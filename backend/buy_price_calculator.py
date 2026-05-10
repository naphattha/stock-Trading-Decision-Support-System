"""
Buy Price Calculator
====================
Suggests an optimal buy price using three methods:
  • Bollinger Lower Band (20, 2σ)
  • Recent 20-day Support (lowest swing low)
  • Fibonacci 61.8% retracement (52-week high → low)

Suggested = lowest value that is still ≥ Fib 61.8% (strong floor).
Also computes upside scenarios to Fib 38.2% and 52-week high.
"""

from __future__ import annotations

import pandas as pd
from dataclasses import dataclass


@dataclass
class BuyPriceResult:
    ticker:              str
    current_price:       float
    suggested_buy_price: float
    suggestion_method:   str      # "BB Lower" | "Support 20d" | "Fibonacci 61.8%"
    # Price levels
    bb_lower:            float
    support_20d:         float
    fib_382:             float
    fib_500:             float
    fib_618:             float
    high_52w:            float
    low_52w:             float
    # Expected upside from suggested buy price
    upside_to_fib_382:   float    # % gain → Fib 38.2% (first target)
    upside_to_52w_high:  float    # % gain → 52-week high (full recovery)


def calculate_buy_price(df: pd.DataFrame, ticker: str) -> BuyPriceResult:
    close = df["Close"].squeeze()
    low   = df["Low"].squeeze()

    current = float(close.iloc[-1])

    # ── Bollinger Lower ────────────────────────────────────────────────────────
    sma   = close.rolling(20).mean()
    std   = close.rolling(20).std()
    bb_lo = float((sma - 2 * std).iloc[-1])

    # ── Support: lowest low of last 20 trading days ────────────────────────────
    support = float(low.tail(20).min())

    # ── Fibonacci (52-week range) ──────────────────────────────────────────────
    window   = min(252, len(close))
    high_52w = float(close.tail(window).max())
    low_52w  = float(close.tail(window).min())
    swing    = high_52w - low_52w

    fib_382 = round(high_52w - 0.382 * swing, 2)
    fib_500 = round(high_52w - 0.500 * swing, 2)
    fib_618 = round(high_52w - 0.618 * swing, 2)

    # ── Suggested price ────────────────────────────────────────────────────────
    # Lowest candidate that is still ≥ Fib 61.8% (hard floor)
    candidates = {
        "BB Lower":        bb_lo,
        "Support 20d":     support,
        "Fibonacci 61.8%": fib_618,
    }
    valid = {k: v for k, v in candidates.items() if v >= fib_618}

    if valid:
        method    = min(valid, key=valid.get)
        suggested = valid[method]
    else:
        method    = "Fibonacci 61.8%"
        suggested = fib_618

    suggested = round(max(suggested, 0.01), 2)

    # ── Upside ────────────────────────────────────────────────────────────────
    upside_382 = round((fib_382 - suggested) / suggested * 100, 1)
    upside_52h = round((high_52w - suggested) / suggested * 100, 1)

    return BuyPriceResult(
        ticker=ticker,
        current_price=round(current, 2),
        suggested_buy_price=suggested,
        suggestion_method=method,
        bb_lower=round(bb_lo, 2),
        support_20d=round(support, 2),
        fib_382=fib_382,
        fib_500=fib_500,
        fib_618=fib_618,
        high_52w=round(high_52w, 2),
        low_52w=round(low_52w, 2),
        upside_to_fib_382=upside_382,
        upside_to_52w_high=upside_52h,
    )
