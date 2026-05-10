"""
WebSocket Manager
=================
Tracks all active Flutter WebSocket connections.
Broadcasts structured events whenever signals are refreshed
so Flutter updates UI in real-time without polling.

Event schema
  { "event": "<event_name>", "data": { ... } }

Events
  signals.updated      → one ticker's signal refreshed
  checklist.triggered  → a checklist item hit its target price
  portfolio.updated    → a position was added / removed
"""

from __future__ import annotations

import json
from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self._active: list[WebSocket] = []

    async def connect(self, ws: WebSocket) -> None:
        await ws.accept()
        self._active.append(ws)
        print(f"[ws] +1 client  (total {len(self._active)})")

    def disconnect(self, ws: WebSocket) -> None:
        self._active = [c for c in self._active if c is not ws]
        print(f"[ws] -1 client  (total {len(self._active)})")

    @property
    def connection_count(self) -> int:
        return len(self._active)

    async def broadcast(self, event: str, data: dict) -> None:
        """Send event to every connected client; drop stale connections."""
        message = json.dumps({"event": event, "data": data})
        stale: list[WebSocket] = []
        for ws in list(self._active):
            try:
                await ws.send_text(message)
            except Exception:
                stale.append(ws)
        for ws in stale:
            self.disconnect(ws)

    async def send_to(self, ws: WebSocket, event: str, data: dict) -> None:
        """Send event to one client."""
        await ws.send_text(json.dumps({"event": event, "data": data}))


# Singleton — imported everywhere
manager = ConnectionManager()
