"""
Risk Manager
============
Three position-sizing methods per trade:

1. Fixed % Risk  – risk 1 % or 2 % of portfolio per trade
2. Kelly Criterion (half-Kelly) – derived from historical signal win-rate
3. ATR-based stop-loss / take-profit suggestion (2 × ATR SL, 3 × ATR TP)
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from dataclasses import dataclass
from typing import Optional
from sqlalchemy.orm import Session


# ── Result container ──────────────────────────────────────────────────────────

@dataclass
class RiskResult:
    ticker:               str
    entry_price:          float
    # ATR
    atr:                  float
    suggested_stop_loss:  float   # entry − 2 × ATR
    suggested_take_profit:float   # entry + 3 × ATR
    rr_ratio:             float   # reward / risk
    # Fixed %
    fixed_1pct_shares:    int
    fixed_1pct_value:     float
    fixed_2pct_shares:    int
    fixed_2pct_value:     float
    # Kelly
    historical_win_rate:  Optional[float]
    kelly_fraction:       Optional[float]   # half-Kelly, capped at 25 %
    kelly_shares:         Optional[int]
    kelly_value:          Optional[float]
    kelly_note:           str


# ── ATR ───────────────────────────────────────────────────────────────────────

def _atr(df: pd.DataFrame, period: int = 14) -> float:
    high  = df["High"].squeeze()
    low   = df["Low"].squeeze()
    close = df["Close"].squeeze()
    tr = pd.concat([
        high - low,
        (high - close.shift()).abs(),
        (low  - close.shift()).abs(),
    ], axis=1).max(axis=1)
    return float(tr.rolling(period).mean().iloc[-1])


# ── Historical win-rate from stored signals ───────────────────────────────────

def _win_rate_from_db(
    db: Session, ticker: str
) -> Optional[tuple[float, float, float]]:
    """
    Returns (win_rate, avg_win_pct, avg_loss_pct) using consecutive
    signal pairs stored in the DB.  Returns None if < 10 samples.
    """
    from database import Signal
    rows = (
        db.query(Signal)
        .filter(Signal.ticker == ticker)
        .order_by(Signal.timestamp.asc())
        .all()
    )
    if len(rows) < 10:
        return None

    wins, losses    = 0, 0
    win_pcts: list  = []
    loss_pcts: list = []

    for i in range(len(rows) - 1):
        curr = rows[i]
        nxt  = rows[i + 1]
        if not (curr.current_price and nxt.current_price):
            continue
        if curr.overall_signal == "BUY":
            pct = (nxt.current_price - curr.current_price) / curr.current_price
        elif curr.overall_signal == "SELL":
            pct = (curr.current_price - nxt.current_price) / curr.current_price
        else:
            continue
        if pct > 0:
            wins += 1
            win_pcts.append(pct)
        else:
            losses += 1
            loss_pcts.append(abs(pct))

    total = wins + losses
    if total == 0:
        return None

    return (
        wins / total,
        float(np.mean(win_pcts))  if win_pcts  else 0.0,
        float(np.mean(loss_pcts)) if loss_pcts else 0.0,
    )


# ── Kelly fraction (half-Kelly, capped) ──────────────────────────────────────

def _kelly(win_rate: float, avg_win: float, avg_loss: float) -> float:
    if avg_loss < 1e-9:
        return 0.0
    b     = avg_win / avg_loss
    raw   = (b * win_rate - (1 - win_rate)) / b
    half  = raw * 0.5                       # half-Kelly for safety
    return max(0.0, min(half, 0.25))        # cap at 25 %


# ── Main ──────────────────────────────────────────────────────────────────────

def calculate_risk(
    df: pd.DataFrame,
    ticker: str,
    portfolio_value: float,
    db: Session,
) -> RiskResult:
    entry         = float(df["Close"].iloc[-1])
    atr_val       = _atr(df)
    sl            = round(entry - 2 * atr_val, 2)
    tp            = round(entry + 3 * atr_val, 2)
    risk_per_share = max(entry - sl, entry * 0.01)   # at least 1 % floor
    rr            = round((tp - entry) / risk_per_share, 2)

    def _size(pct: float) -> tuple[int, float]:
        amt    = portfolio_value * pct
        shares = max(0, int(amt / risk_per_share))
        return shares, round(shares * entry, 2)

    s1, v1 = _size(0.01)
    s2, v2 = _size(0.02)

    # ── Kelly ─────────────────────────────────────────────────────────────────
    hist = _win_rate_from_db(db, ticker)
    wr = kf = ks = kv = None
    kelly_note = "Need ≥10 signal history records for Kelly calculation."

    if hist:
        wr_raw, avg_w, avg_l = hist
        wr   = round(wr_raw, 3)
        kf   = round(_kelly(wr_raw, avg_w, avg_l), 4)
        kamt = portfolio_value * kf
        ks   = max(0, int(kamt / entry))
        kv   = round(ks * entry, 2)
        kelly_note = (
            f"Win rate {wr*100:.1f}% over {len([wr_raw])}" 
            f" trades · Half-Kelly {kf*100:.1f}% of portfolio"
        )

    return RiskResult(
        ticker=ticker,
        entry_price=round(entry, 2),
        atr=round(atr_val, 4),
        suggested_stop_loss=sl,
        suggested_take_profit=tp,
        rr_ratio=rr,
        fixed_1pct_shares=s1,
        fixed_1pct_value=v1,
        fixed_2pct_shares=s2,
        fixed_2pct_value=v2,
        historical_win_rate=wr,
        kelly_fraction=kf,
        kelly_shares=ks,
        kelly_value=kv,
        kelly_note=kelly_note,
    )
