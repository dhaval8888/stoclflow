# StockFlow — Local Development Setup

This guide covers running StockFlow without Docker.
The normal daily workflow is: **PostgreSQL (local) → Node.js backend → Flutter app**.

---

## Prerequisites

| Requirement | Minimum | Download |
|---|---|---|
| Node.js | 18+ | https://nodejs.org |
| PostgreSQL | 14+ | https://www.postgresql.org/download/windows/ |
| Flutter | 3.19+ | https://docs.flutter.dev/get-started/install |

---

## One-time Setup

### Step 1 — Install PostgreSQL (if not installed)

**Option A — PostgreSQL Installer (recommended)**
1. Download from https://www.postgresql.org/download/windows/
2. Run the installer. Default port `5432` is fine.
3. Set a password for the `postgres` superuser — you will need it below.
4. Add PostgreSQL `bin` to your PATH during installation, or add it manually:
   - Example path: `C:\Program Files\PostgreSQL\17\bin`

**Option B — Chocolatey**
```powershell
choco install postgresql --params '/Password:postgres'
```

Verify the installation:
```powershell
psql --version
# Expected: psql (PostgreSQL) 17.x
```

---

### Step 2 — Create the database

```powershell
psql -U postgres -c "CREATE DATABASE stockflow_db;"
```

If prompted, enter the `postgres` password you set during installation.

---

### Step 3 — Configure the backend environment

```powershell
cd stockflow-api
Copy-Item .env.example .env
```

Open `stockflow-api\.env` and set the following values:

```env
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@localhost:5432/stockflow_db
```

Replace `YOUR_PASSWORD` with your PostgreSQL `postgres` user password.

Generate the required JWT secrets (run once, copy the output):
```powershell
node -e "const c=require('crypto'); console.log('JWT_ACCESS_SECRET=' + c.randomBytes(48).toString('hex')); console.log('JWT_REFRESH_SECRET=' + c.randomBytes(48).toString('hex'));"
```

Paste the two generated lines into your `.env` file, replacing the placeholder values.

Your completed `.env` should look like:
```env
NODE_ENV=development
PORT=3000
CORS_ORIGIN=*

DATABASE_URL=postgresql://postgres:postgres@localhost:5432/stockflow_db

JWT_ACCESS_SECRET=a1b2c3d4...  (your 96-char hex string)
JWT_REFRESH_SECRET=e5f6g7h8...  (a different 96-char hex string)
JWT_ACCESS_EXPIRES=15m
JWT_REFRESH_EXPIRES=7d
```

Optional (image uploads and push notifications — not required in development):
```env
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=
```

---

### Step 4 — Run migrations and seed data

```powershell
cd stockflow-api
npm install
npm run migrate
npm run seed
```

Expected output from `npm run migrate`:
```
🔄  Running migrations...
  ✅  Applied   001_create_roles.sql
  ✅  Applied   002_create_businesses.sql
  ...
  ✨  Applied N migration(s).
```

Expected output from `npm run seed`:
```
🌱  Seeding database...
  ✅  Roles seeded
  ✅  Business seeded
  ✅  Users seeded
  ...
  ✨  Seed complete.
```

---

## Daily Development Workflow

### Terminal 1 — Backend

```powershell
cd stockflow-api
npm run dev
```

Backend runs at `http://localhost:3000`  
Swagger UI: `http://localhost:3000/api-docs`  
Health check: `http://localhost:3000/health`

### Terminal 2 — Flutter App

```powershell
cd stockflow_app
flutter pub get
flutter run
```

The Flutter app reads the API URL from `stockflow_app\.env`:
```env
API_BASE_URL=http://10.0.2.2:3000/api/v1   # Android Emulator
# API_BASE_URL=http://localhost:3000/api/v1  # Windows/Desktop
```

**Android Emulator** uses `10.0.2.2` (the host machine's localhost).  
**Physical device** on the same WiFi network: use your machine's local IP (e.g., `192.168.x.x:3000`).

---

## Demo Credentials

| Role | Email | Password |
|---|---|---|
| **Owner** | `owner@demo.com` | `Owner@123` |
| **Manager** | `manager@demo.com` | `Manager@123` |
| **Cashier** | `cashier@demo.com` | `Cashier@123` |

---

## Automated Setup (Windows PowerShell)

The `setup-local.ps1` script in the project root automates steps 2–4 above:

```powershell
powershell -ExecutionPolicy Bypass -File setup-local.ps1
```

This script:
- Detects your local PostgreSQL installation
- Creates the `stockflow_db` database
- Creates `stockflow-api/.env` from the example with auto-generated JWT secrets
- Runs `npm install`, `npm run migrate`, and `npm run seed`

> **Note:** You still need to manually set your PostgreSQL password in `.env` before running the script if the auto-created file uses a placeholder.

---

## Running Tests (no database required)

```powershell
cd stockflow-api

# Unit tests — standalone, no database needed
npm run test:unit

# Integration tests — uses PGlite (in-process PostgreSQL, no external DB)
npm run test:integration

# E2E tests — uses PGlite for a fresh DB workflow
npm run test:e2e
```

---

## Docker (Optional)

Docker is available as an **optional** deployment and demo mechanism — not required for development.

```powershell
# Start everything with Docker (backend + PostgreSQL)
docker compose up -d

# Or just PostgreSQL via Docker, backend runs natively
docker compose up -d db
cd stockflow-api
npm run dev
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for full Docker, Render, and Railway deployment instructions.

---

## Troubleshooting

### `psql` not found
PostgreSQL `bin` directory is not on PATH.  
Add `C:\Program Files\PostgreSQL\17\bin` to your system PATH, then restart the terminal.

### Connection refused (`ECONNREFUSED 127.0.0.1:5432`)
PostgreSQL is not running. Start it:
```powershell
# Windows Services
net start postgresql-x64-17
# Or via PostgreSQL pgAdmin
```

### `Missing required environment variables`
Your `stockflow-api/.env` is missing `JWT_ACCESS_SECRET` or `JWT_REFRESH_SECRET`.  
Run the key generation command in Step 3 and add the values to your `.env`.

### `password authentication failed for user "postgres"`
The password in `DATABASE_URL` does not match what you set during PostgreSQL installation.  
Update the password in `stockflow-api/.env`.

### Flutter connects but gets 401 errors
The backend is running but you're not logged in.  
Use the demo credentials above in the Flutter app login screen.

### Android Emulator cannot connect to backend
Change the API base URL from `localhost` to `10.0.2.2` in `stockflow_app/.env`:
```env
API_BASE_URL=http://10.0.2.2:3000/api/v1
```
