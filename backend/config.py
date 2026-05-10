import os
from dotenv import load_dotenv

load_dotenv()

# ── Database ───────────────────────────────────────────────────────────────────
DATABASE_URL: str = os.getenv(
    "DATABASE_URL",
    "postgresql://trading_user:trading_pass@localhost:5432/trading_dss",
)

# ── Redis ──────────────────────────────────────────────────────────────────────
REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")

# ── Discord ────────────────────────────────────────────────────────────────────
DISCORD_WEBHOOK_URL: str = os.getenv("DISCORD_WEBHOOK_URL", "")

# ── Scheduler ──────────────────────────────────────────────────────────────────
SIGNAL_REFRESH_INTERVAL_MINUTES: int = int(
    os.getenv("SIGNAL_REFRESH_INTERVAL", "30")
)

# ── Data ───────────────────────────────────────────────────────────────────────
DATA_PERIOD: str = "6mo"
CORS_ORIGINS: list[str] = ["*"]

# ── Universe scanner ───────────────────────────────────────────────────────────
UNIVERSE_MIN_SCORE: int = 3   # criteria out of 5 needed to enter universe
