"""
Fundamental Filter
==================
Fetches key fundamental metrics via yfinance and scores each stock
against configurable quality thresholds.

Checks (BUY signal is flagged if any fail):
  • Market Cap  ≥ $1 B  (avoid penny / micro-cap stocks)
  • EPS (TTM)   > 0     (must be profitable)
  • P/E ratio   < 60    (not wildly overvalued)
  • Debt/Equity < 3.0   (not over-leveraged)
"""

from __future__ import annotations

import yfinance as yf
from dataclasses import dataclass, field
from typing import Optional


# ── Quality thresholds (tune to your strategy) ────────────────────────────────

THRESHOLDS: dict = {
    "min_market_cap":   1_000_000_000,   # $1 B
    "min_eps":          0.0,
    "max_pe":           60.0,
    "max_debt_equity":  3.0,             # ratio (not percentage)
}


# ── Data container ────────────────────────────────────────────────────────────

@dataclass
class FundamentalData:
    ticker:          str
    name:            str
    sector:          str
    # Metrics
    market_cap:      Optional[float] = None   # USD
    pe_ratio:        Optional[float] = None
    forward_pe:      Optional[float] = None
    eps_ttm:         Optional[float] = None
    revenue_growth:  Optional[float] = None   # YoY decimal (0.12 = 12%)
    profit_margin:   Optional[float] = None
    debt_to_equity:  Optional[float] = None   # ratio
    price_to_book:   Optional[float] = None
    dividend_yield:  Optional[float] = None
    # Quality verdict
    passes_filter:   bool        = True
    filter_warnings: list[str]   = field(default_factory=list)


# ── Main function ─────────────────────────────────────────────────────────────

def fetch_fundamentals(ticker: str) -> FundamentalData:
    """
    Fetch and evaluate fundamental data for *ticker*.
    Returns a FundamentalData dataclass.  Never raises.
    """
    try:
        info = yf.Ticker(ticker).info or {}
    except Exception as exc:
        print(f"[fundamental] {ticker}: {exc}")
        info = {}

    def _float(key: str) -> Optional[float]:
        v = info.get(key)
        return float(v) if v is not None else None

    # ── Raw metrics ───────────────────────────────────────────────────────────
    market_cap     = _float("marketCap")
    pe_ratio       = _float("trailingPE")
    forward_pe     = _float("forwardPE")
    eps_ttm        = _float("trailingEps")
    revenue_growth = _float("revenueGrowth")
    profit_margin  = _float("profitMargins")
    raw_de         = _float("debtToEquity")
    price_to_book  = _float("priceToBook")
    dividend_yield = _float("dividendYield")

    # yfinance sometimes returns D/E as a percentage (e.g. 150 instead of 1.5)
    debt_to_equity: Optional[float] = None
    if raw_de is not None:
        debt_to_equity = raw_de / 100 if raw_de > 20 else raw_de

    # ── Quality checks ────────────────────────────────────────────────────────
    warnings: list[str] = []

    if market_cap is not None and market_cap < THRESHOLDS["min_market_cap"]:
        warnings.append(
            f"Small-cap ${market_cap / 1e9:.2f}B "
            f"(threshold ≥${THRESHOLDS['min_market_cap'] / 1e9:.0f}B)"
        )

    if eps_ttm is not None and eps_ttm < THRESHOLDS["min_eps"]:
        warnings.append(f"Unprofitable — EPS {eps_ttm:.2f}")

    if pe_ratio is not None and pe_ratio > THRESHOLDS["max_pe"]:
        warnings.append(
            f"High valuation — P/E {pe_ratio:.1f} "
            f"(threshold < {THRESHOLDS['max_pe']})"
        )

    if debt_to_equity is not None and debt_to_equity > THRESHOLDS["max_debt_equity"]:
        warnings.append(
            f"High leverage — D/E {debt_to_equity:.2f} "
            f"(threshold < {THRESHOLDS['max_debt_equity']})"
        )

    return FundamentalData(
        ticker=ticker,
        name=info.get("longName") or ticker,
        sector=info.get("sector") or "Unknown",
        market_cap=market_cap,
        pe_ratio=pe_ratio,
        forward_pe=forward_pe,
        eps_ttm=eps_ttm,
        revenue_growth=revenue_growth,
        profit_margin=profit_margin,
        debt_to_equity=debt_to_equity,
        price_to_book=price_to_book,
        dividend_yield=dividend_yield,
        passes_filter=len(warnings) == 0,
        filter_warnings=warnings,
    )
