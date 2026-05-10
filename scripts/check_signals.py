#!/usr/bin/env python3
"""
check_signals.py
================
Standalone script run by GitHub Actions on a cron schedule.

What it does:
  1. Connects directly to Supabase PostgreSQL (no FastAPI needed)
  2. Fetches prices from yfinance for all watchlist tickers
  3. Calculates signals (MA, RSI, MACD, Bollinger, Momentum)
  4. Checks Checklist items — marks TRIGGERED if price ≤ target
  5. Sends Discord alerts for BUY / SELL signals
  6. Saves all results back to the database

Run locally:
  DATABASE_URL=... DISCORD_WEBHOOK_URL=... python scripts/check_signals.py
"""

from __future__ import annotations

import asyncio
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

import httpx
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# ── Path setup — import from backend ─────────────────────────────────────────
ROOT    = Path(__file__).parent.parent
BACKEND = ROOT / "backend"
sys.path.insert(0, str(BACKEND))

from data_fetcher  import fetch_stock_data
from signal_engine import calculate_signals
from database      import (
    Base, Watchlist, Signal, Alert, Checklist,
)

# ── Config ────────────────────────────────────────────────────────────────────
DATABASE_URL        = os.environ["DATABASE_URL"]
DISCORD_WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL", "")
ALERT_COOLDOWN_HRS  = 4          # skip duplicate alerts within this window

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
Base.metadata.create_all(bind=engine)    # create tables if first run
Session = sessionmaker(bind=engine)

# ── Discord ───────────────────────────────────────────────────────────────────
_COLORS  = {"BUY": 0x00D26A, "SELL": 0xFF4757, "HOLD": 0xFFA502}
_EMOJIS  = {"BUY": "🟢", "SELL": "🔴", "HOLD": "🟡"}


async def _discord(
    ticker: str, signal: str, price: float, confidence: float,
    rsi: float, macd: float, ma: str, bb: str, mom: str,
) -> bool:
    if not DISCORD_WEBHOOK_URL:
        print("    ⚠️  DISCORD_WEBHOOK_URL not set — skipping")
        return False

    embed = {
        "title":       f"{_EMOJIS.get(signal,'⚪')} {ticker} — {signal} Signal",
        "color":       _COLORS.get(signal, 0x888888),
        "description": f"MA `{ma}` · BB `{bb}` · Momentum `{mom}`",
        "fields": [
            {"name": "💰 Price",      "value": f"${price:.2f}",      "inline": True},
            {"name": "📊 Confidence", "value": f"{confidence:.0f}%", "inline": True},
            {"name": "📈 RSI",        "value": f"{rsi:.1f}",         "inline": True},
            {"name": "MACD",          "value": f"{macd:.4f}",         "inline": True},
        ],
        "footer":    {"text": "Trading DSS · GitHub Actions"},
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.post(
                DISCORD_WEBHOOK_URL,
                json={"username": "Trading DSS Bot", "embeds": [embed]},
            )
            return r.status_code in (200, 204)
    except Exception as exc:
        print(f"    ❌ Discord error: {exc}")
        return False


# ── Main ──────────────────────────────────────────────────────────────────────

async def run() -> None:
    db   = Session()
    ok   = 0
    fail = 0

    try:
        tickers = [r.ticker for r in db.query(Watchlist).all()]
        print(f"[{datetime.utcnow():%Y-%m-%d %H:%M} UTC] Processing {len(tickers)} tickers")

        for ticker in tickers:
            print(f"\n  ── {ticker}")

            df = fetch_stock_data(ticker)
            if df is None:
                print("    ⚠️  No price data — skipping")
                fail += 1
                continue

            result = calculate_signals(df, ticker)
            if result is None:
                print("    ⚠️  Not enough history — skipping")
                fail += 1
                continue

            # ── Save signal ───────────────────────────────────────────────
            sig = Signal(
                ticker=ticker,
                ma_signal=result.ma_signal,       rsi_signal=result.rsi_signal,
                macd_signal=result.macd_signal,   bb_signal=result.bb_signal,
                momentum_signal=result.momentum_signal,
                overall_signal=result.overall_signal, confidence=result.confidence,
                current_price=result.current_price,   rsi_value=result.rsi_value,
                macd_value=result.macd_value,     macd_signal_value=result.macd_signal_value,
                bb_upper=result.bb_upper,         bb_lower=result.bb_lower,
                bb_middle=result.bb_middle,       sma20=result.sma20,
                sma50=result.sma50,               momentum_value=result.momentum_value,
            )
            db.add(sig)
            print(f"    {result.overall_signal} ({result.confidence:.0f}%)  "
                  f"@ ${result.current_price:.2f}  RSI {result.rsi_value:.1f}")

            # ── Check Checklist price targets ─────────────────────────────
            waiting = db.query(Checklist).filter(
                Checklist.ticker == ticker,
                Checklist.status == "WAITING",
            ).all()
            for item in waiting:
                if result.current_price <= item.target_price:
                    item.status      = "TRIGGERED"
                    item.triggered_at = datetime.utcnow()
                    print(f"    🎯 Checklist triggered! "
                          f"${result.current_price:.2f} ≤ target ${item.target_price:.2f}")
                    # Send a separate Discord alert for checklist trigger
                    await _discord(
                        ticker, "BUY", result.current_price, result.confidence,
                        result.rsi_value, result.macd_value,
                        result.ma_signal, result.bb_signal, result.momentum_signal,
                    )

            # ── Send BUY / SELL Discord alert ─────────────────────────────
            if result.overall_signal in ("BUY", "SELL"):
                cutoff = datetime.utcnow() - timedelta(hours=ALERT_COOLDOWN_HRS)
                dup = db.query(Alert).filter(
                    Alert.ticker     == ticker,
                    Alert.signal     == result.overall_signal,
                    Alert.created_at >= cutoff,
                ).first()

                if dup:
                    print(f"    ⏭️  Duplicate within {ALERT_COOLDOWN_HRS}h — skipped")
                else:
                    sent = await _discord(
                        ticker=ticker, signal=result.overall_signal,
                        price=result.current_price, confidence=result.confidence,
                        rsi=result.rsi_value, macd=result.macd_value,
                        ma=result.ma_signal, bb=result.bb_signal,
                        mom=result.momentum_signal,
                    )
                    db.add(Alert(
                        ticker=ticker,
                        message=(f"{result.overall_signal} | {ticker} | "
                                 f"${result.current_price:.2f} | "
                                 f"Conf {result.confidence:.0f}%"),
                        signal=result.overall_signal,
                        price=result.current_price,
                        discord_sent=sent,
                    ))
                    print(f"    {'✅' if sent else '❌'} Discord alert sent")

            ok += 1

        db.commit()

    finally:
        db.close()

    print(f"\n{'─'*40}")
    print(f"Done: {ok} ok  |  {fail} failed")


if __name__ == "__main__":
    asyncio.run(run())
