"""
Redis Cache Layer
=================
Key patterns
  signal:{ticker}       → latest SignalResult JSON      TTL 30 min
  portfolio:snapshot    → full portfolio P&L snapshot   TTL  5 min
  universe:scan         → last auto-scan output         TTL 60 min
  checklist:status      → triggered checklist items     TTL 10 min
"""

from __future__ import annotations

import json
import redis
from typing import Optional
from config import REDIS_URL

_client: Optional[redis.Redis] = None

TTL_SIGNAL    = 30 * 60
TTL_PORTFOLIO =  5 * 60
TTL_SCAN      = 60 * 60
TTL_CHECKLIST = 10 * 60


def _r() -> redis.Redis:
    global _client
    if _client is None:
        _client = redis.from_url(REDIS_URL, decode_responses=True)
    return _client


# ── Signal ─────────────────────────────────────────────────────────────────────

def set_signal(ticker: str, data: dict) -> None:
    _r().setex(f"signal:{ticker}", TTL_SIGNAL, json.dumps(data))

def get_signal(ticker: str) -> Optional[dict]:
    raw = _r().get(f"signal:{ticker}")
    return json.loads(raw) if raw else None

def invalidate_signal(ticker: str) -> None:
    _r().delete(f"signal:{ticker}")

def invalidate_all_signals() -> None:
    keys = _r().keys("signal:*")
    if keys:
        _r().delete(*keys)


# ── Portfolio ──────────────────────────────────────────────────────────────────

def set_portfolio(data: list) -> None:
    _r().setex("portfolio:snapshot", TTL_PORTFOLIO, json.dumps(data))

def get_portfolio() -> Optional[list]:
    raw = _r().get("portfolio:snapshot")
    return json.loads(raw) if raw else None

def invalidate_portfolio() -> None:
    _r().delete("portfolio:snapshot")


# ── Universe scan ──────────────────────────────────────────────────────────────

def set_scan(data: list) -> None:
    _r().setex("universe:scan", TTL_SCAN, json.dumps(data))

def get_scan() -> Optional[list]:
    raw = _r().get("universe:scan")
    return json.loads(raw) if raw else None

def invalidate_scan() -> None:
    _r().delete("universe:scan")


# ── Checklist ──────────────────────────────────────────────────────────────────

def set_checklist_triggered(data: list) -> None:
    _r().setex("checklist:triggered", TTL_CHECKLIST, json.dumps(data))

def get_checklist_triggered() -> Optional[list]:
    raw = _r().get("checklist:triggered")
    return json.loads(raw) if raw else None

def invalidate_checklist() -> None:
    _r().delete("checklist:triggered")


# ── Health ─────────────────────────────────────────────────────────────────────

def ping() -> bool:
    try:
        _r().ping()
        return True
    except Exception:
        return False
