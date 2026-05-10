"""
Universe Scanner
================
Scans a pool of tickers against 5 quantitative criteria.
Tickers scoring ≥ MIN_SCORE are surfaced for the Universe.

Criteria
  1. RSI(14) < 35                            — oversold zone
  2. Price ≤ BB Lower Band × 1.02            — near lower Bollinger
  3. Price ≤ 52-week Low × 1.10              — near 52-week low
  4. MA50 crossed above MA200 ≤ 20 days ago  — fresh Golden Cross
  5. Price within 2% of Fib 38.2/50/61.8%   — Fibonacci support
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from dataclasses import dataclass, field
from typing import Optional

from data_fetcher import fetch_stock_data
from config import UNIVERSE_MIN_SCORE


@dataclass
class ScanResult:
    ticker:           str
    score:            int
    criteria_matched: list[str]   = field(default_factory=list)
    current_price:    Optional[float] = None
    rsi:              Optional[float] = None
    fib_level:        Optional[str]   = None


# ── Indicator helpers ─────────────────────────────────────────────────────────

def _rsi(close: pd.Series, period: int = 14) -> pd.Series:
    d    = close.diff()
    gain = d.clip(lower=0).rolling(period).mean()
    loss = (-d.clip(upper=0)).rolling(period).mean()
    return 100 - (100 / (1 + gain / loss.replace(0, np.nan)))


def _bb_lower(close: pd.Series, period: int = 20, n: float = 2.0) -> float:
    sma = close.rolling(period).mean()
    std = close.rolling(period).std()
    return float((sma - n * std).iloc[-1])


# ── Scoring ───────────────────────────────────────────────────────────────────

def _score_df(df: pd.DataFrame) -> tuple[int, list[str], dict]:
    close = df["Close"].squeeze()
    score = 0
    crit: list[str] = []
    meta: dict = {}

    current = float(close.iloc[-1])
    meta["current_price"] = round(current, 2)

    # 1. RSI oversold
    rsi_val = float(_rsi(close).iloc[-1])
    meta["rsi"] = round(rsi_val, 2)
    if rsi_val < 35:
        score += 1
        crit.append(f"RSI oversold ({rsi_val:.1f})")

    # 2. Near Bollinger Lower Band (within 2 %)
    bb_lo = _bb_lower(close)
    if current <= bb_lo * 1.02:
        score += 1
        crit.append(f"Near BB Lower (${bb_lo:.2f})")

    # 3. Near 52-week low (within 10 %)
    window  = min(252, len(close))
    low_52w = float(close.tail(window).min())
    if current <= low_52w * 1.10:
        score += 1
        crit.append(f"Near 52w Low (${low_52w:.2f})")

    # 4. Golden Cross within last 20 trading days
    if len(close) >= 200:
        sma50  = close.rolling(50).mean()
        sma200 = close.rolling(200).mean()
        for i in range(-20, -1):
            try:
                if sma50.iloc[i - 1] <= sma200.iloc[i - 1] and sma50.iloc[i] > sma200.iloc[i]:
                    score += 1
                    crit.append("Golden Cross (MA50 ✕ MA200)")
                    break
            except IndexError:
                pass

    # 5. Fibonacci 38.2 / 50 / 61.8 % retracement (within 2 %)
    high_52w = float(close.tail(window).max())
    swing    = high_52w - low_52w
    fib_map  = {
        "38.2%": high_52w - 0.382 * swing,
        "50.0%": high_52w - 0.500 * swing,
        "61.8%": high_52w - 0.618 * swing,
    }
    for label, level in fib_map.items():
        if swing > 0 and abs(current - level) / max(level, 0.01) <= 0.02:
            score += 1
            crit.append(f"Fibonacci {label} (${level:.2f})")
            meta["fib_level"] = label
            break

    return score, crit, meta


# ── Public API ────────────────────────────────────────────────────────────────

def scan_pool(tickers: list[str]) -> list[ScanResult]:
    """
    Scan *tickers* and return those scoring ≥ UNIVERSE_MIN_SCORE,
    sorted by score descending.
    """
    results: list[ScanResult] = []

    for ticker in tickers:
        try:
            df = fetch_stock_data(ticker, period="1y")
            if df is None or len(df) < 60:
                continue
            score, crit, meta = _score_df(df)
            if score >= UNIVERSE_MIN_SCORE:
                results.append(ScanResult(
                    ticker=ticker,
                    score=score,
                    criteria_matched=crit,
                    current_price=meta.get("current_price"),
                    rsi=meta.get("rsi"),
                    fib_level=meta.get("fib_level"),
                ))
        except Exception as exc:
            print(f"[scanner] {ticker}: {exc}")

    return sorted(results, key=lambda r: r.score, reverse=True)
