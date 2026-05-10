"""
Discord Alert
=============
Sends a rich embed to a Discord webhook when a BUY or SELL signal fires.
Set DISCORD_WEBHOOK_URL in .env to activate.
"""

from __future__ import annotations

import httpx
from datetime import datetime, timezone
from config import DISCORD_WEBHOOK_URL

# Embed colours (Discord uses decimal integers)
_COLORS = {"BUY": 0x00D26A, "SELL": 0xFF4757, "HOLD": 0xFFA502}
_EMOJIS = {"BUY": "🟢", "SELL": "🔴", "HOLD": "🟡"}


async def send_discord_alert(
    ticker:          str,
    signal:          str,
    price:           float,
    confidence:      float,
    rsi:             float,
    macd:            float,
    ma_signal:       str,
    bb_signal:       str,
    momentum_signal: str,
) -> bool:
    """Post an embed to Discord.  Returns True if successful."""
    if not DISCORD_WEBHOOK_URL:
        print("[discord] No webhook URL configured – skipping.")
        return False

    emoji  = _EMOJIS.get(signal, "⚪")
    color  = _COLORS.get(signal, 0x888888)
    now_ts = datetime.now(timezone.utc).isoformat()

    sub_signals = (
        f"MA `{ma_signal}` · BB `{bb_signal}` · Momentum `{momentum_signal}`"
    )

    embed = {
        "title":       f"{emoji}  {ticker} — **{signal}** Signal",
        "color":       color,
        "description": sub_signals,
        "fields": [
            {"name": "💰 Price",      "value": f"${price:.2f}",      "inline": True},
            {"name": "📊 Confidence", "value": f"{confidence:.0f}%", "inline": True},
            {"name": "📈 RSI (14)",   "value": f"{rsi:.1f}",         "inline": True},
            {"name": "MACD",          "value": f"{macd:.4f}",         "inline": True},
        ],
        "footer":    {"text": "Stock Trading DSS  •  US Market"},
        "timestamp": now_ts,
    }

    payload = {
        "username":   "Trading DSS Bot",
        "avatar_url": "https://i.imgur.com/AfFp7pu.png",
        "embeds":     [embed],
    }

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.post(DISCORD_WEBHOOK_URL, json=payload)
            return r.status_code in (200, 204)
    except Exception as exc:
        print(f"[discord] Failed to send alert: {exc}")
        return False
