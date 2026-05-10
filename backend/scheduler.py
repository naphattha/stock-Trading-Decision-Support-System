"""
Scheduler
=========
Runs the signal-refresh job in the background at a configurable interval.
Integrates with FastAPI's lifespan using AsyncIOScheduler.
"""

from __future__ import annotations

from typing import Callable, Awaitable
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.interval import IntervalTrigger
from config import SIGNAL_REFRESH_INTERVAL_MINUTES

_scheduler = AsyncIOScheduler()


def start(refresh_fn: Callable[[], Awaitable[None]]) -> None:
    """Add the refresh job and start the scheduler."""
    _scheduler.add_job(
        refresh_fn,
        trigger=IntervalTrigger(minutes=SIGNAL_REFRESH_INTERVAL_MINUTES),
        id="signal_refresh",
        name="Auto Signal Refresh",
        replace_existing=True,
        misfire_grace_time=60,
    )
    _scheduler.start()
    print(
        f"[scheduler] Started – refreshing signals every "
        f"{SIGNAL_REFRESH_INTERVAL_MINUTES} min."
    )


def stop() -> None:
    if _scheduler.running:
        _scheduler.shutdown(wait=False)
        print("[scheduler] Stopped.")
