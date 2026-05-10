"""
Signal Engine
=============
Calculates five technical indicators and combines them into a single
BUY / SELL / HOLD decision with a confidence score.

Indicators
----------
1. MA Crossover  – SMA-20 vs SMA-50
2. RSI           – 14-period, overbought >70, oversold <30
3. MACD          – (12, 26, 9) crossover of MACD line vs signal line
4. Bollinger Bands – 20-period / 2 std; price touches band
5. Momentum (ROC) – 10-day Rate-of-Change, threshold ±2 %
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from dataclasses import dataclass
from typing import Optional


# ─── Result container ──────────────────────────────────────────────────────────

@dataclass
class SignalResult:
    ticker:            str
    current_price:     float
    # individual signals
    ma_signal:         str
    rsi_signal:        str
    macd_signal:       str
    bb_signal:         str
    momentum_signal:   str
    # aggregated
    overall_signal:    str
    confidence:        float        # 0–100
    # raw values
    rsi_value:         float
    macd_value:        float
    macd_signal_value: float
    bb_upper:          float
    bb_lower:          float
    bb_middle:         float
    sma20:             float
    sma50:             float
    momentum_value:    float


# ─── Indicator helpers ─────────────────────────────────────────────────────────

def _rsi(prices: pd.Series, period: int = 14) -> pd.Series:
    delta = prices.diff()
    gain  = delta.clip(lower=0).rolling(period).mean()
    loss  = (-delta.clip(upper=0)).rolling(period).mean()
    rs    = gain / loss.replace(0, np.nan)
    return 100 - (100 / (1 + rs))


def _macd(prices: pd.Series, fast: int = 12, slow: int = 26, sig: int = 9):
    ema_fast   = prices.ewm(span=fast, adjust=False).mean()
    ema_slow   = prices.ewm(span=slow, adjust=False).mean()
    macd_line  = ema_fast - ema_slow
    signal_line = macd_line.ewm(span=sig, adjust=False).mean()
    return macd_line, signal_line


def _bollinger(prices: pd.Series, period: int = 20, n_std: float = 2.0):
    sma    = prices.rolling(period).mean()
    std    = prices.rolling(period).std()
    upper  = sma + n_std * std
    lower  = sma - n_std * std
    return upper, sma, lower


# ─── Main function ─────────────────────────────────────────────────────────────

def calculate_signals(df: pd.DataFrame, ticker: str) -> Optional[SignalResult]:
    """
    Accepts a DataFrame with at least a 'Close' column (60+ rows).
    Returns None if data is insufficient.
    """
    if df is None or len(df) < 60:
        return None

    close = df["Close"].squeeze()   # ensure Series even if multi-column

    # ── 1. MA Crossover ────────────────────────────────────────────────────────
    sma20 = close.rolling(20).mean()
    sma50 = close.rolling(50).mean()

    c20, p20 = float(sma20.iloc[-1]), float(sma20.iloc[-2])
    c50, p50 = float(sma50.iloc[-1]), float(sma50.iloc[-2])

    if p20 <= p50 and c20 > c50:
        ma_signal = "BUY"       # fresh golden cross
    elif p20 >= p50 and c20 < c50:
        ma_signal = "SELL"      # fresh death cross
    elif c20 > c50:
        ma_signal = "BUY"       # already above
    else:
        ma_signal = "SELL"

    # ── 2. RSI ─────────────────────────────────────────────────────────────────
    rsi_series = _rsi(close)
    rsi_val    = float(rsi_series.iloc[-1])

    if rsi_val < 30:
        rsi_signal = "BUY"
    elif rsi_val > 70:
        rsi_signal = "SELL"
    else:
        rsi_signal = "HOLD"

    # ── 3. MACD ────────────────────────────────────────────────────────────────
    macd_line, sig_line = _macd(close)
    cM, pM = float(macd_line.iloc[-1]), float(macd_line.iloc[-2])
    cS, pS = float(sig_line.iloc[-1]),  float(sig_line.iloc[-2])

    if pM <= pS and cM > cS:
        macd_signal = "BUY"
    elif pM >= pS and cM < cS:
        macd_signal = "SELL"
    elif cM > cS:
        macd_signal = "BUY"
    else:
        macd_signal = "SELL"

    # ── 4. Bollinger Bands ─────────────────────────────────────────────────────
    bb_upper, bb_mid, bb_lower = _bollinger(close)
    price      = float(close.iloc[-1])
    bb_up_val  = float(bb_upper.iloc[-1])
    bb_lo_val  = float(bb_lower.iloc[-1])
    bb_mi_val  = float(bb_mid.iloc[-1])

    if price <= bb_lo_val:
        bb_signal = "BUY"
    elif price >= bb_up_val:
        bb_signal = "SELL"
    else:
        bb_signal = "HOLD"

    # ── 5. Momentum (10-day ROC) ───────────────────────────────────────────────
    roc_period = 10
    roc = ((close.iloc[-1] - close.iloc[-roc_period]) / close.iloc[-roc_period]) * 100
    mom_val = float(roc)

    if mom_val > 2:
        momentum_signal = "BUY"
    elif mom_val < -2:
        momentum_signal = "SELL"
    else:
        momentum_signal = "HOLD"

    # ── Aggregate: majority vote ───────────────────────────────────────────────
    votes = [ma_signal, rsi_signal, macd_signal, bb_signal, momentum_signal]
    buy_n  = votes.count("BUY")
    sell_n = votes.count("SELL")
    hold_n = votes.count("HOLD")

    if buy_n >= 3:
        overall_signal = "BUY"
        confidence     = (buy_n / 5) * 100
    elif sell_n >= 3:
        overall_signal = "SELL"
        confidence     = (sell_n / 5) * 100
    else:
        overall_signal = "HOLD"
        confidence     = max(hold_n / 5, 0.4) * 100

    return SignalResult(
        ticker=ticker,
        current_price=price,
        ma_signal=ma_signal,
        rsi_signal=rsi_signal,
        macd_signal=macd_signal,
        bb_signal=bb_signal,
        momentum_signal=momentum_signal,
        overall_signal=overall_signal,
        confidence=round(confidence, 1),
        rsi_value=round(rsi_val, 2),
        macd_value=round(cM, 4),
        macd_signal_value=round(cS, 4),
        bb_upper=round(bb_up_val, 2),
        bb_lower=round(bb_lo_val, 2),
        bb_middle=round(bb_mi_val, 2),
        sma20=round(c20, 2),
        sma50=round(c50, 2),
        momentum_value=round(mom_val, 2),
    )
