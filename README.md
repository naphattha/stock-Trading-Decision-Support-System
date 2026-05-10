# 📈 Stock Trading Decision Support System

**Stack:** Python (FastAPI) · SQLite · Dart (Flutter Web)  
**Market:** US Stocks via Yahoo Finance (yfinance)  
**Strategies:** MA Crossover · RSI · MACD · Bollinger Bands · Momentum  
**Alerts:** Discord Webhook + In-App Dashboard

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Flutter Web (Dart)                      │
│  Dashboard ──► Stock Detail  (port 5000 in dev)         │
└────────────────────┬────────────────────────────────────┘
                     │ HTTP / REST
┌────────────────────▼────────────────────────────────────┐
│              FastAPI Backend (Python)                    │
│  /watchlist  /signals  /price  /alerts  /portfolio      │
│  ┌─────────────────┐   ┌──────────────────────────────┐ │
│  │  Signal Engine  │   │  APScheduler (every 30 min)  │ │
│  │  MA · RSI · MACD│   │  auto-refresh all tickers    │ │
│  │  BB · Momentum  │   └──────────────────────────────┘ │
│  └────────┬────────┘                                    │
│           │ yfinance                                    │
│  ┌────────▼──────┐   ┌──────────────────────────────┐  │
│  │  Yahoo Finance│   │  Discord Webhook              │  │
│  └───────────────┘   └──────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐ │
│  │  SQLite: stocks · watchlist · signals · alerts     │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## Quick Start

### 1 · Backend

```bash
cd backend

# Create & activate virtual env
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env → add your DISCORD_WEBHOOK_URL

# Run
uvicorn main:app --reload --port 8000
```

API docs → http://localhost:8000/docs

---

### 2 · Frontend

```bash
cd frontend

# Install Flutter Web (if not already)
flutter config --enable-web

# Get packages
flutter pub get

# Run in Chrome
flutter run -d chrome --web-port 5000
```

> **CORS:** The backend allows all origins by default.  
> For production set `CORS_ORIGINS` in `config.py`.

---

## Signal Logic

| Indicator | BUY condition | SELL condition | HOLD |
|---|---|---|---|
| MA Crossover (SMA20/50) | SMA20 > SMA50 | SMA20 < SMA50 | — |
| RSI (14) | RSI < 30 | RSI > 70 | 30–70 |
| MACD (12,26,9) | MACD crosses above signal | MACD crosses below signal | — |
| Bollinger Bands (20, 2σ) | Price ≤ Lower Band | Price ≥ Upper Band | Inside bands |
| Momentum ROC (10d) | ROC > +2 % | ROC < −2 % | ±2 % |

**Overall Signal** = majority vote (≥3 out of 5).  
**Confidence** = proportion of votes for the winning signal × 100.

---

## REST API Reference

| Method | Endpoint | Description |
|---|---|---|
| GET | `/watchlist` | List watchlist items |
| POST | `/watchlist` | Add ticker |
| DELETE | `/watchlist/{ticker}` | Remove ticker |
| POST | `/signals/refresh` | Trigger immediate refresh (background) |
| GET | `/signals/latest` | Latest signal for all watchlist tickers |
| GET | `/signals/{ticker}` | Signal history for a ticker |
| GET | `/signals/{ticker}/latest` | Latest signal for one ticker |
| GET | `/price/{ticker}?period=3mo` | OHLCV price data |
| GET | `/alerts?limit=50` | Recent alerts |
| GET | `/portfolio/summary` | Portfolio overview counts |
| GET | `/health` | Health check |

---

## Discord Alert Format

```
🟢  AAPL — BUY Signal
MA `BUY` · BB `BUY` · Momentum `BUY`

💰 Price     $182.50
📊 Confidence  80%
📈 RSI (14)   28.4
MACD          0.0123
```

---

## Project Structure

```
trading_dss/
├── backend/
│   ├── main.py            ← FastAPI app + all routes
│   ├── database.py        ← SQLAlchemy models + session
│   ├── schemas.py         ← Pydantic request/response models
│   ├── signal_engine.py   ← MA, RSI, MACD, BB, Momentum logic
│   ├── data_fetcher.py    ← yfinance wrapper
│   ├── discord_alert.py   ← Discord webhook sender
│   ├── scheduler.py       ← APScheduler background job
│   ├── config.py          ← Environment config
│   ├── requirements.txt
│   └── .env.example
└── frontend/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── config/app_config.dart      ← API URL, colours, helpers
        ├── models/models.dart          ← SignalData, WatchlistEntry, …
        ├── services/api_service.dart   ← HTTP client
        ├── screens/
        │   ├── dashboard_screen.dart   ← Main view
        │   └── stock_detail_screen.dart← Detail + chart
        └── widgets/
            ├── signal_badge.dart
            ├── stock_card.dart
            └── alert_list.dart
```

---

## Configuration

| Variable | Default | Description |
|---|---|---|
| `DISCORD_WEBHOOK_URL` | _(empty)_ | Discord webhook – leave blank to disable |
| `SIGNAL_REFRESH_INTERVAL` | `30` | Auto-refresh interval in minutes |

---

## Extending

- **Add a new indicator:** implement it in `signal_engine.py`, add a column to `Signal` in `database.py`, expose it in `schemas.py`.
- **Change data source:** replace `data_fetcher.py` (keep the same function signatures).
- **Add authentication:** add FastAPI `Depends` with OAuth2/JWT.
