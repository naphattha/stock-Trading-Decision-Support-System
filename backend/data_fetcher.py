"""
Data Fetcher
============
Thin wrapper around yfinance.  All network calls are isolated here
so they can be swapped for a paid data provider without touching
signal_engine.py.
"""

from __future__ import annotations

import yfinance as yf
import pandas as pd
from typing import Optional


def fetch_stock_data(ticker: str, period: str = "6mo") -> Optional[pd.DataFrame]:
    """Return OHLCV DataFrame or None on failure."""
    try:
        df = yf.Ticker(ticker).history(period=period)
        if df.empty:
            return None
        df.index = pd.to_datetime(df.index)
        return df
    except Exception as exc:
        print(f"[data_fetcher] {ticker}: {exc}")
        return None


def fetch_stock_info(ticker: str) -> dict:
    """Return basic metadata (name, sector …).  Never raises."""
    defaults = {
        "name":       ticker,
        "sector":     "Unknown",
        "industry":   "Unknown",
        "market_cap": 0,
        "currency":   "USD",
    }
    try:
        info = yf.Ticker(ticker).info
        return {
            "name":       info.get("longName")    or ticker,
            "sector":     info.get("sector")      or "Unknown",
            "industry":   info.get("industry")    or "Unknown",
            "market_cap": info.get("marketCap")   or 0,
            "currency":   info.get("currency")    or "USD",
        }
    except Exception:
        return defaults
