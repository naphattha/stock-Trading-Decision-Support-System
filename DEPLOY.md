# 🚀 Deployment Guide — Free Stack

## Architecture
```
Vercel (Flutter Web) → Render (FastAPI) → Supabase (PostgreSQL)
                                        → Upstash (Redis)
GitHub Actions → Discord alerts (cron, no server needed)
UptimeRobot    → Keeps Render awake (free)
```

---

## Step 1 — Supabase (PostgreSQL)

1. Sign up at https://supabase.com
2. New Project → choose region closest to you
3. Settings → Database → Connection String → **Transaction pooler** URI
4. Copy the URI — looks like:
   ```
   postgresql://postgres.[ref]:[password]@aws-0-[region].pooler.supabase.com:6543/postgres
   ```
5. Save as `DATABASE_URL`

> Tables are created automatically when FastAPI starts for the first time.

---

## Step 2 — Upstash (Redis)

1. Sign up at https://upstash.com
2. Create Database → choose region close to Render
3. Details tab → copy **Redis URL** (starts with `rediss://`)
4. Save as `REDIS_URL`

---

## Step 3 — Render (FastAPI Backend)

1. Sign up at https://render.com → connect GitHub
2. New → Web Service → your repo
3. Settings:
   - **Root Directory:** `backend`
   - **Runtime:** Docker
   - **Dockerfile path:** `./Dockerfile`
4. Environment Variables — add all three:
   ```
   DATABASE_URL        = (from Supabase)
   REDIS_URL           = (from Upstash)
   DISCORD_WEBHOOK_URL = (from Discord)
   DISABLE_SCHEDULER   = true
   ```
5. Deploy → wait ~3 min → copy your URL:
   ```
   https://trading-dss-api.onrender.com
   ```

---

## Step 4 — GitHub Secrets

Go to: GitHub repo → Settings → Secrets and variables → Actions

Add these secrets:

| Secret name          | Value                                         |
|----------------------|-----------------------------------------------|
| `DATABASE_URL`       | postgresql://... (Supabase)                  |
| `DISCORD_WEBHOOK_URL`| https://discord.com/api/webhooks/...         |
| `RENDER_API_URL`     | https://trading-dss-api.onrender.com         |
| `RENDER_WS_URL`      | wss://trading-dss-api.onrender.com/ws/signals|
| `VERCEL_TOKEN`       | from vercel.com/account/tokens               |
| `VERCEL_ORG_ID`      | from vercel project settings                 |
| `VERCEL_PROJECT_ID`  | from vercel project settings                 |

---

## Step 5 — Vercel (Flutter Web)

### Option A: Manual (first deploy)
```bash
# Install Vercel CLI
npm i -g vercel

# Build Flutter
cd frontend
flutter build web --release \
  --dart-define=API_URL=https://trading-dss-api.onrender.com \
  --dart-define=WS_URL=wss://trading-dss-api.onrender.com/ws/signals

# Deploy
cd build/web
vercel --prod
```

### Option B: Auto via GitHub Actions
After Step 4, every push to `main` that changes `frontend/` auto-deploys.

---

## Step 6 — UptimeRobot (Prevent Render sleep)

Render free tier sleeps after 15 min. Fix it:

1. Sign up at https://uptimerobot.com (free)
2. Add New Monitor:
   - Type: HTTP(s)
   - URL: `https://trading-dss-api.onrender.com/health`
   - Interval: **5 minutes**
3. Done — Render won't sleep anymore

---

## Step 7 — Test Everything

```bash
# 1. Test backend health
curl https://trading-dss-api.onrender.com/health

# 2. Run GitHub Actions manually
# GitHub → Actions → Signal Alert → Run workflow

# 3. Check Discord for test alert

# 4. Open Flutter Web on phone
# https://your-project.vercel.app
```

---

## Local Development (unchanged)

```bash
# Start local services
docker-compose up -d   # PostgreSQL + Redis

# Backend
cd backend
cp .env.example .env   # set DISABLE_SCHEDULER=false for local
uvicorn main:app --reload --port 8000

# Frontend (points to localhost by default)
cd frontend
flutter run -d chrome --web-port 5000
```

---

## Summary: What each service does

| Service       | Purpose                        | Cost    |
|---------------|-------------------------------|---------|
| Vercel        | Hosts Flutter Web (static)     | Free    |
| Render        | Runs FastAPI 24/7              | Free*   |
| Supabase      | PostgreSQL database            | Free*   |
| Upstash       | Redis cache                    | Free*   |
| GitHub Actions| Discord alert cron every 30min | Free*   |
| UptimeRobot   | Keeps Render awake             | Free    |

*Free tier limits apply — sufficient for personal single-user use.
