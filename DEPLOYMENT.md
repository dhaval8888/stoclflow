# StockFlow Deployment & Operations Guide

> **Deployment Status**: **DEPLOYMENT-READY**. Production configurations (`render.yaml`, `docker-compose.yml`, Dockerfile) and release builds have been tested and verified. The project is not currently hosted at an active public cloud URL to avoid ongoing hosting charges.

This guide covers deployment strategies for StockFlow:
1. Managed PostgreSQL Database (Neon Serverless Postgres / Supabase)
2. Backend Deployment (Render Web Service / Railway)
3. Local Containerized Stack (Docker Compose)
4. Mobile Client Production Build (Flutter Release APK & Android App Bundle)

---

## 1. Managed PostgreSQL Setup (Neon)

[Neon](https://neon.tech) offers serverless PostgreSQL with connection pooling and SSL encryption.

### Step-by-step Provisioning:
1. Log in to [Neon Console](https://console.neon.tech).
2. Click **Create Project**, name it `stockflow-db`, and select your preferred region.
3. Once provisioned, locate the **Connection Details** pane on the Dashboard.
4. Select **Pooled connection** string (recommended for serverless/PaaS backends) or direct connection string:
   ```bash
   postgres://[user]:[password]@[ep-xyz].neon.tech/neondb?sslmode=require
   ```
5. Note: StockFlow automatically enforces SSL in production via `src/config/db.js` (`ssl: { rejectUnauthorized: false }`).

---

## 2. Cloud Backend Deployment

### Option A: Render (Recommended)

#### Using the Blueprint (`render.yaml`)
1. Fork or push the repository to GitHub.
2. In the [Render Dashboard](https://dashboard.render.com), click **New +** > **Blueprint**.
3. Connect your repository. Render will automatically detect `render.yaml`.
4. Fill in the required environment variables:
   - `DATABASE_URL`: Paste your Neon connection string (`postgres://...`).
5. Render will automatically:
   - Install dependencies (`npm install`)
   - Execute database migrations (`npm run migrate`)
   - Start the server (`npm start`)
   - Monitor the health check at `/api/health`

#### Manual Service Configuration (Without Blueprint)
- **Environment**: Node.js
- **Root Directory**: `stockflow-api`
- **Build Command**: `npm install`
- **Start Command**: `npm run migrate && npm start`
- **Health Check Path**: `/api/health`
- **Environment Variables**:
  | Key | Example Value | Description |
  |---|---|---|
  | `NODE_ENV` | `production` | Enables helmet, sanitized errors, SSL |
  | `PORT` | `10000` | Render default port |
  | `DATABASE_URL` | `postgres://...` | Managed PostgreSQL connection string |
  | `JWT_ACCESS_SECRET` | `64-char-random-hex` | Secret for access tokens |
  | `JWT_REFRESH_SECRET`| `64-char-random-hex` | Secret for refresh tokens |
  | `JWT_ACCESS_EXPIRES_IN` | `15m` | Token lifespan |
  | `JWT_REFRESH_EXPIRES_IN`| `7d` | Refresh lifespan |
  | `CORS_ORIGIN` | `*` or your web domain | Allowed CORS origins |

#### Running Database Seeds on Render:
To populate demo users, roles, categories, and initial products:
1. In Render Dashboard, navigate to `stockflow-api` service.
2. Click the **Shell** tab.
3. Run:
   ```bash
   npm run seed
   ```

---

### Option B: Railway

1. Install Railway CLI or link GitHub repository in [Railway Dashboard](https://railway.app).
2. Add a new service from the GitHub repository with root directory set to `stockflow-api`.
3. In service **Settings** > **Deploy**, configure:
   - Build Command: `npm install`
   - Start Command: `npm run migrate && npm start`
4. In **Variables**, add:
   - `DATABASE_URL`
   - `JWT_ACCESS_SECRET`
   - `JWT_REFRESH_SECRET`
   - `NODE_ENV=production`
   - `PORT=3000`

---

## 3. Local Docker Compose Stack

For reproducible local development or self-hosted staging:

```bash
# Clone the repository
git clone https://github.com/your-repo/stockflow.git
cd stockflow

# Start PostgreSQL and StockFlow API in containers
docker compose up -d

# Check service logs
docker compose logs -f api

# Execute database migrations inside the running API container
docker compose exec api npm run migrate

# Seed initial demonstration data
docker compose exec api npm run seed

# Verify API health
curl http://localhost:3000/api/health
```

To tear down the containers:
```bash
docker compose down
# Or to wipe database volumes:
docker compose down -v
```

---

## 4. Flutter Production Configuration & Builds

### Development Build
Run locally against your local development backend or Android emulator (10.0.2.2):
```bash
cd stockflow_app

# Default uses 10.0.2.2:3000 on Android emulator
flutter run

# Or explicitly define local IP for physical devices:
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:3000/api
```

### Production Release Builds

#### 1. APK (Direct installation / Sideloading):
Compile with your production cloud API URL passed at build time:
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://stockflow-api.onrender.com/api
```
The output file is located at:
```
stockflow_app/build/app/outputs/flutter-apk/app-release.apk
```

#### 2. Android App Bundle (AAB for Google Play Console):
To publish to the Google Play Store:
```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://stockflow-api.onrender.com/api
```
The output file is located at:
```
stockflow_app/build/app/outputs/bundle/release/app-release.aab
```

#### Configuration Priority:
The Flutter application resolves the API endpoint in the following order of precedence:
1. Compile-time environment variable: `--dart-define=API_BASE_URL=https://...`
2. Runtime `.env` file variable: `API_BASE_URL` (loaded via `flutter_dotenv`)
3. Platform default: `http://10.0.2.2:3000/api` (Android emulator) or `http://localhost:3000/api` (Web/Desktop/iOS simulator)

---

## 5. Security & Maintenance Checklist

- [ ] **Secrets**: Never commit `.env` or `.env.*` files. Use `.env.example` templates.
- [ ] **CORS**: In production, restrict `CORS_ORIGIN` to your known frontend domains if hosting Flutter Web.
- [ ] **Health Monitoring**: Set up uptime pings (e.g. UptimeRobot, BetterStack) targeting `/api/health`.
- [ ] **Database Backups**: Enable automated daily backups on Neon or your managed PostgreSQL provider.
- [ ] **Log Sanitization**: Ensure error handler masks stack traces and database schema errors in production mode (`NODE_ENV=production`).
