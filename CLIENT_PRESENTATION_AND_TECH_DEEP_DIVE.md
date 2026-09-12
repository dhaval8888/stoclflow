# StockFlow — Client Presentation & Technical Deep Dive

> **A Complete Business Pitch, User Walkthrough, and Engineering Architecture Guide**

---

# PART 1: HOW TO EXPLAIN STOCKFLOW TO A CLIENT
*(Use this section when pitching StockFlow to store owners, retail clients, or business investors)*

---

## 1. The 30-Second Elevator Pitch

> *"StockFlow is an all-in-one smart Point of Sale (POS) and inventory control system designed specifically for retail stores. It turns any smartphone, tablet, or desktop into a high-speed cash register and real-time inventory tracker. Best of all, it automatically calculates your **exact daily net profits** and keeps your cashiers honest by hiding your wholesale costs and profits behind strict role security."*

---

## 2. The Big Business Problems StockFlow Solves

| Traditional Retail Problems | How StockFlow Solves It |
|---|---|
| **Inventory Shrinkage & Unexplained Losses** | Every single item added, removed, or sold is permanently logged with the cashier’s name, exact timestamp, and reason. |
| **"Am I Actually Making Money?"** | Most POS systems only show Total Revenue. StockFlow shows your **Net Profit** after subtracting wholesale item costs and customer discounts. |
| **Accidental Overselling & Stockouts** | Real-time stock alerts warn you before you run out of fast-moving items, and the POS physically prevents selling items you don't have. |
| **Cashier Snooping & Price Leaks** | Cashiers can only ring up sales. They can **never** see wholesale purchase costs, store profits, or owner settings. |
| **Expensive Dedicated Hardware** | No need to buy $1,500 proprietary barcode registers. StockFlow runs on standard phones, tablets, or computers using the built-in camera to scan barcodes. |

---

## 3. Core Features to Showcase to the Client

### 1. High-Speed Point of Sale (POS) & Checkout
- **Instant Product Lookup**: Tap items from the visual catalogue or scan barcodes with the camera.
- **Dynamic Cart Math**: Line totals, discounts, and store taxes are automatically calculated in real-time.
- **Multiple Payment Options**: Accept **Cash** (with automated change calculation), **Debit/Credit Card**, or **UPI / QR / Mobile Wallets**.
- **Digital Invoices & Receipts**: Instantly generates clean, itemized receipts with invoice numbers, store branding, and cashier IDs.

---

### 2. Smart Inventory & Stock Movements
Stores handle inventory in different ways every day. StockFlow gives store owners three clear operational workflows:

```
[ STOCK IN ]      ->  Receiving new shipments or supplier deliveries
[ STOCK OUT ]     ->  Recording damaged goods, breakage, or expired units
[ ADJUSTMENT ]    ->  Reconciling stock counts after a physical store audit
```

- **Initial Stock on Creation**: When adding a new product, you can set the current shelf count immediately so it’s ready to sell on day one.
- **Visual Stock Health**: Color-coded badges highlight:
  - 🟢 **In Stock**: Healthy supply
  - 🟡 **Low Stock**: Approaching minimum threshold
  - 🔴 **Out of Stock**: Completely sold out

---

### 3. Real-Time Profit & Margin Intelligence
Most apps stop at "Total Sales". StockFlow gives business owners **true financial transparency**:
- **Today's Profit**: Live profit earned so far today.
- **Weekly & Monthly Profit**: Identify which weeks generated the highest net margins.
- **All-Time Lifetime Overview**: Cumulative gross revenue and cumulative net profits since opening.
- **True Profit Math**: 
  $$\text{Net Profit} = \text{Selling Price} - \text{Wholesale Cost Price} - \text{Discounts}$$
- **Interactive Visuals**: Beautiful revenue and profit trend charts over 7, 30, and 90 days.
- **Top & Slow Sellers**: Instantly reveals your top 5 revenue-generating items and flags dead stock with zero sales in the last 30 days.

---

### 4. Cashier vs. Owner Role Security (RBAC)
Protect your store's private financial data:
- **`OWNER`**: Full control over settings, tax rates, employee payroll/roles, cost prices, and profit reports.
- **`MANAGER`**: Can adjust inventory, restock goods, view analytics, and ring up sales.
- **`CASHIER`**: Front-counter register only. Cashiers **cannot** see wholesale costs, profit margins, or analytics screens.

---

### 5. 100% Transparent Audit Ledger
Every inventory modification creates a permanent audit record:
- *Who* touched the stock (e.g., `fazal`)
- *What* they did (`STOCK_IN`, `STOCK_OUT`, `ADJUSTMENT`, `SALE`)
- *When* it happened (down to the second)
- *The exact change* (e.g., `+50 pcs`, `Before: 0 -> After: 50`)


---

## 4. Visual Product Tour

### A. Fast & Intuitive Product Catalog
Adding products is fast with automatic barcode scanning and instant margin calculations:

![New Product Form](docs/screenshots/01_new_product_form.png)

*The form lets store managers enter the wholesale cost price, customer selling price, unit of measure, and initial stock in one simple screen.*

---

### B. Live Product Overview & Status
Products are grouped with clear stock levels and pricing:

![Product Catalogue Cards](docs/screenshots/02_product_catalogue.png)

*Color-coded status indicators immediately notify staff when an item is in stock, low on stock, or out of stock.*

---

### C. Seamless Inventory Movements
Receiving a supplier delivery or writing off damaged stock takes just two taps:

![Inventory Movement Modal](docs/screenshots/03_inventory_movement_dialog.png)

*Staff can select Stock In, Stock Out, or Adjustment, type the count, and add an optional supplier invoice number or note.*

---

### D. Complete Audit Ledger
Total peace of mind with immutable before-and-after history:

![Inventory Audit Log](docs/screenshots/05_inventory_audit_log.png)

*Every single unit change is tracked with timestamp, cashier name, and before/after balances.*

---

## 5. "A Day in the Life" of a Store Using StockFlow

1. **8:00 AM — Morning Review**: The Owner opens StockFlow. The **Dashboard** shows 2 items on **Low Stock Alert**.
2. **10:00 AM — Deliveries Arrive**: A vendor delivers 50 boxes of coffee. The manager opens **Inventory**, taps **+**, selects **Stock In**, enters `50`, and types invoice `#PO-8821`. Available stock jumps from `0` to `50` instantly.
3. **1:00 PM — Busy Lunch Rush**: Cashiers use the **POS Register** on their phones/tablets. They scan barcodes using the camera, enter payment methods, and print digital receipts. The inventory decrements in real time without lag.
4. **4:00 PM — Stock Safety in Action**: A customer asks for 10 units of an item with only 4 in stock. The POS register displays a clear warning and prevents overselling.
5. **9:00 PM — Closing & Profit Check**: The Owner checks the **Analytics Screen**. The app shows:
   - **Total Revenue**: $1,450.00
   - **Cost of Goods**: $920.00
   - **Net Profit**: **$530.00**
   The owner goes home knowing *exactly* how much profit their business made today.

---
---

# PART 2: THE DEEP TECHNICAL ENGINEERING SPECIFICATION
*(Use this section for technical evaluation, code reviews, and developer handovers)*

---

## 1. High-Level Architecture Overview

StockFlow is structured as a **decoupled client-server architecture**:

```
 ┌────────────────────────────────────────────────────────┐
 │                   Flutter Mobile App                   │
 │   Riverpod (State)  •  Dio (HTTP)  •  GoRouter (Nav)   │
 └───────────────────────────┬────────────────────────────┘
                             │ JSON / REST over HTTPS
                             ▼
 ┌────────────────────────────────────────────────────────┐
 │               Node.js / Express.js REST API            │
 │   Routes  •  Controllers  •  Services  •  Repositories │
 └───────────────────────────┬────────────────────────────┘
                             │ Parameterized SQL Pool
                             ▼
 ┌────────────────────────────────────────────────────────┐
 │               PostgreSQL Relational DB                 │
 │   ACID Transactions • Row Locks • CHECK Constraints    │
 └────────────────────────────────────────────────────────┘
```

---

## 2. Frontend Engineering (Flutter & Dart)

### State Management: Riverpod 2.x
- Uses `StateNotifierProvider` and immutable state models built with Dart.
- **UI Decoupling**: Screens only observe state via `ref.watch()`. All business logic lives in controllers (`CartController`, `ProductsController`, `InventoryController`, `AnalyticsController`).
- **Debounced Search**: Search input debounces network requests by 400ms to eliminate redundant API pressure.

### HTTP Client & Token Lifecycle (Dio)
- Configured with a dedicated `AuthInterceptor`:
  1. Automatically attaches `Authorization: Bearer <access_token>` to all protected outgoing requests.
  2. If a request fails with `401 Unauthorized`, the interceptor queues the request, calls `POST /api/v1/auth/refresh` using the secure refresh token, updates the token store, and retries the original request seamlessly without logging the user out.
  3. If refresh fails, securely wipes device tokens and redirects to `/login`.

### Secure Hardware Storage
- Authentication tokens are stored via `flutter_secure_storage`:
  - **Android**: Stored in the Android Keystore with AES-256 GCM encryption.
  - **iOS**: Stored in the iOS Keychain.

### Barcode Scanner
- Integrated with `mobile_scanner` leveraging Google ML Kit hardware acceleration for zero-latency camera scanning on iOS and Android.

---

## 3. Backend Engineering (Node.js & Express)

### Modular Domain Architecture
The API is split into independent domain modules inside `stockflow-api/src/modules/`:
- `auth/`: User registration, JWT login, token refresh, and profile fetching.
- `business/`: Store configuration, currency, timezone, and tax settings.
- `products/`: Product catalogue CRUD, category grouping, and image uploads.
- `inventory/`: Real-time stock queries, stock adjustments, and audit log retrieval.
- `sales/`: Point of Sale checkout pipeline, cart validation, and receipt generation.
- `analytics/`: Aggregate reporting, revenue calculation, profit math, and sales trends.
- `users/`: Employee onboarding, role assignment, and staff management.

### The 4-Layer Execution Pattern
```
HTTP Request
     │
     ▼
[ Route ]        -> Defines URL pattern, HTTP method, and rate-limiting
     │
     ▼
[ Middleware ]   -> Authenticates JWT & checks role authorization (RBAC)
     │
     ▼
[ Controller ]   -> Validates request schema, casts types, handles HTTP responses
     │
     ▼
[ Service ]      -> Executes business rules, ensures integrity, orchestrates DB
     │
     ▼
[ Repository ]   -> Executes clean, parameterized SQL queries via PostgreSQL pool
```

### Security & Hardening
- **Password Security**: Passwords hashed with `bcryptjs` using 10 salt rounds.
- **SQL Injection Prevention**: 100% of database interactions use parameterized queries (`$1, $2, ...`). Zero string interpolation in SQL.
- **HTTP Hardening**: `helmet` headers, strict `cors` policies, and `express-rate-limit` to prevent brute-force authentication attacks.

---

## 4. Database Architecture & PostgreSQL ACID Guarantees

### Relational Schema Design

```
   [businesses] 1 ──── ∞ [users] (OWNER, MANAGER, CASHIER)
        │
        ├──────────── ∞ [categories]
        │                     │
        ├──────────── ∞ [products] 1 ──── 1 [inventory] (CHECK qty >= 0)
        │                     │
        │                     ├────────── ∞ [inventory_transactions] (Audit Log)
        │                     │
        └──────────── ∞ [sales] 1 ─────── ∞ [sale_items]
```

### 1. Zero-Overselling Concurrency Protection
In a busy store with multiple cashiers ringing up sales simultaneously, race conditions can cause negative stock. StockFlow eliminates this using row-level locking:
```sql
SELECT quantity FROM inventory WHERE product_id = $1 FOR UPDATE;
```
`FOR UPDATE` locks the targeted product inventory row in PostgreSQL. Any concurrent sale transaction for the same product must wait until the first sale completes.

### 2. The Atomic Checkout Pipeline
When a checkout request is processed:
1. `await db.query('BEGIN')` initiates an atomic transaction.
2. Every item's inventory is checked and decremented.
3. If **any** item fails (e.g., customer ordered 5, but only 3 remain):
   - The server triggers `await db.query('ROLLBACK')`.
   - No sale is recorded.
   - No inventory is deducted.
   - An informative `400 Insufficient stock` error is returned to the user.
4. If all items pass, audit transaction records and the parent sale invoice are written, followed by `await db.query('COMMIT')`.

### 3. Database Constraints as Safety Nets
Even if an application-level bug occurred, PostgreSQL strictly enforces:
```sql
CONSTRAINT chk_inventory_qty_non_negative CHECK (quantity >= 0);
```
Any operation attempting to reduce stock below 0 is rejected at the database engine level.

---

## 5. The Financial Computation Engine

### Real-Time Net Profit SQL Formula
Net profit is calculated dynamically without cached totals that could drift out of sync:
```sql
SELECT
  COALESCE(SUM(s.total_amount), 0)::FLOAT AS total_revenue,
  COALESCE((
    SELECT SUM(si.line_total - (si.quantity * COALESCE(p.cost_price, 0)))
    FROM sale_items si
    JOIN sales s2 ON s2.id = si.sale_id
    LEFT JOIN products p ON p.id = si.product_id
    WHERE s2.business_id = $1 AND s2.status = 'COMPLETED'
  ), 0)::FLOAT AS total_profit
FROM sales s
WHERE s.business_id = $1 AND s.status = 'COMPLETED';
```
- `si.line_total` accounts for actual selling price minus item-level discounts.
- `si.quantity * p.cost_price` calculates the true Cost of Goods Sold (COGS).
- Difference represents net gross profit earned.

### Decimal String Safety (PostgreSQL to Dart)
PostgreSQL `NUMERIC(12,3)` returns numbers as strings in Node.js (e.g. `'50.000'`).
Dart's standard `int.tryParse('50.000')` returns `null` (causing accidental `0` resets).
StockFlow implements resilient parsing across all models:
```dart
currentQuantity: (double.tryParse(json['quantity']?.toString() ?? '0') ?? 0).round()
```
This ensures that floating and decimal stock values from PostgreSQL are parsed safely into integer units.

---

## 6. Testing, Quality Assurance & Verification

### Test Suite Summary

| Test Suite | Framework | Scope | Results |
|---|---|---|---|
| **Backend Unit Tests** | Jest | Controllers, Services, Auth & RBAC | **38 Passed**, 0 Failed |
| **Backend Integration Tests** | Jest + PGlite | Real PostgreSQL engine, ACID transactions, Concurrency & Rollbacks | **8 Passed**, 0 Failed |
| **Frontend Unit Tests** | Flutter Test | Riverpod Controllers, State Transitions, Cart Math, API Exception Handling | **49 Passed**, 0 Failed |
| **Static Code Analysis** | `flutter analyze` | Clean syntax, null safety, zero dead code | **0 Issues Found** |

---

## 7. Developer Cheatsheet: Running the Project Locally

StockFlow does **not** require Docker for local development.

### 1. Database
Ensure local PostgreSQL is running on port `5432`:
```sql
CREATE DATABASE stockflow;
```

### 2. Backend
```bash
cd stockflow-api
npm install
npm run migrate
npm run seed
npm run dev
```
*API runs at `http://localhost:3000`.*

### 3. Frontend
```bash
cd stockflow_app
flutter pub get
flutter run -d emulator-5554
```
*Connects to backend via `http://10.0.2.2:3000/api/v1`.*

---

## 8. Summary Checklist for Client Demos

When demonstrating StockFlow to a client, walk through these 5 key steps:
1. **Show the Dashboard**: Point out **Today's Revenue** vs **Today's Profit** — highlight how rare it is for POS systems to show true profit.
2. **Show the Product Form**: Create an item, set cost price and selling price, and show how initial stock can be set on day one.
3. **Ring Up a Sale at the POS**: Add the item to cart, apply a small discount, select **Cash**, show the change calculation, and complete the sale.
4. **Show Real-Time Inventory Deduction**: Open Inventory and show how stock automatically decremented by the exact sale quantity.
5. **Show the Audit Log**: Open the Audit Log tab to show the client that every action records the cashier's name and exact before/after balance.
