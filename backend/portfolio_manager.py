"""
Portfolio Manager
=================
Real-time P&L, weight analysis (actual vs equal-weight target),
and BUY recommendations from triggered checklist items.

Design principle: Let winners run.
  Weights are shown for transparency only — no forced rebalancing.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional
from sqlalchemy.orm import Session

from data_fetcher import fetch_stock_data


@dataclass
class HoldingResult:
    ticker:               str
    shares:               float
    cost_basis_per_share: float
    current_price:        float
    market_value:         float
    cost_basis_total:     float
    unrealized_pnl:       float
    pnl_pct:              float
    actual_weight:        float
    target_weight:        float
    weight_diff:          float   # positive = overweight, negative = underweight
    date_bought:          Optional[str]
    notes:                str


@dataclass
class PortfolioSnapshot:
    holdings:         list[HoldingResult]
    total_value:      float
    total_cost:       float
    total_pnl:        float
    total_pnl_pct:    float
    equal_weight_pct: float


@dataclass
class Recommendation:
    ticker:        str
    current_price: float
    target_price:  float
    signal:        str
    confidence:    float
    upside_pct:    float
    reason:        str


def get_portfolio_snapshot(db: Session) -> PortfolioSnapshot:
    from database import Position

    positions = db.query(Position).all()
    if not positions:
        return PortfolioSnapshot([], 0, 0, 0, 0, 0)

    holdings: list[HoldingResult] = []

    for pos in positions:
        # Fetch latest close (5-day window is fast)
        df = fetch_stock_data(pos.ticker, period="5d")
        if df is not None and not df.empty:
            current = float(df["Close"].iloc[-1])
        else:
            current = float(pos.cost_basis_per_share)

        mv   = round(current * pos.shares, 2)
        cost = round(pos.cost_basis_per_share * pos.shares, 2)
        pnl  = round(mv - cost, 2)
        pct  = round(pnl / cost * 100, 2) if cost > 0 else 0.0

        holdings.append(HoldingResult(
            ticker=pos.ticker,
            shares=float(pos.shares),
            cost_basis_per_share=float(pos.cost_basis_per_share),
            current_price=round(current, 2),
            market_value=mv,
            cost_basis_total=cost,
            unrealized_pnl=pnl,
            pnl_pct=pct,
            actual_weight=0.0,    # filled below
            target_weight=0.0,
            weight_diff=0.0,
            date_bought=pos.date_bought.strftime("%Y-%m-%d") if pos.date_bought else None,
            notes=pos.notes or "",
        ))

    total_val  = sum(h.market_value for h in holdings)
    total_cost = sum(h.cost_basis_total for h in holdings)
    total_pnl  = round(total_val - total_cost, 2)
    total_pct  = round(total_pnl / total_cost * 100, 2) if total_cost > 0 else 0.0
    eq_w       = round(100 / len(holdings), 1) if holdings else 0

    for h in holdings:
        h.actual_weight = round(h.market_value / total_val * 100, 1) if total_val > 0 else 0
        h.target_weight = eq_w
        h.weight_diff   = round(h.actual_weight - h.target_weight, 1)

    return PortfolioSnapshot(
        holdings=holdings,
        total_value=round(total_val, 2),
        total_cost=round(total_cost, 2),
        total_pnl=total_pnl,
        total_pnl_pct=total_pct,
        equal_weight_pct=eq_w,
    )


def get_recommendations(db: Session) -> list[Recommendation]:
    """
    Checklist items with status=TRIGGERED where the latest Signal = BUY.
    Sorted by confidence descending.
    """
    from database import Checklist, Signal

    triggered = db.query(Checklist).filter(
        Checklist.status == "TRIGGERED"
    ).all()

    recs: list[Recommendation] = []
    for item in triggered:
        sig = (
            db.query(Signal)
            .filter(Signal.ticker == item.ticker)
            .order_by(Signal.timestamp.desc())
            .first()
        )
        if not (sig and sig.overall_signal == "BUY" and sig.current_price):
            continue

        upside = round(
            (item.target_price - sig.current_price) / sig.current_price * 100, 1
        ) if sig.current_price > 0 else 0

        recs.append(Recommendation(
            ticker=item.ticker,
            current_price=float(sig.current_price),
            target_price=float(item.target_price),
            signal=sig.overall_signal,
            confidence=float(sig.confidence or 0),
            upside_pct=upside,
            reason=(
                f"Checklist target ${item.target_price:.2f} triggered "
                f"+ Signal BUY ({sig.confidence:.0f}% confidence)"
            ),
        ))

    return sorted(recs, key=lambda r: r.confidence, reverse=True)
