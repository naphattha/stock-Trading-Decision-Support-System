"""
Market Regime & Multi-Timeframe Analysis
=========================================
Regime detection  – ADX (14): TRENDING / WEAK_TREND / RANGING
Volatility regime – Bollinger Band Width: HIGH / NORMAL / LOW
Multi-timeframe   – Daily vs Weekly signal confluence

Strategy recommendation adapts to the detected regime so the caller
knows which indicators to trust most.
"""

from __future__ import annotations

import numpy as np
import pandas as pd
from dataclasses import dataclass
from typing import Optional

from signal_engine import calculate_signals


# ── Result container ──────────────────────────────────────────────────────────

@dataclass
class RegimeResult:
    ticker:                str
    # ADX
    adx:                   float
    plus_di:               float
    minus_di:              float
    regime:                str        # TRENDING | WEAK_TREND | RANGING
    regime_strength:       str        # STRONG | MODERATE | WEAK
    # Volatility
    bb_width:              float      # Bollinger Band Width %
    volatility_regime:     str        # HIGH | NORMAL | LOW
    # Multi-timeframe
    daily_signal:          Optional[str]
    weekly_signal:         Optional[str]
    mtf_confluence:        bool
    mtf_strength:          str        # STRONG | CONFLICTED | NEUTRAL
    # Recommendation
    recommended_strategy:  str
    strategy_note:         str


# ── Indicator helpers ─────────────────────────────────────────────────────────

def _calc_adx(
    df: pd.DataFrame, period: int = 14
) -> tuple[float, float, float]:
    high  = df["High"].squeeze()
    low   = df["Low"].squeeze()
    close = df["Close"].squeeze()

    up   = high - high.shift()
    down = low.shift() - low

    pos_dm = up.where((up > down) & (up > 0), 0.0)
    neg_dm = down.where((down > up) & (down > 0), 0.0)

    tr = pd.concat([
        high - low,
        (high - close.shift()).abs(),
        (low  - close.shift()).abs(),
    ], axis=1).max(axis=1)

    atr    = tr.ewm(span=period, adjust=False).mean()
    pos_di = 100 * pos_dm.ewm(span=period, adjust=False).mean() / atr
    neg_di = 100 * neg_dm.ewm(span=period, adjust=False).mean() / atr

    dx  = 100 * (pos_di - neg_di).abs() / (pos_di + neg_di).replace(0, np.nan)
    adx = dx.ewm(span=period, adjust=False).mean()

    return (
        float(adx.iloc[-1]),
        float(pos_di.iloc[-1]),
        float(neg_di.iloc[-1]),
    )


def _bb_width(close: pd.Series, period: int = 20) -> float:
    """Bollinger Band Width as % of midline."""
    sma   = close.rolling(period).mean()
    std   = close.rolling(period).std()
    upper = sma + 2 * std
    lower = sma - 2 * std
    width = ((upper - lower) / sma) * 100
    return float(width.iloc[-1])


def _to_weekly(df: pd.DataFrame) -> pd.DataFrame:
    return df.resample("W").agg({
        "Open":   "first",
        "High":   "max",
        "Low":    "min",
        "Close":  "last",
        "Volume": "sum",
    }).dropna()


# ── Main ──────────────────────────────────────────────────────────────────────

def analyze_regime(df: pd.DataFrame, ticker: str) -> RegimeResult:
    close = df["Close"].squeeze()

    # ── ADX ───────────────────────────────────────────────────────────────────
    adx, pdi, ndi = _calc_adx(df)

    if adx >= 25:
        regime   = "TRENDING"
        strength = "STRONG" if adx >= 40 else "MODERATE"
    elif adx >= 18:
        regime   = "WEAK_TREND"
        strength = "MODERATE"
    else:
        regime   = "RANGING"
        strength = "WEAK"

    # ── Volatility ────────────────────────────────────────────────────────────
    bw = _bb_width(close)
    if bw > 8:
        vol_regime = "HIGH"
    elif bw > 4:
        vol_regime = "NORMAL"
    else:
        vol_regime = "LOW"

    # ── Multi-timeframe ───────────────────────────────────────────────────────
    daily_sig = None
    result_d  = calculate_signals(df, ticker)
    if result_d:
        daily_sig = result_d.overall_signal

    weekly_df  = _to_weekly(df)
    weekly_sig = None
    if len(weekly_df) >= 30:
        result_w = calculate_signals(weekly_df, ticker)
        if result_w:
            weekly_sig = result_w.overall_signal

    confluence = bool(
        daily_sig and weekly_sig and daily_sig == weekly_sig
    )
    if confluence and daily_sig in ("BUY", "SELL"):
        mtf_strength = "STRONG"
    elif daily_sig == weekly_sig:
        mtf_strength = "NEUTRAL"
    else:
        mtf_strength = "CONFLICTED"

    # ── Strategy recommendation ───────────────────────────────────────────────
    if regime == "TRENDING":
        strategy = "Trend Following — MA Crossover + Momentum"
        note = (
            f"ADX {adx:.1f} confirms a {'strong' if strength == 'STRONG' else 'moderate'} trend. "
            "Favour MA Crossover and Momentum signals. "
            "Use trailing stop-loss. Avoid counter-trend entries."
        )
    elif regime == "RANGING":
        strategy = "Mean Reversion — RSI + Bollinger Bands"
        note = (
            f"ADX {adx:.1f} — market is ranging/consolidating. "
            "RSI and Bollinger Bands are more reliable here. "
            "Buy near the lower band, sell near the upper band. Keep stops tight."
        )
    else:
        strategy = "Wait for Confirmation"
        note = (
            f"ADX {adx:.1f} — trend is weak. "
            "Wait for ADX to rise above 25 (favour trend strategies) "
            "or drop below 18 (favour mean-reversion) before committing."
        )

    if not confluence and daily_sig and weekly_sig:
        note += (
            f" ⚠️ MTF conflict: Daily={daily_sig} vs Weekly={weekly_sig} — "
            "reduce position size until timeframes align."
        )
    elif confluence and daily_sig in ("BUY", "SELL"):
        note += f" ✅ MTF confluence: both timeframes agree on {daily_sig}."

    if vol_regime == "HIGH":
        note += " 📈 High volatility — widen stop-loss and reduce size."
    elif vol_regime == "LOW":
        note += " 📉 Low volatility (squeeze) — a breakout move may be near."

    return RegimeResult(
        ticker=ticker,
        adx=round(adx, 2),
        plus_di=round(pdi, 2),
        minus_di=round(ndi, 2),
        regime=regime,
        regime_strength=strength,
        bb_width=round(bw, 2),
        volatility_regime=vol_regime,
        daily_signal=daily_sig,
        weekly_signal=weekly_sig,
        mtf_confluence=confluence,
        mtf_strength=mtf_strength,
        recommended_strategy=strategy,
        strategy_note=note,
    )
