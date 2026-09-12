# StockFlow — Smart Inventory & POS Management System

StockFlow is a production-grade, full-stack inventory management and Point-of-Sale (POS) solution engineered for retail stores, warehouses, and small-to-medium businesses. It bridges a modern Material 3 mobile application with a transactional Node.js / PostgreSQL backend to guarantee zero stock drift, prevent concurrent overselling, and provide real-time business visibility.

---

## 1. Problem Statement

Retail businesses frequently struggle with:
- **Inventory Inconsistencies & Overselling**: Concurrent sales at different registers or physical counters selling the same remaining unit before records update.
- **Disconnected Systems**: Siloed POS checkouts, manual stock-taking ledgers, and fragmented analytics.
- **Security & Authorization Risks**: Mobile clients storing sensitive database keys or lack of role-based data partitioning between owners and floor cashiers.

StockFlow solves these challenges by treating the PostgreSQL database as the single authoritative source of truth, enforcing row-level locks on stock rows during checkout, and providing role-based user experiences across Flutter and Express.

---

## 2. System Architecture

```mermaid
graph TD
    subgraph Client["Flutter Mobile Client (Material 3)"]
        UI["Presentation Layer (Screens & Widgets)"]
        Ctrl["Application Layer (Riverpod Controllers)"]
        Data["Data Layer (Dio + TokenStorage)"]
        UI --> Ctrl
        Ctrl --> Data
    end

    subgraph Backend["Node.js / Express Monolith"]
        MW["Middleware (Helmet, CORS, RateLimit, Auth, RBAC)"]
        Routes["REST API Routes (/api/...)"]
        Services["Domain Services (Sales, Inventory, Auth)"]
        Repo["Data Access Layer"]
        MW --> Routes --> Services --> Repo
    end

    subgraph Storage["Persistence & External Services"]
        PG[("PostgreSQL 16 (Row-Level Locking)")]
        Cloudinary[("Cloudinary (Image CDN)")]
    end

    Data -->|"HTTPS / JWT Bearer"| MW
    Repo -->|"pg pool (SELECT ... FOR UPDATE)"| PG
    Services -->|"Multipart Upload"| Cloudinary
```

---

## 3. Entity-Relationship Diagram (ERD)

```mermaid
erDiagram
    ROLES ||--o{ USERS : "has"
    BUSINESSES ||--o{ USERS : "employs"
    BUSINESSES ||--o{ CATEGORIES : "organizes"
    BUSINESSES ||--o{ PRODUCTS : "owns"
    CATEGORIES ||--o{ PRODUCTS : "categorizes"
    PRODUCTS ||--o{ PRODUCT_IMAGES : "has"
    PRODUCTS ||--o{ INVENTORY_TRANSACTIONS : "tracks"
    BUSINESSES ||--o{ SALES : "records"
    USERS ||--o{ SALES : "processes"
    SALES ||--o{ SALE_ITEMS : "contains"
    PRODUCTS ||--o{ SALE_ITEMS : "sold_in"
    USERS ||--o{ REFRESH_TOKENS : "owns"

    ROLES {
        int id PK
        string name
    }

    BUSINESSES {
        uuid id PK
        string name
        string currency
        string timezone
    }

    USERS {
        uuid id PK
        uuid business_id FK
        int role_id FK
        string full_name
        string email UK
        string password_hash
        boolean is_active
    }

    CATEGORIES {
        uuid id PK
        uuid business_id FK
        string name
        string slug
    }

    PRODUCTS {
        uuid id PK
        uuid business_id FK
        uuid category_id FK
        string name
        string sku UK
        string barcode UK
        numeric cost_price
        numeric unit_price
        int current_stock
        int low_stock_threshold
        boolean is_active
    }

    PRODUCT_IMAGES {
        uuid id PK
        uuid product_id FK
        string image_url
        boolean is_primary
    }

    INVENTORY_TRANSACTIONS {
        uuid id PK
        uuid product_id FK
        uuid user_id FK
        string transaction_type
        int quantity_change
        int balance_after
        string reason
        timestamptz created_at
    }

    SALES {
        uuid id PK
        uuid business_id FK
        uuid cashier_id FK
        numeric subtotal
        numeric discount_amount
        numeric tax_amount
        numeric total_amount
        string payment_method
        string status
        timestamptz created_at
    }

    SALE_ITEMS {
        uuid id PK
        uuid sale_id FK
        uuid product_id FK
        int quantity
        numeric unit_price
        numeric total_price
    }

    REFRESH_TOKENS {
        uuid id PK
        uuid user_id FK
        string token_hash
        timestamptz expires_at
        boolean is_revoked
    }
```

---

## 4. Implemented Features

### Mobile Application (Flutter)
- **Role-Based Experience**:
  - **Owner / Manager**: Full executive dashboard, revenue KPIs, product cost & profit margins, business analytics, and staff administration.
  - **Cashier**: Streamlined operational interface focused on point-of-sale checkout, catalogue browsing, and receipt history without financial profit leakage.
- **Product & Category Catalogue**:
  - Live search with 400ms debouncing and race condition protection (`_currentRequestId`).
  - Category filtering and deduplicating infinite scroll pagination.
  - Product creation/editing with image upload support via Cloudinary.
- **Point of Sale (POS) & Barcode Scanning**:
  - Interactive camera barcode scanner using `mobile_scanner`.
  - Dynamic cart with item quantity clamping against current available stock.
  - Line-item and order-level discount calculations with tax adjustments.
  - Payment method selection (Cash, Card, UPI) and digital receipt generation.
  - Manager-authorized void sale workflow reversing inventory movements.
- **Inventory Ledger**:
  - Real-time stock movements (`STOCK_IN`, `STOCK_OUT`, `ADJUSTMENT`) with reason tracking and stock level status badges.
- **Business Analytics**:
  - Daily, weekly, and monthly sales trend charts.
  - Top-selling and slow-moving product rankings.
  - Estimated gross profit and cost analysis for managers/owners.
- **Employee Management**:
  - List staff, invite/create team members, reassign roles, and activate/deactivate accounts.

### Backend API (Node.js / Express / PostgreSQL)
- **Concurrency & Transaction Safety**:
  - Pessimistic row locking (`SELECT ... FOR UPDATE`) during checkout guaranteeing zero overselling.
  - Atomic database transactions (`BEGIN` ... `COMMIT` / `ROLLBACK`) for sales and ledger movements.
- **Security & Hardening**:
  - `Helmet` security headers and environment-aware CORS.
  - Tiered rate limiters: sensitive auth routes (5 req/15 min) vs general API routes.
  - Token-based authentication: short-lived JWT access tokens (15 min) with refresh token rotation (7 days).
  - Sanitized production error handler concealing database schemas and stack traces.

---

## 5. Technology Stack

| Component | Technology | Description |
|---|---|---|
| **Mobile Client** | Flutter 3.x / Dart 3.x | Cross-platform mobile framework |
| **Design System** | Material 3 | Modern adaptive styling with dark/light themes |
| **State Management**| Riverpod 2.x | Reactive dependency injection and state management |
| **Routing** | GoRouter | Declarative routing with auth redirect guards |
| **Networking** | Dio | HTTP client with queued token refresh interceptor |
| **Secure Storage** | `flutter_secure_storage`| OS Keychain / Keystore encrypted token storage |
| **Backend Engine** | Node.js 20 / Express 4 | Monolithic REST service |
| **Database** | PostgreSQL 16 | Relational database with row-level locking |
| **Schema Validation**| Zod | Runtime payload validation |
| **Media Hosting** | Cloudinary | Image upload and CDN delivery |
| **Containerization**| Docker & Docker Compose | Optional: containerized deployment and cloud hosting |

---

## 6. Quick Start & Setup

### Prerequisites
- Node.js 18+ and npm
- PostgreSQL 14+ installed locally (or Docker as an optional alternative)
- Flutter 3.19+ and Android Studio / Xcode

For full step-by-step instructions including PostgreSQL installation and troubleshooting, see [LOCAL_SETUP.md](LOCAL_SETUP.md).

### Option A: Local Setup (Recommended for Development)

```bash
# 1. Configure environment
cd stockflow-api
copy .env.example .env
# Edit .env — set DATABASE_URL and generate JWT secrets (see LOCAL_SETUP.md)

# 2. Install and run
npm install
npm run migrate
npm run seed
npm run dev
# Backend available at http://localhost:3000
```

```bash
# 3. Run Flutter app (new terminal)
cd stockflow_app
flutter pub get
flutter run
```

#### Demo Credentials:
| Role | Email | Password |
|---|---|---|
| **Owner** | `owner@demo.com` | `Owner@123` |
| **Manager** | `manager@demo.com` | `Manager@123` |
| **Cashier** | `cashier@demo.com` | `Cashier@123` |

> **Note for Android Emulator:** The Flutter app's `.env` must use `http://10.0.2.2:3000/api/v1` (not `localhost`) to reach the host machine.

### Option B: Docker Compose (Optional)

```bash
# Launch PostgreSQL + Node.js backend via Docker
docker compose up -d
docker compose exec api npm run migrate
docker compose exec api npm run seed
# Backend available at http://localhost:3000
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for full Docker, Render, and Railway deployment instructions.

---

## 7. Environment Variables

### Backend (`stockflow-api/.env`)
| Variable | Required | Default / Example | Purpose |
|---|---|---|---|
| `PORT` | No | `3000` | Server listening port |
| `NODE_ENV` | No | `development` | `development` or `production` |
| `DATABASE_URL` | **Yes** | `postgres://user:pass@localhost:5432/db` | PostgreSQL connection URI |
| `JWT_ACCESS_SECRET` | **Yes** | `96-char hex string` | Key for signing access tokens — generate with `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"` |
| `JWT_REFRESH_SECRET`| **Yes** | `96-char hex string` | Key for signing refresh tokens — must be **different** from access secret |
| `JWT_ACCESS_EXPIRES` | No | `15m` | Access token lifespan |
| `JWT_REFRESH_EXPIRES`| No | `7d` | Refresh token lifespan |
| `CORS_ORIGIN` | No | `*` | Allowed origin for CORS headers |
| `CLOUDINARY_CLOUD_NAME` | No | `your-cloud` | Cloudinary storage identifier |
| `CLOUDINARY_API_KEY` | No | `your-key` | Cloudinary access key |
| `CLOUDINARY_API_SECRET`| No | `your-secret` | Cloudinary secret |

### Flutter Client (`stockflow_app`)
- Injected at build time via `--dart-define=API_BASE_URL=https://api.yourdomain.com/api`
- Or loaded via `.env` file (`API_BASE_URL=http://10.0.2.2:3000/api` for Android Emulator).

---

## 8. API Overview

Interactive Swagger UI documentation is available at `/api-docs` when the backend is running.

| Method | Endpoint | Access | Description |
|---|---|---|---|
| `GET` | `/health` / `/api/health` | Public | System health check & database connectivity probe |
| `GET` | `/api-docs` | Public | Interactive Swagger UI API documentation |
| `POST` | `/api/v1/auth/login` | Public | Authenticate user & receive JWT tokens |
| `POST` | `/api/v1/auth/refresh` | Public | Exchange refresh token for new access token |
| `POST` | `/api/v1/auth/logout` | Authenticated | Revoke refresh token |
| `GET` | `/api/v1/auth/me` | Authenticated | Fetch current profile and role |
| `GET` | `/api/v1/products` | Cashier+ | List products (with pagination, search, category) |
| `GET` | `/api/v1/products/:id` | Cashier+ | Retrieve product detail by ID or barcode |
| `POST` | `/api/v1/products` | Manager+ | Create a new product |
| `PUT` | `/api/v1/products/:id` | Manager+ | Update product details |
| `DELETE`| `/api/v1/products/:id` | Manager+ | Soft delete / deactivate product |
| `GET` | `/api/v1/categories` | Cashier+ | List business categories |
| `POST` | `/api/v1/categories` | Manager+ | Create category |
| `GET` | `/api/v1/inventory` | Manager+ | List stock levels & low stock alerts |
| `POST` | `/api/v1/inventory/transaction` | Manager+ | Record stock-in, stock-out, or adjustment |
| `POST` | `/api/v1/sales` | Cashier+ | Atomic checkout with pessimistic row locking |
| `GET` | `/api/v1/sales` | Cashier+ | List sales history |
| `GET` | `/api/v1/sales/:id` | Cashier+ | Get sale receipt details |
| `POST` | `/api/v1/sales/:id/void` | Manager+ | Void sale and restore inventory balances |
| `GET` | `/api/v1/analytics/summary` | Manager+ | Business overview KPIs |
| `GET` | `/api/v1/analytics/sales-trend` | Manager+ | Daily/weekly revenue and sales trends |
| `GET` | `/api/v1/analytics/top-products` | Manager+ | Best performing products |
| `GET` | `/api/v1/analytics/profit` | Owner only | Gross profit, margins, and cost reports |
| `GET` | `/api/v1/users` | Manager+ | List staff members |
| `POST` | `/api/v1/users` | Owner only | Create staff member |
| `PUT` | `/api/v1/users/:id/role` | Owner only | Update staff role |
| `PUT` | `/api/v1/users/:id/status` | Owner only | Activate / deactivate staff member |

---

## 9. Testing & Quality Assurance

### Backend Test Suites
```bash
cd stockflow-api

# 1. Standalone Unit Tests (38 tests: auth, RBAC, calculations, controllers, validation)
npm run test:unit

# 2. PostgreSQL Database Integration Tests (8 tests: row locking, rollback, check constraints, oversell prevention)
npm run test:integration

# 3. Fresh Database Reproducibility & E2E Workflow (15 tests: empty DB -> migrations -> seeds -> business workflow)
npm run test:e2e

# Run all backend suites
npm run test:all
```

### Flutter Verification & Production Builds
```bash
cd stockflow_app

# Run static analysis (0 issues found)
flutter analyze

# Run unit and widget test suite (80 tests passed)
flutter test

# Build production Release APK (70.0 MB verified)
flutter build apk --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api

# Build Android App Bundle for Google Play Store publication
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

---

## 10. Continuous Integration (GitHub Actions)

Continuous integration is configured in `.github/workflows/ci.yml` and triggers automatically on pushes and pull requests to `main`:
- **Backend Job**: Sets up Node.js 20, caches npm packages, runs `npm ci`, and executes `npm run test:unit`.
- **Flutter Job**: Sets up Java 17 and stable Flutter, runs `flutter pub get`, runs `flutter analyze` for static code quality, and executes `flutter test` across all 80 unit and widget tests.

---

## 11. Deployment Status

> **Notice on Deployment Honesty**:
> StockFlow is **Deployment-Ready** with fully verified configurations for Neon Serverless PostgreSQL, Render (`render.yaml`), Railway, Docker Compose, and compiled Android Release APK (`70.0 MB`). It is not currently hosted at an active public URL, avoiding unmonitored server costs.

For complete cloud deployment instructions covering **Neon Managed PostgreSQL**, **Render / Railway Web Services**, and **Docker Compose**, refer to [DEPLOYMENT.md](file:///c:/Users/DHAVAL/Documents/fixit%20flutter%20project/DEPLOYMENT.md).

For the in-depth architectural case study, technical challenges, and interview guide, refer to [PORTFOLIO.md](file:///c:/Users/DHAVAL/Documents/fixit%20flutter%20project/PORTFOLIO.md).
#   s t o c l f l o w  
 