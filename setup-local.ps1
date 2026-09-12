# StockFlow — Local Development Setup Script for Windows
# ─────────────────────────────────────────────────────────────────────────────
# Run this from the project root:
#   powershell -ExecutionPolicy Bypass -File setup-local.ps1
# ─────────────────────────────────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   StockFlow — Local Development Setup" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ─── Step 1: Check Node.js ────────────────────────────────────────────────────
Write-Host "1. Checking Node.js..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version
    Write-Host "   ✅  Node.js $nodeVersion found" -ForegroundColor Green
} catch {
    Write-Host "   ❌  Node.js not found. Install from https://nodejs.org (version 18+)" -ForegroundColor Red
    exit 1
}

# ─── Step 2: Check PostgreSQL ────────────────────────────────────────────────
Write-Host ""
Write-Host "2. Checking PostgreSQL..." -ForegroundColor Yellow

$pgPaths = @(
    "C:\Program Files\PostgreSQL\17\bin",
    "C:\Program Files\PostgreSQL\16\bin",
    "C:\Program Files\PostgreSQL\15\bin",
    "C:\Program Files\PostgreSQL\14\bin"
)

$pgBin = $null
foreach ($p in $pgPaths) {
    if (Test-Path "$p\psql.exe") {
        $pgBin = $p
        break
    }
}

if ($pgBin) {
    $env:PATH = "$pgBin;$env:PATH"
    $pgVersion = & "$pgBin\psql.exe" --version
    Write-Host "   ✅  $pgVersion found at $pgBin" -ForegroundColor Green
} else {
    Write-Host "   ⚠️   PostgreSQL not found in standard locations." -ForegroundColor Yellow
    Write-Host "       Install from: https://www.postgresql.org/download/windows/" -ForegroundColor Yellow
    Write-Host "       Or use Chocolatey:  choco install postgresql --params '/Password:postgres'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   After installing, re-run this script." -ForegroundColor White
    exit 1
}

# ─── Step 3: Create .env if it doesn't exist ─────────────────────────────────
Write-Host ""
Write-Host "3. Checking .env configuration..." -ForegroundColor Yellow

$envFile = "stockflow-api\.env"
$envExample = "stockflow-api\.env.example"

if (-not (Test-Path $envFile)) {
    Write-Host "   Creating .env from .env.example..." -ForegroundColor White
    Copy-Item $envExample $envFile

    # Generate JWT secrets automatically
    $accessSecret = node -e "process.stdout.write(require('crypto').randomBytes(48).toString('hex'))"
    $refreshSecret = node -e "process.stdout.write(require('crypto').randomBytes(48).toString('hex'))"

    # Replace placeholder values
    $envContent = Get-Content $envFile -Raw
    $envContent = $envContent -replace "replace_with_a_random_64_char_hex_string_for_access_tokens", $accessSecret
    $envContent = $envContent -replace "replace_with_a_different_random_64_char_hex_string_for_refresh", $refreshSecret
    Set-Content $envFile $envContent -NoNewline

    Write-Host "   ✅  .env created with auto-generated JWT secrets" -ForegroundColor Green
    Write-Host ""
    Write-Host "   ⚠️   You still need to set DATABASE_URL in stockflow-api\.env" -ForegroundColor Yellow
    Write-Host "       Edit the file and set your PostgreSQL password." -ForegroundColor Yellow
} else {
    Write-Host "   ✅  .env already exists" -ForegroundColor Green
}

# ─── Step 4: Read DATABASE_URL from .env ────────────────────────────────────
Write-Host ""
Write-Host "4. Reading database configuration..." -ForegroundColor Yellow

$dbUrl = Select-String -Path $envFile -Pattern "^DATABASE_URL=(.+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }

if (-not $dbUrl -or $dbUrl -match "your_password") {
    Write-Host ""
    Write-Host "   ❌  DATABASE_URL is not configured in $envFile" -ForegroundColor Red
    Write-Host "       Open the file and replace 'your_password' with your PostgreSQL password." -ForegroundColor Yellow
    Write-Host "       Example: DATABASE_URL=postgresql://postgres:postgres@localhost:5432/stockflow_db" -ForegroundColor White
    exit 1
}

Write-Host "   ✅  DATABASE_URL configured" -ForegroundColor Green

# ─── Step 5: Create database if needed ───────────────────────────────────────
Write-Host ""
Write-Host "5. Creating database 'stockflow_db' if it doesn't exist..." -ForegroundColor Yellow

try {
    $createResult = & "$pgBin\psql.exe" -U postgres -c "SELECT 1 FROM pg_database WHERE datname = 'stockflow_db'" --tuples-only --no-align 2>&1
    if ($createResult -notmatch "1") {
        & "$pgBin\psql.exe" -U postgres -c "CREATE DATABASE stockflow_db;" 2>&1
        Write-Host "   ✅  Database 'stockflow_db' created" -ForegroundColor Green
    } else {
        Write-Host "   ✅  Database 'stockflow_db' already exists" -ForegroundColor Green
    }
} catch {
    Write-Host "   ⚠️   Could not auto-create database. You may need to create it manually:" -ForegroundColor Yellow
    Write-Host "       psql -U postgres -c ""CREATE DATABASE stockflow_db;""" -ForegroundColor White
}

# ─── Step 6: Install backend dependencies ────────────────────────────────────
Write-Host ""
Write-Host "6. Installing backend dependencies..." -ForegroundColor Yellow
Push-Location "stockflow-api"
npm install --silent
Write-Host "   ✅  npm install complete" -ForegroundColor Green

# ─── Step 7: Run migrations ───────────────────────────────────────────────────
Write-Host ""
Write-Host "7. Running database migrations..." -ForegroundColor Yellow
node src/db/migrate.js
Write-Host "   ✅  Migrations complete" -ForegroundColor Green

# ─── Step 8: Seed demo data ───────────────────────────────────────────────────
Write-Host ""
Write-Host "8. Seeding demo data..." -ForegroundColor Yellow
node src/db/seed.js
Write-Host "   ✅  Seed complete" -ForegroundColor Green
Pop-Location

# ─── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "   ✅  Setup complete!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Start the backend:" -ForegroundColor White
Write-Host "   cd stockflow-api" -ForegroundColor Cyan
Write-Host "   npm run dev" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run the Flutter app (in a new terminal):" -ForegroundColor White
Write-Host "   cd stockflow_app" -ForegroundColor Cyan
Write-Host "   flutter run" -ForegroundColor Cyan
Write-Host ""
Write-Host "Demo credentials:" -ForegroundColor White
Write-Host "   Owner   → owner@demo.com   / Owner@123" -ForegroundColor Cyan
Write-Host "   Manager → manager@demo.com / Manager@123" -ForegroundColor Cyan
Write-Host "   Cashier → cashier@demo.com / Cashier@123" -ForegroundColor Cyan
Write-Host ""
