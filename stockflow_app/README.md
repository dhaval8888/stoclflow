# StockFlow Mobile App

**StockFlow** is an enterprise-grade Smart Inventory, Point-of-Sale (POS), and Business Management mobile application built with **Flutter** and **Material Design 3**, designed for modern retail and warehouse operations. It connects to a secure Node.js/Express REST backend backed by PostgreSQL.

---

## 🏛️ Architecture & Design System

StockFlow adheres to a strict **Feature-First Architecture** combined with principles of Clean Architecture:

```
lib/
├── core/
│   ├── constants/       # App-wide constants, dimensions, API endpoints
│   ├── network/         # Dio client, JWT refresh interceptor, ApiException
│   ├── router/          # GoRouter configuration & route guards
│   ├── theme/           # Material 3 light/dark themes & color palette
│   ├── utils/           # Debouncer, formatters, validators
│   └── widgets/         # Reusable design system primitives (buttons, text fields, state views)
└── features/
    ├── auth/            # Authentication, session restoration, RBAC
    ├── categories/      # Category management & color badges
    ├── products/        # Product catalog, debounced search, deep links, image upload
    ├── inventory/       # Stock tracking, adjustments, movement audits
    ├── sales/           # POS terminal, barcode scanning, cart calculation, receipts, voiding
    ├── dashboard/       # Executive metrics & quick actions
    └── settings/        # Profile, role permissions, appearance preferences
```

### Layer Separation
1. **Presentation Layer (`presentation/`)**:
   - Pure UI widgets, screens, and dialogs.
   - Consumes state via `ConsumerWidget` or `ConsumerStatefulWidget`.
   - Emits user events to controllers without executing direct business logic.
2. **Application Layer (`application/`)**:
   - `StateNotifier` controllers managing immutable state classes (`copyWith`).
   - Contains UI-level business logic, search debouncing, pagination coordination, and cart calculations.
3. **Data Layer (`data/`)**:
   - **Models**: Hand-crafted, zero-codegen immutable models with serialization (`fromJson`, `toJson`).
   - **Repositories**: Isolated API communication layer converting HTTP responses into strongly-typed domain models and throwing centralized `ApiException`s.

---

## 🔐 Security & Networking Architecture

- **Token Storage**: Access and refresh tokens are stored securely in `FlutterSecureStorage` (Keychain on iOS, EncryptedSharedPreferences on Android).
- **Silent Refresh Token Rotation**:
  - The custom Dio interceptor queues concurrent requests when a 401 response occurs.
  - A single refresh request executes with rotation protection; subsequent queued requests retry seamlessly with the new access token.
- **Session Restoration & Invalidation**:
  - Cold-start session checks validate the stored token against `/api/v1/auth/me`.
  - HTTP `401 Unauthorized` or `403 Forbidden` instantly purges stored tokens to prevent unauthorized persistence.
  - Genuine network connection drops fall back to cached user credentials for seamless offline viewing.
- **Role-Based Sensitive Field Protection**:
  - Profit margins and unit cost prices are automatically sanitized on cashier accounts while accessible to managers and owners.

---

## ⚡ Production Readiness & Engineering Highlights (Phase 4.5)

- **Debounced Search & Stale Response Discard**:
  - Product catalog search uses a 400ms debouncer.
  - An atomic `_activeRequestId` sequence guard discards out-of-order network responses, eliminating search race conditions.
- **Resilient Non-Destructive Pagination**:
  - Page 1 cached data is preserved if a pagination (`loadMore()`) network request fails.
  - Retries can be triggered without resetting the list state.
  - Product items are automatically deduplicated by ID to prevent duplicate widget keys.
- **Deep-Link & Direct Lookup**:
  - Product details support both in-memory routing and direct repository fetch (`getProductById`), allowing deep links and unbuffered page navigation.
- **Standardized View Primitives**:
  - Reusable `LoadingView`, `EmptyStateView`, and `ErrorStateView` with user-friendly error translations (zero raw Dio leakages to end users).
- **Strict Null Safety**:
  - Zero unsafe `!` force-unwraps on network models and zero silent `catch (_) {}` blocks.

---

## 🧪 Testing Suite

The repository contains an automated test suite spanning unit, widget, and end-to-end integration tests:

| Test Type | Directory | Coverage |
| :--- | :--- | :--- |
| **Unit Tests** | `test/unit/` | `ApiException` status mapping, `AuthController` session lifecycle, `ProductsController` debouncing & pagination, `CartController` calculations & bounds |
| **Widget Tests** | `test/widget/` | `LoginScreen` validation & loading state, `StatusBadge`, `AppButton`, `LoadingView`, `EmptyStateView`, `ErrorStateView` |
| **Integration Tests** | `test/integration/` | Full `ProviderContainer` auth lifecycle (cold start, login, session storage, restart, logout, 401 revocation, offline fallback) |
| **Business Flow** | `test/phase4_business_test.dart` | POS cart totals, stock limit clamps, sensitive field masking, receipt parsing, voided sale state |

### Running the Tests

```bash
# Run all tests
flutter test

# Run specific suites
flutter test test/unit/
flutter test test/widget/
flutter test test/integration/

# Run static analysis (0 warnings, 0 errors)
flutter analyze
```

---

## 🚀 Setup & Local Execution

### Prerequisites
- **Flutter SDK**: `>= 3.13.2`
- **Dart SDK**: `>= 3.1.0`
- **Node.js**: `>= 18.0.0` (for `stockflow-api`)
- **PostgreSQL**: `>= 14.0`

### 1. Start Backend API
```bash
cd "../stockflow-api"
npm install
npm run migrate
npm run seed # Seeds owner (alex@stockflow.com) and test inventory
npm run dev  # Runs on http://localhost:5000
```

### 2. Configure & Run Flutter App
```bash
cd "stockflow_app"

# Install dependencies
flutter pub get

# Verify static code health
flutter analyze

# Launch mobile client
flutter run
```

### Default Credentials (from Backend Seed)
- **Owner**: `alex@stockflow.com` / `Password123!`
- **Manager**: `sarah@stockflow.com` / `Password123!`
- **Cashier**: `john@stockflow.com` / `Password123!`
