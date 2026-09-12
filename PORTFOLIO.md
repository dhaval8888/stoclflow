# StockFlow — Technical Portfolio & Architecture Case Study

> **StockFlow** is a production-grade, full-stack inventory management and Point-of-Sale (POS) system built with **Flutter (Material 3)** and **Node.js / Express / PostgreSQL**. It delivers real-time stock control, barcode scanning, pessimistic transaction-safe checkout, role-based access control (RBAC), and analytics.

---

## 1. Executive Summary

- **Domain**: Retail & Warehouse Inventory Management, Point of Sale (POS), Multi-Role Operations.
- **Client Application**: Cross-platform Flutter mobile client following Clean Architecture (data, application, presentation) with Riverpod 2.x state management, GoRouter declarative routing, and Material 3 design system.
- **Backend API**: Monolithic Node.js/Express REST service with PostgreSQL connection pooling, atomic transaction boundaries, strict schema validation (Zod), and JWT security with refresh token rotation.
- **Target Scale**: Single or multi-location businesses demanding zero-drift inventory tracking and concurrent sales protection.

---

## 2. Core Architecture & Design Decisions

### A. Full-Stack Monolithic Architecture
Rather than over-engineering with microservices or distributed queues, StockFlow adopts a clean, modular monolith.
- **Rationale**: A single deployable Node.js service running against a managed relational database minimizes network overhead, eliminates distributed transaction anomalies (2PC/Saga complexity), simplifies testing, and lowers operational infrastructure cost.
- **Domain Boundaries**: Modules are organized cleanly by domain: `auth`, `products`, `categories`, `inventory`, `sales`, `analytics`, `employees`, and `notifications`.

### B. PostgreSQL as the Single Source of Truth
Mobile clients **never directly mutate inventory levels** or store final authoritative balances.
- All stock movements (`STOCK_IN`, `STOCK_OUT`, `SALE`, `VOID_SALE`, `ADJUSTMENT`) are represented as an append-only audit trail in the `inventory_movements` ledger table, guarded by foreign keys and constraints.
- The `current_stock` balance in the `products` table is updated atomically within the same transaction that records the ledger movement.

### C. Pessimistic Row Locking for Concurrent POS Sales
One of the most critical engineering problems in retail systems is the "oversell anomaly": two cashiers scanning the last available item simultaneously.
- **Implementation**: During checkout, the sales service issues:
  ```sql
  SELECT id, current_stock, unit_price, cost_price, is_active 
  FROM products 
  WHERE id = ANY($1) 
  FOR UPDATE;
  ```
- **Guarantees**: PostgreSQL places row-level exclusive locks on the requested products in a single operation. If stock is insufficient, the transaction immediately issues a `ROLLBACK` and responds with `400 Bad Request` (`INSUFFICIENT_STOCK`). No partial writes or overselling can occur.

### D. Layered Client-Side Architecture (Flutter)
The mobile client strictly separates concerns into three distinct layers:
1. **Data Layer**: DTO models with robust JSON deserialization, Dio HTTP clients, interceptors for automatic JWT refresh with request queuing, and secure token persistence using `flutter_secure_storage`.
2. **Application Layer**: Riverpod `StateNotifier` controllers encapsulating business logic, search debouncing, race condition request matching (`_currentRequestId`), and deduplicating pagination.
3. **Presentation Layer**: Responsive screens and reusable widgets (empty states, error views with retry callbacks, skeleton loading, Material 3 theming with dynamic dark/light mode support).

---

## 3. Key Technical Challenges & Solutions

### Challenge 1: The JWT Refresh Token Concurrency Storm
- **Problem**: When an access token expires while multiple asynchronous HTTP requests (e.g. dashboard summary + notifications + profile) are in flight, multiple requests trigger parallel refresh calls simultaneously. Under refresh token rotation (where a token can only be used once), the first request rotates the token, and the subsequent parallel requests fail with `401 Token Reused / Invalid`, unexpectedly logging the user out.
- **Solution**: Implemented a **Mutex-locked Token Queue** inside the Dio `QueuedInterceptor`. When a `401 Unauthorized` occurs:
  1. The interceptor immediately acquires a lock and pauses incoming requests.
  2. Exactly one refresh request is dispatched to `/api/auth/refresh`.
  3. Upon success, the new tokens are securely stored, and all queued requests are retried with the updated authorization header.
  4. If the refresh token is genuinely invalid, the queue is rejected, and the auth state broadcasts a session expiration redirecting to the login screen.

### Challenge 2: Search Race Conditions & Out-of-Order API Responses
- **Problem**: As a user types into the product search bar, network latency can cause an earlier request (e.g., query `"appl"`) to resolve *after* a later request (e.g., query `"apple"`), overwriting the user's latest results with stale data.
- **Solution**:
  1. Built a 400ms debounce timer preventing excessive API requests on keystrokes.
  2. Implemented request ID generation (`_currentRequestId = DateTime.now().microsecondsSinceEpoch`). Any incoming response whose request ID does not match the active controller state is discarded before state mutation.

### Challenge 3: Role-Based UX Partitioning without Navigation State Errors
- **Problem**: `CASHIER` users should have access only to operational tasks (POS checkout, product catalogue, receipt history) and must not see financial KPIs (revenue, gross profit, inventory costs). Furthermore, dynamically hiding bottom navigation bar items caused `RangeError (index): Invalid value: Valid value range is empty: 0` when the active index pointed to a tab that disappeared.
- **Solution**:
  1. Partitioned navigation shells in GoRouter dynamically based on the authenticated user's role.
  2. Implemented a dedicated `_CashierDashboard` rendering quick operational actions (`New Sale`, `Browse Products`, `Sales History`) while omitting sensitive business cards.
  3. Clamped and reset navigation tab indices before rendering the scaffold.

---

## 4. Testing & Quality Assurance Strategy

StockFlow implements a two-tier testing strategy distinguishing fast unit tests from persistent database integration tests:

### Tier 1: Standalone Unit Tests
Runs instantaneously in CI/CD without external dependencies:
- **Backend Unit Tests** (`npm run test:unit`):
  - **Auth & RBAC**: Password hashing, JWT token generation, role verification (`authorize('OWNER', 'MANAGER')`), cashier rejection on manager routes.
  - **Sales Transaction Boundaries**: Mock client rollback verification, cart validation, discount ceiling checks (discount cannot exceed subtotal), and out-of-stock rejection.
  - **Inventory Ledger**: Stock-in, stock-out, manual adjustment, negative stock prevention, and invalid movement rejection.
- **Flutter Unit & Widget Tests** (`flutter test`):
  - 80 automated tests covering `CartController`, `ProductsController`, `EmployeesController`, `AnalyticsController`, form validation, error state rendering, and role-based dashboard views.

### Tier 2: Database Integration Tests
Runs against real PostgreSQL instances:
- Validates SQL foreign key constraints, unique indexing, schema migration rollback, and pessimistic row locking under concurrent load.

---

## 5. Security Hardening Measures

| Layer | Implementation |
|---|---|
| **HTTP Headers** | Configured `helmet` with secure defaults for Content Security Policy, XSS protection, and frameguard. |
| **Rate Limiting** | Strict rate limiting on authentication routes (5 requests / 15 minutes) and standard limits on business APIs. |
| **Data Sanitization** | `Zod` schemas validate and strip unexpected payload properties before controllers process input. |
| **Error Handling** | In production mode (`NODE_ENV=production`), generic safe error messages are returned; stack traces, SQL syntax errors, and schema table names are suppressed. |
| **Secrets Management** | Zero secrets in git. Strict gitignore policies with `.env.example` templates. Mobile client only receives `API_BASE_URL` via compile-time `--dart-define`. |

---

## 6. Technical Interview Talking Points

1. **Why use PostgreSQL row-level locks (`SELECT ... FOR UPDATE`) instead of Optimistic Concurrency Control (OCC) with version columns?**
   - *Talking Point*: "In a high-throughput POS checkout environment during peak retail hours, multiple cashiers may sell the same popular SKU within milliseconds. Optimistic locking relies on rollbacks and retries, which leads to retry storms and degraded user experience at the cash register. Pessimistic locking queues the checkouts cleanly, serializes stock validation, and fails predictably without retry overhead."

2. **How does StockFlow prevent secret leakage in mobile applications?**
   - *Talking Point*: "Mobile applications cannot keep secrets because APKs and IPAs can be decompiled. We ensure zero sensitive API keys (JWT secrets, Cloudinary secrets, DB credentials) exist in the mobile codebase. The Flutter app only knows the public `API_BASE_URL` injected at compile time via `--dart-define`. All privileged operations (image signing, password verification, transaction coordination) are mediated strictly by the backend."

3. **How is state management structured in Flutter for predictable UI rendering?**
   - *Talking Point*: "We use Riverpod `StateNotifier` paired with immutable state objects (`copyWith` pattern). Each feature screen derives its state from a single controller, handling four explicit states: Initial, Loading, Loaded, and Error. This eliminates intermediate inconsistent UI states and makes testing deterministic using mock providers."

---

## 7. Guided Project Walkthrough

1. **Authentication**: Log in as `owner@demo.com` (full business access) or `cashier@demo.com` (operational POS access).
2. **Dashboard**: Observe role-specific rendering — Owners see revenue, weekly growth, and low stock warnings; Cashiers see a streamlined POS launcher.
3. **Catalogue & Search**: Search for products with debounced autocomplete and filter by category.
4. **POS Cart & Barcode Scanner**: Add items to cart, adjust quantities up to available stock limit, apply line-item or order-level discounts, and select payment method (Cash, Card, UPI).
5. **Checkout & Atomic Deductions**: Complete sale — verify that product `current_stock` is decremented atomically and a corresponding `inventory_movements` record is written.
6. **Receipt & Void**: Inspect receipt and test manager-authorized void sale to reverse inventory movement automatically.
