from __future__ import annotations
from datetime import datetime
from sqlalchemy import (
    create_engine, Column, Integer, String,
    Float, DateTime, Text, Boolean, JSON,
)
from sqlalchemy.orm import declarative_base, sessionmaker
from config import DATABASE_URL

engine       = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base         = declarative_base()


# ── Existing tables ────────────────────────────────────────────────────────────

class Stock(Base):
    __tablename__ = "stocks"
    id        = Column(Integer, primary_key=True)
    ticker    = Column(String, unique=True, index=True, nullable=False)
    name      = Column(String, default="")
    sector    = Column(String, default="Unknown")
    added_at  = Column(DateTime, default=datetime.utcnow)
    is_active = Column(Boolean, default=True)


class Watchlist(Base):
    __tablename__ = "watchlist"
    id           = Column(Integer, primary_key=True)
    ticker       = Column(String, unique=True, index=True, nullable=False)
    notes        = Column(Text, default="")
    target_price = Column(Float, nullable=True)
    stop_loss    = Column(Float, nullable=True)
    added_at     = Column(DateTime, default=datetime.utcnow)


class Signal(Base):
    __tablename__ = "signals"
    id                = Column(Integer, primary_key=True)
    ticker            = Column(String, index=True, nullable=False)
    timestamp         = Column(DateTime, default=datetime.utcnow, index=True)
    ma_signal         = Column(String)
    rsi_signal        = Column(String)
    macd_signal       = Column(String)
    bb_signal         = Column(String)
    momentum_signal   = Column(String)
    overall_signal    = Column(String)
    confidence        = Column(Float)
    current_price     = Column(Float)
    rsi_value         = Column(Float)
    macd_value        = Column(Float)
    macd_signal_value = Column(Float)
    bb_upper          = Column(Float)
    bb_lower          = Column(Float)
    bb_middle         = Column(Float)
    sma20             = Column(Float)
    sma50             = Column(Float)
    momentum_value    = Column(Float)
    fundamental_ok    = Column(Boolean, nullable=True)
    fundamental_warn  = Column(Text, nullable=True)


class Alert(Base):
    __tablename__ = "alerts"
    id           = Column(Integer, primary_key=True)
    ticker       = Column(String, index=True)
    message      = Column(Text)
    signal       = Column(String)
    price        = Column(Float)
    created_at   = Column(DateTime, default=datetime.utcnow, index=True)
    discord_sent = Column(Boolean, default=False)


class FundamentalData(Base):
    __tablename__ = "fundamentals"
    id              = Column(Integer, primary_key=True)
    ticker          = Column(String, unique=True, index=True)
    updated_at      = Column(DateTime, default=datetime.utcnow)
    name            = Column(String, default="")
    sector          = Column(String, default="Unknown")
    market_cap      = Column(Float, nullable=True)
    pe_ratio        = Column(Float, nullable=True)
    forward_pe      = Column(Float, nullable=True)
    eps_ttm         = Column(Float, nullable=True)
    revenue_growth  = Column(Float, nullable=True)
    profit_margin   = Column(Float, nullable=True)
    debt_to_equity  = Column(Float, nullable=True)
    price_to_book   = Column(Float, nullable=True)
    dividend_yield  = Column(Float, nullable=True)
    passes_filter   = Column(Boolean, default=True)
    filter_warnings = Column(Text, default="[]")


# ── New tables ─────────────────────────────────────────────────────────────────

class UniversePool(Base):
    """Raw ticker pool uploaded via CSV or added manually."""
    __tablename__ = "universe_pool"
    ticker     = Column(String, primary_key=True, index=True)
    source     = Column(String, default="manual")   # csv | manual
    added_at   = Column(DateTime, default=datetime.utcnow)


class Universe(Base):
    """Tickers that passed the auto-scan or were manually promoted."""
    __tablename__ = "universe"
    id               = Column(Integer, primary_key=True)
    ticker           = Column(String, unique=True, index=True, nullable=False)
    added_by         = Column(String, default="manual")  # manual | scan
    scan_score       = Column(Integer, default=0)
    criteria_matched = Column(JSON, default=list)         # list of strings
    current_price    = Column(Float, nullable=True)
    rsi              = Column(Float, nullable=True)
    fib_level        = Column(String, nullable=True)
    notes            = Column(Text, default="")
    added_at         = Column(DateTime, default=datetime.utcnow)


class Checklist(Base):
    """Stocks in the buy watchlist with a target price gate."""
    __tablename__ = "checklist"
    id                 = Column(Integer, primary_key=True)
    ticker             = Column(String, index=True, nullable=False)
    target_price       = Column(Float, nullable=False)
    suggested_price    = Column(Float, nullable=True)
    suggestion_method  = Column(String, nullable=True)  # "BB Lower" | etc.
    # Price levels for reference
    fib_382            = Column(Float, nullable=True)
    fib_500            = Column(Float, nullable=True)
    fib_618            = Column(Float, nullable=True)
    high_52w           = Column(Float, nullable=True)
    low_52w            = Column(Float, nullable=True)
    status             = Column(String, default="WAITING")
    # WAITING → TRIGGERED → BOUGHT | EXPIRED
    notes              = Column(Text, default="")
    created_at         = Column(DateTime, default=datetime.utcnow)
    triggered_at       = Column(DateTime, nullable=True)
    resolved_at        = Column(DateTime, nullable=True)


class Position(Base):
    """Actual portfolio holdings with cost basis."""
    __tablename__ = "positions"
    id                   = Column(Integer, primary_key=True)
    ticker               = Column(String, index=True, nullable=False)
    shares               = Column(Float, nullable=False)
    cost_basis_per_share = Column(Float, nullable=False)
    date_bought          = Column(DateTime, nullable=True)
    checklist_id         = Column(Integer, nullable=True)  # source checklist item
    notes                = Column(Text, default="")
    added_at             = Column(DateTime, default=datetime.utcnow)


class StockCache(Base):
    """Persistent cache for stock data to fallback on API failures."""
    __tablename__ = "stock_cache"
    id          = Column(Integer, primary_key=True)
    ticker      = Column(String, unique=True, index=True, nullable=False)
    price       = Column(Float, nullable=True)
    signals     = Column(JSON, nullable=True)
    indicators  = Column(JSON, nullable=True)
    updated_at  = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


# ── Helpers ───────────────────────────────────────────────────────────────────

def create_tables() -> None:
    Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
