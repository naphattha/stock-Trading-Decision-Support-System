"""
Stock Trading DSS — FastAPI v3
=================================
New: Universe · Checklist · Portfolio · WebSocket · Redis Cache · PostgreSQL
"""
from __future__ import annotations

import csv, io, json, os
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks, Query, WebSocket, WebSocketDisconnect, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

import cache
import scheduler as sched
from config import CORS_ORIGINS
from database import (
    create_tables, get_db,
    Stock, Watchlist, Signal, Alert, FundamentalData,
    UniversePool, Universe, Checklist, Position,
)
from data_fetcher import fetch_stock_data, fetch_stock_info
from discord_alert import send_discord_alert
from fundamental_filter import fetch_fundamentals
from market_regime import analyze_regime
from risk_manager import calculate_risk
from buy_price_calculator import calculate_buy_price
from portfolio_manager import get_portfolio_snapshot, get_recommendations
from universe_scanner import scan_pool
from websocket_manager import manager as ws_manager
from schemas import *
from signal_engine import calculate_signals


# ── Lifespan ──────────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    create_tables()
    # Scheduler is disabled when GitHub Actions handles alerts (DISABLE_SCHEDULER=true)
    if os.getenv("DISABLE_SCHEDULER", "false").lower() != "true":
        sched.start(_auto_refresh)
        print("[app] APScheduler started (built-in mode)")
    else:
        print("[app] APScheduler disabled — GitHub Actions handles alerts")
    yield
    sched.stop()

app = FastAPI(title="Stock Trading DSS", version="3.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=CORS_ORIGINS, allow_methods=["*"], allow_headers=["*"])


# ── WebSocket ─────────────────────────────────────────────────────────────────
@app.websocket("/ws/signals")
async def ws_endpoint(ws: WebSocket):
    await ws_manager.connect(ws)
    try:
        # send snapshot of all cached signals on connect
        from database import SessionLocal
        db = SessionLocal()
        tickers = [r.ticker for r in db.query(Watchlist).all()]
        db.close()
        for t in tickers:
            cached = cache.get_signal(t)
            if cached:
                await ws_manager.send_to(ws, "signals.snapshot", cached)
        while True:
            await ws.receive_text()   # keep alive (ping/pong)
    except WebSocketDisconnect:
        ws_manager.disconnect(ws)


# ── Internal helpers ──────────────────────────────────────────────────────────
def _upsert_stock(db, ticker):
    if not db.query(Stock).filter(Stock.ticker == ticker).first():
        info = fetch_stock_info(ticker)
        db.add(Stock(ticker=ticker, name=info["name"], sector=info["sector"]))

def _get_or_refresh_fundamental(db, ticker):
    row = db.query(FundamentalData).filter(FundamentalData.ticker == ticker).first()
    stale = row is None or (datetime.utcnow() - row.updated_at) > timedelta(hours=24)
    if stale:
        fd = fetch_fundamentals(ticker)
        if row is None:
            row = FundamentalData(ticker=ticker); db.add(row)
        row.updated_at = datetime.utcnow(); row.name = fd.name; row.sector = fd.sector
        row.market_cap = fd.market_cap; row.pe_ratio = fd.pe_ratio; row.forward_pe = fd.forward_pe
        row.eps_ttm = fd.eps_ttm; row.revenue_growth = fd.revenue_growth; row.profit_margin = fd.profit_margin
        row.debt_to_equity = fd.debt_to_equity; row.price_to_book = fd.price_to_book; row.dividend_yield = fd.dividend_yield
        row.passes_filter = fd.passes_filter; row.filter_warnings = json.dumps(fd.filter_warnings)
        db.commit(); db.refresh(row)
    return row

async def _process_ticker(db, ticker: str) -> bool:
    df = fetch_stock_data(ticker)
    if df is None: return False
    result = calculate_signals(df, ticker)
    if result is None: return False

    fund = _get_or_refresh_fundamental(db, ticker)
    sig_dict = {
        "ticker": ticker, "timestamp": datetime.utcnow().isoformat(),
        "overall_signal": result.overall_signal, "confidence": result.confidence,
        "current_price": result.current_price, "rsi_value": result.rsi_value,
        "macd_value": result.macd_value, "sma20": result.sma20, "sma50": result.sma50,
        "ma_signal": result.ma_signal, "rsi_signal": result.rsi_signal,
        "macd_signal": result.macd_signal, "bb_signal": result.bb_signal,
        "momentum_signal": result.momentum_signal,
        "bb_upper": result.bb_upper, "bb_lower": result.bb_lower,
        "momentum_value": result.momentum_value,
        "fundamental_ok": fund.passes_filter,
    }
    cache.set_signal(ticker, sig_dict)

    sig = Signal(ticker=ticker, ma_signal=result.ma_signal, rsi_signal=result.rsi_signal,
        macd_signal=result.macd_signal, bb_signal=result.bb_signal, momentum_signal=result.momentum_signal,
        overall_signal=result.overall_signal, confidence=result.confidence, current_price=result.current_price,
        rsi_value=result.rsi_value, macd_value=result.macd_value, macd_signal_value=result.macd_signal_value,
        bb_upper=result.bb_upper, bb_lower=result.bb_lower, bb_middle=result.bb_middle,
        sma20=result.sma20, sma50=result.sma50, momentum_value=result.momentum_value,
        fundamental_ok=fund.passes_filter, fundamental_warn=fund.filter_warnings)
    db.add(sig)

    # Check checklist items
    cl_items = db.query(Checklist).filter(Checklist.ticker == ticker, Checklist.status == "WAITING").all()
    for item in cl_items:
        if result.current_price <= item.target_price:
            item.status = "TRIGGERED"
            item.triggered_at = datetime.utcnow()
            cache.invalidate_checklist()
            await ws_manager.broadcast("checklist.triggered", {
                "ticker": ticker, "target_price": item.target_price,
                "current_price": result.current_price,
            })

    if result.overall_signal in ("BUY", "SELL"):
        cutoff = datetime.utcnow() - timedelta(hours=1)
        dup = db.query(Alert).filter(Alert.ticker == ticker, Alert.signal == result.overall_signal, Alert.created_at >= cutoff).first()
        if not dup:
            alert = Alert(ticker=ticker, message=f"{result.overall_signal}|{ticker}|${result.current_price:.2f}", signal=result.overall_signal, price=result.current_price)
            db.add(alert); db.flush()
            sent = await send_discord_alert(ticker=ticker, signal=result.overall_signal, price=result.current_price, confidence=result.confidence, rsi=result.rsi_value, macd=result.macd_value, ma_signal=result.ma_signal, bb_signal=result.bb_signal, momentum_signal=result.momentum_signal)
            alert.discord_sent = sent

    db.commit()
    await ws_manager.broadcast("signals.updated", sig_dict)
    return True

async def _auto_refresh():
    from database import SessionLocal
    db = SessionLocal()
    try:
        tickers = [r.ticker for r in db.query(Watchlist).all()]
        for t in tickers: await _process_ticker(db, t)
        print(f"[sched] {len(tickers)} tickers @ {datetime.utcnow()}")
    finally:
        db.close()


# ══════════════════════════════════════════════════════════════════════════════
# WATCHLIST
# ══════════════════════════════════════════════════════════════════════════════
@app.get("/watchlist", response_model=List[WatchlistResponse], tags=["Watchlist"])
def list_watchlist(db: Session = Depends(get_db)):
    return db.query(Watchlist).order_by(Watchlist.added_at).all()

@app.post("/watchlist", response_model=WatchlistResponse, tags=["Watchlist"])
def add_watchlist(item: WatchlistCreate, db: Session = Depends(get_db)):
    if db.query(Watchlist).filter(Watchlist.ticker == item.ticker).first():
        raise HTTPException(400, f"{item.ticker} already in watchlist.")
    _upsert_stock(db, item.ticker)
    row = Watchlist(ticker=item.ticker, notes=item.notes or "", target_price=item.target_price, stop_loss=item.stop_loss)
    db.add(row); db.commit(); db.refresh(row); return row

@app.delete("/watchlist/{ticker}", tags=["Watchlist"])
def remove_watchlist(ticker: str, db: Session = Depends(get_db)):
    row = db.query(Watchlist).filter(Watchlist.ticker == ticker.upper()).first()
    if not row: raise HTTPException(404, "Not found.")
    db.delete(row); db.commit(); cache.invalidate_signal(ticker.upper())
    return {"removed": ticker.upper()}


# ══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ══════════════════════════════════════════════════════════════════════════════
@app.post("/signals/refresh", tags=["Signals"])
async def refresh_signals(bg: BackgroundTasks, db: Session = Depends(get_db)):
    tickers = [r.ticker for r in db.query(Watchlist).all()]
    if not tickers: return {"message": "Watchlist is empty."}
    async def _run():
        from database import SessionLocal; s = SessionLocal()
        try:
            for t in tickers: await _process_ticker(s, t)
        finally:
            s.close()
    bg.add_task(_run)
    return {"message": f"Refreshing {len(tickers)} ticker(s)."}

@app.get("/signals/latest", tags=["Signals"])
def latest_signals_all(db: Session = Depends(get_db)):
    rows = db.query(Watchlist).all(); result = []
    for wl in rows:
        stock = db.query(Stock).filter(Stock.ticker == wl.ticker).first()
        cached = cache.get_signal(wl.ticker)
        if not cached:
            sig = db.query(Signal).filter(Signal.ticker == wl.ticker).order_by(Signal.timestamp.desc()).first()
            cached = SignalResponse.model_validate(sig).model_dump() if sig else None
        result.append({"ticker": wl.ticker, "name": stock.name if stock else wl.ticker,
            "sector": stock.sector if stock else "Unknown", "target_price": wl.target_price,
            "stop_loss": wl.stop_loss, "notes": wl.notes, "signal": cached})
    return result

@app.get("/signals/{ticker}", response_model=List[SignalResponse], tags=["Signals"])
def signal_history(ticker: str, limit: int = 20, db: Session = Depends(get_db)):
    return db.query(Signal).filter(Signal.ticker == ticker.upper()).order_by(Signal.timestamp.desc()).limit(limit).all()

@app.get("/signals/{ticker}/latest", response_model=SignalResponse, tags=["Signals"])
def signal_latest(ticker: str, db: Session = Depends(get_db)):
    row = db.query(Signal).filter(Signal.ticker == ticker.upper()).order_by(Signal.timestamp.desc()).first()
    if not row: raise HTTPException(404, "No signal found.")
    return row


# ══════════════════════════════════════════════════════════════════════════════
# UNIVERSE POOL
# ══════════════════════════════════════════════════════════════════════════════
@app.get("/universe/pool", tags=["Universe"])
def list_pool(db: Session = Depends(get_db)):
    return db.query(UniversePool).order_by(UniversePool.ticker).all()

@app.post("/universe/pool/upload", tags=["Universe"])
async def upload_pool_csv(file: UploadFile = File(...), db: Session = Depends(get_db)):
    content = await file.read()
    reader  = csv.reader(io.StringIO(content.decode("utf-8")))
    added = 0
    for row in reader:
        if not row: continue
        ticker = row[0].strip().upper()
        if not ticker or ticker.lower() in ("ticker", "symbol", "stock"): continue
        if not db.query(UniversePool).filter(UniversePool.ticker == ticker).first():
            db.add(UniversePool(ticker=ticker, source="csv"))
            added += 1
    db.commit()
    return {"added": added, "message": f"{added} tickers added to pool."}

@app.get("/universe/pool/download", tags=["Universe"])
def download_pool_csv(db: Session = Depends(get_db)):
    rows = db.query(UniversePool).order_by(UniversePool.ticker).all()
    buf = io.StringIO(); writer = csv.writer(buf)
    writer.writerow(["ticker", "source", "added_at"])
    for r in rows: writer.writerow([r.ticker, r.source, r.added_at.strftime("%Y-%m-%d")])
    buf.seek(0)
    return StreamingResponse(io.BytesIO(buf.getvalue().encode()), media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=universe_pool.csv"})

@app.delete("/universe/pool/{ticker}", tags=["Universe"])
def remove_pool(ticker: str, db: Session = Depends(get_db)):
    row = db.query(UniversePool).filter(UniversePool.ticker == ticker.upper()).first()
    if not row: raise HTTPException(404)
    db.delete(row); db.commit()
    return {"removed": ticker.upper()}


# ══════════════════════════════════════════════════════════════════════════════
# UNIVERSE
# ══════════════════════════════════════════════════════════════════════════════
@app.get("/universe", response_model=List[UniverseResponse], tags=["Universe"])
def list_universe(db: Session = Depends(get_db)):
    return db.query(Universe).order_by(Universe.scan_score.desc()).all()

@app.post("/universe/add", response_model=UniverseResponse, tags=["Universe"])
def add_universe_manual(item: UniverseCreate, db: Session = Depends(get_db)):
    if db.query(Universe).filter(Universe.ticker == item.ticker).first():
        raise HTTPException(400, f"{item.ticker} already in universe.")
    row = Universe(ticker=item.ticker, added_by="manual", notes=item.notes or "")
    db.add(row); db.commit(); db.refresh(row); return row

@app.post("/universe/scan", response_model=List[ScanResultResponse], tags=["Universe"])
async def run_scan(bg: BackgroundTasks, db: Session = Depends(get_db)):
    cached = cache.get_scan()
    if cached: return cached
    pool = [r.ticker for r in db.query(UniversePool).all()]
    if not pool: raise HTTPException(400, "Universe pool is empty. Upload a CSV first.")
    results = scan_pool(pool)
    # auto-add to universe
    added = 0
    for r in results:
        if not db.query(Universe).filter(Universe.ticker == r.ticker).first():
            db.add(Universe(ticker=r.ticker, added_by="scan", scan_score=r.score,
                criteria_matched=r.criteria_matched, current_price=r.current_price,
                rsi=r.rsi, fib_level=r.fib_level))
            added += 1
    db.commit()
    out = [{"ticker": r.ticker, "score": r.score, "criteria_matched": r.criteria_matched,
        "current_price": r.current_price, "rsi": r.rsi, "fib_level": r.fib_level} for r in results]
    cache.set_scan(out)
    return out

@app.delete("/universe/{ticker}", tags=["Universe"])
def remove_universe(ticker: str, db: Session = Depends(get_db)):
    row = db.query(Universe).filter(Universe.ticker == ticker.upper()).first()
    if not row: raise HTTPException(404)
    db.delete(row); db.commit(); return {"removed": ticker.upper()}


# ══════════════════════════════════════════════════════════════════════════════
# CHECKLIST
# ══════════════════════════════════════════════════════════════════════════════
@app.get("/checklist", response_model=List[ChecklistResponse], tags=["Checklist"])
def list_checklist(db: Session = Depends(get_db)):
    return db.query(Checklist).order_by(Checklist.created_at.desc()).all()

@app.post("/checklist", response_model=ChecklistResponse, tags=["Checklist"])
def add_checklist(item: ChecklistCreate, db: Session = Depends(get_db)):
    df = fetch_stock_data(item.ticker)
    bp = calculate_buy_price(df, item.ticker) if df is not None else None
    row = Checklist(
        ticker=item.ticker, target_price=item.target_price, notes=item.notes or "",
        suggested_price=bp.suggested_buy_price if bp else None,
        suggestion_method=bp.suggestion_method if bp else None,
        fib_382=bp.fib_382 if bp else None, fib_500=bp.fib_500 if bp else None,
        fib_618=bp.fib_618 if bp else None, high_52w=bp.high_52w if bp else None,
        low_52w=bp.low_52w if bp else None,
    )
    db.add(row); db.commit(); db.refresh(row)
    cache.invalidate_checklist(); return row

@app.get("/checklist/buy-price/{ticker}", response_model=BuyPriceResponse, tags=["Checklist"])
def get_buy_price(ticker: str):
    df = fetch_stock_data(ticker.upper())
    if df is None: raise HTTPException(404, "No price data.")
    bp = calculate_buy_price(df, ticker.upper())
    return BuyPriceResponse(ticker=bp.ticker, current_price=bp.current_price,
        suggested_buy_price=bp.suggested_buy_price, suggestion_method=bp.suggestion_method,
        bb_lower=bp.bb_lower, support_20d=bp.support_20d, fib_382=bp.fib_382,
        fib_500=bp.fib_500, fib_618=bp.fib_618, high_52w=bp.high_52w, low_52w=bp.low_52w,
        upside_to_fib_382=bp.upside_to_fib_382, upside_to_52w_high=bp.upside_to_52w_high)

@app.patch("/checklist/{id}/expire", tags=["Checklist"])
def expire_checklist(id: int, db: Session = Depends(get_db)):
    row = db.query(Checklist).filter(Checklist.id == id).first()
    if not row: raise HTTPException(404)
    row.status = "EXPIRED"; row.resolved_at = datetime.utcnow()
    db.commit(); cache.invalidate_checklist(); return {"status": "EXPIRED"}

@app.patch("/checklist/{id}/bought", tags=["Checklist"])
def mark_bought(id: int, body: PositionCreate, db: Session = Depends(get_db)):
    row = db.query(Checklist).filter(Checklist.id == id).first()
    if not row: raise HTTPException(404)
    row.status = "BOUGHT"; row.resolved_at = datetime.utcnow()
    date = datetime.strptime(body.date_bought, "%Y-%m-%d") if body.date_bought else datetime.utcnow()
    pos = Position(ticker=row.ticker, shares=body.shares,
        cost_basis_per_share=body.cost_basis_per_share, date_bought=date,
        checklist_id=id, notes=body.notes or "")
    db.add(pos); db.commit()
    cache.invalidate_checklist(); cache.invalidate_portfolio()
    await_ws = {"ticker": row.ticker, "shares": body.shares, "price": body.cost_basis_per_share}
    return {"status": "BOUGHT", "position_id": pos.id}

@app.delete("/checklist/{id}", tags=["Checklist"])
def delete_checklist(id: int, db: Session = Depends(get_db)):
    row = db.query(Checklist).filter(Checklist.id == id).first()
    if not row: raise HTTPException(404)
    db.delete(row); db.commit(); cache.invalidate_checklist(); return {"deleted": id}


# ══════════════════════════════════════════════════════════════════════════════
# PORTFOLIO
# ══════════════════════════════════════════════════════════════════════════════
@app.get("/portfolio/holdings", response_model=PortfolioSnapshotResponse, tags=["Portfolio"])
def portfolio_holdings(db: Session = Depends(get_db)):
    cached = cache.get_portfolio()
    if cached:
        return cached
    snap = get_portfolio_snapshot(db)
    out = {
        "holdings": [h.__dict__ for h in snap.holdings],
        "total_value": snap.total_value, "total_cost": snap.total_cost,
        "total_pnl": snap.total_pnl, "total_pnl_pct": snap.total_pnl_pct,
        "equal_weight_pct": snap.equal_weight_pct,
    }
    cache.set_portfolio([out])
    return out

@app.get("/portfolio/recommendations", response_model=List[RecommendationResponse], tags=["Portfolio"])
def portfolio_recommendations(db: Session = Depends(get_db)):
    recs = get_recommendations(db)
    return [RecommendationResponse(ticker=r.ticker, current_price=r.current_price,
        target_price=r.target_price, signal=r.signal, confidence=r.confidence,
        upside_pct=r.upside_pct, reason=r.reason) for r in recs]

@app.get("/portfolio/positions", response_model=List[PositionResponse], tags=["Portfolio"])
def list_positions(db: Session = Depends(get_db)):
    return db.query(Position).order_by(Position.added_at.desc()).all()

@app.post("/portfolio/positions", response_model=PositionResponse, tags=["Portfolio"])
def add_position(item: PositionCreate, db: Session = Depends(get_db)):
    date = datetime.strptime(item.date_bought, "%Y-%m-%d") if item.date_bought else datetime.utcnow()
    pos = Position(ticker=item.ticker, shares=item.shares, cost_basis_per_share=item.cost_basis_per_share,
        date_bought=date, checklist_id=item.checklist_id, notes=item.notes or "")
    db.add(pos); db.commit(); db.refresh(pos)
    cache.invalidate_portfolio(); return pos

@app.delete("/portfolio/positions/{id}", tags=["Portfolio"])
def delete_position(id: int, db: Session = Depends(get_db)):
    pos = db.query(Position).filter(Position.id == id).first()
    if not pos: raise HTTPException(404)
    db.delete(pos); db.commit(); cache.invalidate_portfolio(); return {"deleted": id}

@app.get("/portfolio/summary", response_model=PortfolioSummary, tags=["Portfolio"])
def portfolio_summary(db: Session = Depends(get_db)):
    wl = db.query(Watchlist).all(); buy=sell=hold=ns=0
    for w in wl:
        s = db.query(Signal).filter(Signal.ticker==w.ticker).order_by(Signal.timestamp.desc()).first()
        if not s: ns+=1
        elif s.overall_signal=="BUY": buy+=1
        elif s.overall_signal=="SELL": sell+=1
        else: hold+=1
    return PortfolioSummary(total_stocks=len(wl), buy_signals=buy, sell_signals=sell,
        hold_signals=hold, no_signal=ns, last_updated=datetime.utcnow().isoformat()+"Z")


# ══════════════════════════════════════════════════════════════════════════════
# PRICE / FUNDAMENTAL / REGIME / RISK / ALERTS
# ══════════════════════════════════════════════════════════════════════════════
@app.get("/price/{ticker}", tags=["Price"])
def price_data(ticker: str, period: str = "3mo"):
    df = fetch_stock_data(ticker.upper(), period)
    if df is None: raise HTTPException(404)
    return {"ticker": ticker.upper(), "data": [
        {"date": d.strftime("%Y-%m-%d"), "open": round(float(r["Open"]),2),
         "high": round(float(r["High"]),2), "low": round(float(r["Low"]),2),
         "close": round(float(r["Close"]),2), "volume": int(r["Volume"])}
        for d, r in df.iterrows()]}

@app.get("/fundamental/{ticker}", response_model=FundamentalResponse, tags=["Fundamental"])
def get_fundamental(ticker: str, refresh: bool = False, db: Session = Depends(get_db)):
    t = ticker.upper()
    if refresh:
        row = db.query(FundamentalData).filter(FundamentalData.ticker == t).first()
        if row: row.updated_at = datetime.utcnow() - timedelta(hours=25); db.commit()
    row = _get_or_refresh_fundamental(db, t)
    return FundamentalResponse(ticker=row.ticker, name=row.name, sector=row.sector,
        market_cap=row.market_cap, pe_ratio=row.pe_ratio, forward_pe=row.forward_pe,
        eps_ttm=row.eps_ttm, revenue_growth=row.revenue_growth, profit_margin=row.profit_margin,
        debt_to_equity=row.debt_to_equity, price_to_book=row.price_to_book,
        dividend_yield=row.dividend_yield, passes_filter=row.passes_filter,
        filter_warnings=json.loads(row.filter_warnings or "[]"), updated_at=row.updated_at)

@app.get("/regime/{ticker}", response_model=RegimeResponse, tags=["Regime"])
def get_regime(ticker: str):
    df = fetch_stock_data(ticker.upper(), "6mo")
    if df is None: raise HTTPException(404)
    r = analyze_regime(df, ticker.upper())
    return RegimeResponse(ticker=r.ticker, adx=r.adx, plus_di=r.plus_di, minus_di=r.minus_di,
        regime=r.regime, regime_strength=r.regime_strength, bb_width=r.bb_width,
        volatility_regime=r.volatility_regime, daily_signal=r.daily_signal, weekly_signal=r.weekly_signal,
        mtf_confluence=r.mtf_confluence, mtf_strength=r.mtf_strength,
        recommended_strategy=r.recommended_strategy, strategy_note=r.strategy_note)

@app.get("/risk/{ticker}", response_model=RiskResponse, tags=["Risk"])
def get_risk(ticker: str, portfolio: float = Query(default=100_000, gt=0), db: Session = Depends(get_db)):
    df = fetch_stock_data(ticker.upper())
    if df is None: raise HTTPException(404)
    r = calculate_risk(df, ticker.upper(), portfolio, db)
    return RiskResponse(ticker=r.ticker, entry_price=r.entry_price, atr=r.atr,
        suggested_stop_loss=r.suggested_stop_loss, suggested_take_profit=r.suggested_take_profit,
        rr_ratio=r.rr_ratio, fixed_1pct_shares=r.fixed_1pct_shares, fixed_1pct_value=r.fixed_1pct_value,
        fixed_2pct_shares=r.fixed_2pct_shares, fixed_2pct_value=r.fixed_2pct_value,
        historical_win_rate=r.historical_win_rate, kelly_fraction=r.kelly_fraction,
        kelly_shares=r.kelly_shares, kelly_value=r.kelly_value, kelly_note=r.kelly_note)

@app.get("/alerts", response_model=List[AlertResponse], tags=["Alerts"])
def list_alerts(limit: int = 50, db: Session = Depends(get_db)):
    return db.query(Alert).order_by(Alert.created_at.desc()).limit(limit).all()

@app.get("/health", tags=["System"])
def health():
    return {"status": "ok", "version": "3.0.0", "redis": cache.ping(),
            "ws_clients": ws_manager.connection_count, "time": datetime.utcnow().isoformat()+"Z"}
