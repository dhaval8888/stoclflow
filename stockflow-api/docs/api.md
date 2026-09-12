# STOCKFLOW API — Endpoint Reference

**Base URL:** `http://localhost:3000/api/v1`

**Authentication:** All protected endpoints require:
```
Authorization: Bearer <access_token>
```

---

## Response Format

All responses follow this structure:

```json
{
  "success": true,
  "message": "Optional message",
  "data": { ... }
}
```

**Error format:**
```json
{
  "success": false,
  "status": "error",
  "message": "Human-readable error description"
}
```

**Paginated responses** include a `meta` object:
```json
{
  "data": {
    "products": [...],
    "meta": {
      "page": 1,
      "limit": 20,
      "total": 150,
      "totalPages": 8,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

---

## AUTH — `/api/v1/auth`

| Method | Endpoint | Auth | Role | Description |
|--------|----------|------|------|-------------|
| POST | `/register` | No | — | Register new business + OWNER account |
| POST | `/login` | No | — | Login, returns JWT pair |
| POST | `/refresh` | No | — | Refresh access token |
| POST | `/logout` | No | — | Invalidate refresh token |
| GET | `/me` | ✅ | All | Get current user profile |

### POST /auth/register
```json
{
  "businessName": "Raj Electronics",
  "businessAddress": "123 Main Street",
  "businessPhone": "9876543210",
  "fullName": "Raj Kumar",
  "email": "raj@rajelectronics.com",
  "password": "SecurePass@123"
}
```

### POST /auth/login
```json
{
  "email": "owner@demo.com",
  "password": "Owner@123"
}
```
**Response includes:** `tokens.accessToken`, `tokens.refreshToken`, `user` object

### POST /auth/refresh
```json
{ "refreshToken": "<refresh_token>" }
```
**Response includes:** `{ "accessToken": "<new_jwt>", "refreshToken": "<new_rotated_jwt>" }`
*(The incoming refresh token is immediately invalidated upon rotation)*

### POST /auth/logout
```json
{ "refreshToken": "<refresh_token>" }
```

---

## BUSINESS — `/api/v1/business`

| Method | Endpoint | Role | Description |
|--------|----------|------|-------------|
| GET | `/` | All | Get business profile |
| PATCH | `/` | OWNER | Update business profile |

### PATCH /business
```json
{
  "name": "Updated Store Name",
  "address": "456 New Street",
  "phone": "9876543211",
  "email": "store@email.com",
  "currency": "INR",
  "timezone": "Asia/Kolkata"
}
```

---

## EMPLOYEES — `/api/v1/users`

| Method | Endpoint | Role | Description |
|--------|----------|------|-------------|
| GET | `/` | OWNER, MANAGER | List all employees |
| POST | `/` | OWNER | Add new employee |
| GET | `/:id` | OWNER, MANAGER | Get employee details |
| PATCH | `/:id` | OWNER | Update employee |
| DELETE | `/:id` | OWNER | Deactivate employee |

**Query params for GET /users:**
- `role` — `MANAGER` or `CASHIER`
- `search` — search name/email
- `isActive` — `true` or `false`
- `page`, `limit` — pagination

### POST /users
```json
{
  "fullName": "Priya Sharma",
  "email": "priya@store.com",
  "phone": "9876543212",
  "password": "Employee@123",
  "role": "CASHIER"
}
```
**Roles allowed:** `MANAGER`, `CASHIER` (cannot create `OWNER`)

---

## CATEGORIES — `/api/v1/categories`

| Method | Endpoint | Role | Description |
|--------|----------|------|-------------|
| GET | `/` | All | List categories with product count |
| POST | `/` | OWNER, MANAGER | Create category |
| PATCH | `/:id` | OWNER, MANAGER | Update category |
| DELETE | `/:id` | OWNER, MANAGER | Delete category |

### POST /categories
```json
{
  "name": "Electronics",
  "description": "Electronic devices and accessories",
  "colorHex": "#3B82F6"
}
```

---

## PRODUCTS — `/api/v1/products`

| Method | Endpoint | Role | Description |
|--------|----------|------|-------------|
| GET | `/` | All | List products (paginated) |
| POST | `/` | OWNER, MANAGER | Create product |
| GET | `/:id` | All | Get product by ID |
| PATCH | `/:id` | OWNER, MANAGER | Update product |
| DELETE | `/:id` | OWNER, MANAGER | Soft-delete product |
| GET | `/barcode/:code` | All | Lookup by barcode |
| GET | `/sku/:sku` | All | Lookup by SKU |
| POST | `/:id/images` | OWNER, MANAGER | Upload product image |
| DELETE | `/:id/images/:imageId` | OWNER, MANAGER | Remove product image |

**Query params for GET /products:**
- `search` — searches name, SKU, barcode
- `categoryId` — UUID
- `stockStatus` — `IN_STOCK`, `LOW_STOCK`, `OUT_OF_STOCK`
- `isActive` — `true` (default), `false`, `all`
- `page`, `limit`

### POST /products
```json
{
  "name": "iPhone 15 Pro",
  "description": "Apple flagship smartphone",
  "categoryId": "<uuid>",
  "sku": "IPHONE-15-PRO-128",
  "barcode": "8901234567890",
  "unit": "pcs",
  "costPrice": 85000,
  "sellingPrice": 99000,
  "lowStockThreshold": 5
}
```

**Units:** `pcs`, `kg`, `ltr`, `gm`, `ml`, `box`, `dozen`, `pair`

---

## INVENTORY — `/api/v1/inventory`

> All inventory endpoints require **OWNER** or **MANAGER** role.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | All products with stock levels |
| GET | `/low-stock` | Products at or below threshold |
| GET | `/out-of-stock` | Products with zero quantity |
| GET | `/transactions` | Inventory transaction history |
| POST | `/transaction` | Create stock movement |
| GET | `/:productId` | Stock level for single product |

**Query params for GET /:**
- `search` — product name or SKU
- `page`, `limit`

**Query params for GET /transactions:**
- `productId`, `type`, `startDate`, `endDate`, `page`, `limit`

### POST /inventory/transaction
```json
{
  "productId": "<uuid>",
  "type": "STOCK_IN",
  "quantity": 50,
  "note": "Received from supplier ABC"
}
```
**Types:** `STOCK_IN`, `STOCK_OUT`, `ADJUSTMENT`

> `SALE` and `RETURN` types are created automatically by the sales service.

---

## SALES / POS — `/api/v1/sales`

| Method | Endpoint | Role | Description |
|--------|----------|------|-------------|
| POST | `/` | All | Create sale (atomic) |
| GET | `/` | All | List sales (cashier sees own only) |
| GET | `/:id` | All | Sale details |
| GET | `/:id/receipt` | All | Receipt data (with business info) |
| POST | `/:id/void` | OWNER, MANAGER | Void sale + restore inventory |

### POST /sales
```json
{
  "items": [
    {
      "productId": "<uuid>",
      "quantity": 2,
      "discount": 0
    }
  ],
  "paymentMethod": "CASH",
  "discountAmount": 0,
  "taxAmount": 0,
  "note": "Walk-in customer"
}
```
> **Security Notice:** `unitPrice` is strictly retrieved from the database on the server. The client cannot set or manipulate product prices. Optional item and total discounts are explicitly validated server-side.

**Payment methods:** `CASH`, `CARD`, `UPI`, `OTHER`

**Atomic sale process:**
1. Validate products exist and are active
2. Lock inventory rows (`SELECT FOR UPDATE`)
3. Validate sufficient stock
4. Calculate totals
5. Create `sales` record
6. Create `sale_items` records (price snapshot)
7. Update `inventory` quantities
8. Create `inventory_transactions` (type=SALE)
9. `COMMIT` — or full `ROLLBACK` on any failure

---

## ANALYTICS — `/api/v1/analytics`

> All analytics endpoints require **OWNER** or **MANAGER** role.

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/summary` | Dashboard: today/week/month stats + recent sales |
| GET | `/sales-trend` | Daily revenue for last N days |
| GET | `/top-products` | Best-selling by quantity |
| GET | `/slow-products` | Products with no sales in period |
| GET | `/inventory-value` | Total stock valuation |
| GET | `/profit` | Estimated gross profit |
| GET | `/report` | Grouped sales by period |

**Query params:**
- `GET /sales-trend?days=30`
- `GET /top-products?days=30&limit=10`
- `GET /slow-products?days=30`
- `GET /profit?days=30`
- `GET /report?period=daily` (or `weekly`, `monthly`)

### Sample /summary response
```json
{
  "data": {
    "sales": {
      "today_sales": 12,
      "today_revenue": "45000.00",
      "week_sales": 87,
      "week_revenue": "312500.00",
      "month_sales": 342,
      "month_revenue": "1250000.00",
      "total_sales": 1205,
      "total_revenue": "4800000.00"
    },
    "products": {
      "total_products": 48,
      "active_products": 45
    },
    "alerts": {
      "low_stock_count": 3,
      "out_of_stock_count": 1
    },
    "recentSales": [ ... ]
  }
}
```

---

## NOTIFICATIONS — `/api/v1/notifications`

| Method | Endpoint | Role | Description |
|--------|----------|------|-------------|
| POST | `/token` | All | Register device FCM token |
| DELETE | `/token` | All | Remove device FCM token |

### POST /notifications/token
```json
{
  "token": "<firebase_device_token>",
  "platform": "android"
}
```

---

## HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created |
| 400 | Bad request / validation error |
| 401 | Unauthenticated |
| 403 | Unauthorized (wrong role) |
| 404 | Not found |
| 409 | Conflict (duplicate SKU, email, etc.) |
| 422 | Zod validation failure |
| 500 | Internal server error |

---

## Environment Variables

```env
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/stockflow_db

# JWT
JWT_ACCESS_SECRET=<64-char-random-string>
JWT_REFRESH_SECRET=<64-char-random-string>
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# Cloudinary
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=

# Firebase (service account JSON path or inline)
FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=

# Server
NODE_ENV=development
PORT=3000
```

---

## Flutter Integration Notes

- **Base URL (emulator):** `http://10.0.2.2:3000/api/v1`
- **Base URL (real device):** `http://<your-machine-ip>:3000/api/v1`
- Store `accessToken` in `flutter_secure_storage`
- On 401 response → call `POST /auth/refresh` → retry original request
- On `LOW_STOCK` or `OUT_OF_STOCK` push notification → navigate to `/inventory/low-stock`
