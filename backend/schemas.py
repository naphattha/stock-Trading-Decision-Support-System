from __future__ import annotations
from pydantic import BaseModel, field_validator
from typing import Optional, List, Any
from datetime import datetime


# ── Watchlist ──────────────────────────────────────────────────────────────────
class WatchlistCreate(BaseModel):
    ticker: str; notes: Optional[str] = ""; target_price: Optional[float] = None; stop_loss: Optional[float] = None
    @field_validator("ticker")
    @classmethod
    def up(cls, v): return v.strip().upper()
class WatchlistResponse(BaseModel):
    id: int; ticker: str; notes: str; target_price: Optional[float]; stop_loss: Optional[float]; added_at: datetime
    model_config = {"from_attributes": True}

# ── Signal ─────────────────────────────────────────────────────────────────────
class SignalResponse(BaseModel):
    id: int; ticker: str; timestamp: datetime
    ma_signal: Optional[str]; rsi_signal: Optional[str]; macd_signal: Optional[str]
    bb_signal: Optional[str]; momentum_signal: Optional[str]; overall_signal: Optional[str]
    confidence: Optional[float]; current_price: Optional[float]; rsi_value: Optional[float]
    macd_value: Optional[float]; macd_signal_value: Optional[float]
    bb_upper: Optional[float]; bb_lower: Optional[float]; bb_middle: Optional[float]
    sma20: Optional[float]; sma50: Optional[float]; momentum_value: Optional[float]
    fundamental_ok: Optional[bool]; fundamental_warn: Optional[str]
    model_config = {"from_attributes": True}

# ── Alert ──────────────────────────────────────────────────────────────────────
class AlertResponse(BaseModel):
    id: int; ticker: str; message: str; signal: str; price: float; created_at: datetime; discord_sent: bool
    model_config = {"from_attributes": True}

# ── Portfolio summary ──────────────────────────────────────────────────────────
class PortfolioSummary(BaseModel):
    total_stocks: int; buy_signals: int; sell_signals: int; hold_signals: int; no_signal: int; last_updated: str

# ── Fundamental ────────────────────────────────────────────────────────────────
class FundamentalResponse(BaseModel):
    ticker: str; name: str; sector: str
    market_cap: Optional[float]; pe_ratio: Optional[float]; forward_pe: Optional[float]
    eps_ttm: Optional[float]; revenue_growth: Optional[float]; profit_margin: Optional[float]
    debt_to_equity: Optional[float]; price_to_book: Optional[float]; dividend_yield: Optional[float]
    passes_filter: bool; filter_warnings: List[str]; updated_at: Optional[datetime] = None
    model_config = {"from_attributes": True}

# ── Regime ─────────────────────────────────────────────────────────────────────
class RegimeResponse(BaseModel):
    ticker: str; adx: float; plus_di: float; minus_di: float
    regime: str; regime_strength: str; bb_width: float; volatility_regime: str
    daily_signal: Optional[str]; weekly_signal: Optional[str]
    mtf_confluence: bool; mtf_strength: str; recommended_strategy: str; strategy_note: str

# ── Risk ───────────────────────────────────────────────────────────────────────
class RiskResponse(BaseModel):
    ticker: str; entry_price: float; atr: float
    suggested_stop_loss: float; suggested_take_profit: float; rr_ratio: float
    fixed_1pct_shares: int; fixed_1pct_value: float; fixed_2pct_shares: int; fixed_2pct_value: float
    historical_win_rate: Optional[float]; kelly_fraction: Optional[float]
    kelly_shares: Optional[int]; kelly_value: Optional[float]; kelly_note: str

# ── Universe Pool ──────────────────────────────────────────────────────────────
class UniversePoolItem(BaseModel):
    ticker: str; source: str; added_at: datetime
    model_config = {"from_attributes": True}

# ── Universe ───────────────────────────────────────────────────────────────────
class UniverseCreate(BaseModel):
    ticker: str; notes: Optional[str] = ""
    @field_validator("ticker")
    @classmethod
    def up(cls, v): return v.strip().upper()
class UniverseResponse(BaseModel):
    id: int; ticker: str; added_by: str; scan_score: int
    criteria_matched: Any; current_price: Optional[float]; rsi: Optional[float]
    fib_level: Optional[str]; notes: str; added_at: datetime
    model_config = {"from_attributes": True}
class ScanResultResponse(BaseModel):
    ticker: str; score: int; criteria_matched: List[str]
    current_price: Optional[float]; rsi: Optional[float]; fib_level: Optional[str]

# ── Checklist ──────────────────────────────────────────────────────────────────
class ChecklistCreate(BaseModel):
    ticker: str; target_price: float; notes: Optional[str] = ""
    @field_validator("ticker")
    @classmethod
    def up(cls, v): return v.strip().upper()
class ChecklistResponse(BaseModel):
    id: int; ticker: str; target_price: float; suggested_price: Optional[float]
    suggestion_method: Optional[str]; fib_382: Optional[float]; fib_500: Optional[float]
    fib_618: Optional[float]; high_52w: Optional[float]; low_52w: Optional[float]
    status: str; notes: str; created_at: datetime
    triggered_at: Optional[datetime]; resolved_at: Optional[datetime]
    model_config = {"from_attributes": True}
class BuyPriceResponse(BaseModel):
    ticker: str; current_price: float; suggested_buy_price: float; suggestion_method: str
    bb_lower: float; support_20d: float; fib_382: float; fib_500: float; fib_618: float
    high_52w: float; low_52w: float; upside_to_fib_382: float; upside_to_52w_high: float

# ── Portfolio ──────────────────────────────────────────────────────────────────
class PositionCreate(BaseModel):
    ticker: str; shares: float; cost_basis_per_share: float
    date_bought: Optional[str] = None; checklist_id: Optional[int] = None; notes: Optional[str] = ""
    @field_validator("ticker")
    @classmethod
    def up(cls, v): return v.strip().upper()
class PositionResponse(BaseModel):
    id: int; ticker: str; shares: float; cost_basis_per_share: float
    date_bought: Optional[datetime]; checklist_id: Optional[int]; notes: str; added_at: datetime
    model_config = {"from_attributes": True}
class HoldingResponse(BaseModel):
    ticker: str; shares: float; cost_basis_per_share: float; current_price: float
    market_value: float; cost_basis_total: float; unrealized_pnl: float; pnl_pct: float
    actual_weight: float; target_weight: float; weight_diff: float
    date_bought: Optional[str]; notes: str
class PortfolioSnapshotResponse(BaseModel):
    holdings: List[HoldingResponse]; total_value: float; total_cost: float
    total_pnl: float; total_pnl_pct: float; equal_weight_pct: float
class RecommendationResponse(BaseModel):
    ticker: str; current_price: float; target_price: float
    signal: str; confidence: float; upside_pct: float; reason: str
