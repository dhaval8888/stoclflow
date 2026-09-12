/**
 * Fresh Database Reproducibility & End-to-End Business Workflow Test
 *
 * Tests the entire application lifecycle from a completely empty PostgreSQL database:
 * 1. Empty Database -> Run Migrations -> Run Seeds
 * 2. Health & API Documentation Check
 * 3. Multi-Role Authentication
 * 4. Complete End-to-End Business Lifecycle (Category -> Product -> Stock In -> Search -> POS Sale -> Inventory Decrement -> Audit Ledger -> Analytics -> RBAC Enforcement)
 */
process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'test_jwt_access_secret_for_e2e_testing_12345';
process.env.JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'test_jwt_refresh_secret_for_e2e_testing_12345';

const fs = require('fs');
const path = require('path');
const request = require('supertest');
const { PGlite } = require('@electric-sql/pglite');
const bcrypt = require('bcryptjs');

const dbConfig = require('../../src/config/db');
const app = require('../../src/app');

describe('Fresh Database Reproducibility & End-to-End Business Workflow', () => {
  let db;
  let clientWrapper;
  let ownerToken;
  let cashierToken;
  let createdCategoryId;
  let createdProductId;

  const demoBusinessId = 'b1000000-0000-4000-a000-000000000001';

  beforeAll(async () => {
    // ─── Step 1: Empty PostgreSQL Database ──────────────────────────────────────
    db = new PGlite();

    clientWrapper = {
      query: (text, params) => db.query(text, params),
      release: () => {},
    };

    jest.spyOn(dbConfig.pool, 'connect').mockImplementation(async () => clientWrapper);
    jest.spyOn(dbConfig.pool, 'query').mockImplementation((text, params) => db.query(text, params));

    // ─── Step 2: Run All Migrations on Empty Database ───────────────────────────
    await db.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        filename TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    const migrationsDir = path.join(__dirname, '..', '..', 'src', 'db', 'migrations');
    const migrationFiles = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();

    for (const file of migrationFiles) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      await db.exec(sql);
      await db.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [file]);
    }

    // ─── Step 3: Run Seed Data into Fresh Database ──────────────────────────────
    await db.query(`
      INSERT INTO roles (id, name) VALUES (1, 'OWNER'), (2, 'MANAGER'), (3, 'CASHIER')
      ON CONFLICT (id) DO NOTHING
    `);

    await db.query(`
      INSERT INTO businesses (id, name, address, phone, email, currency, timezone)
      VALUES ($1, 'Fresh Store', '42 Market Street', '+91-9876543210', 'admin@freshstore.com', 'INR', 'Asia/Kolkata')
      ON CONFLICT (id) DO NOTHING
    `, [demoBusinessId]);

    const ownerHash = await bcrypt.hash('Owner@123', 6);
    const cashierHash = await bcrypt.hash('Cashier@123', 6);

    await db.query(`
      INSERT INTO users (id, business_id, role_id, full_name, email, password_hash)
      VALUES
        ('11111111-0000-4000-a000-000000000001', $1, 1, 'Demo Owner', 'owner@demo.com', $2),
        ('33333333-0000-4000-a000-000000000003', $1, 3, 'Demo Cashier', 'cashier@demo.com', $3)
      ON CONFLICT (email) DO NOTHING
    `, [demoBusinessId, ownerHash, cashierHash]);
  });

  afterAll(async () => {
    jest.restoreAllMocks();
    if (db) await db.close();
  });

  describe('Health Endpoint & API Documentation', () => {
    it('GET /health returns 200 OK and confirms database is connected', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('healthy');
      expect(res.body.database).toBe('connected');
    });

    it('GET /api/health also responds with healthy status', async () => {
      const res = await request(app).get('/api/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('healthy');
    });

    it('GET /api-docs serves Swagger UI documentation', async () => {
      const res = await request(app).get('/api-docs/');
      expect(res.status).toBe(200);
      expect(res.text).toContain('Swagger UI');
    });
  });

  describe('Authentication Verification', () => {
    it('logs in as Owner with seeded credentials and receives JWT tokens', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ email: 'owner@demo.com', password: 'Owner@123' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.tokens.accessToken).toBeDefined();
      expect(res.body.data.user.role).toBe('OWNER');
      ownerToken = res.body.data.tokens.accessToken;
    });

    it('logs in as Cashier with seeded credentials', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ email: 'cashier@demo.com', password: 'Cashier@123' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.user.role).toBe('CASHIER');
      cashierToken = res.body.data.tokens.accessToken;
    });

    it('rejects invalid password with 401', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ email: 'owner@demo.com', password: 'WrongPassword' });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });
  });

  describe('End-to-End Business Operations Lifecycle', () => {
    it('1. Owner creates a new category', async () => {
      const res = await request(app)
        .post('/api/v1/categories')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ name: 'Wearables', colorHex: '#10B981' });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.category.name).toBe('Wearables');
      createdCategoryId = res.body.data.category.id;
    });

    it('2. Owner creates a new product in the category', async () => {
      const res = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          categoryId: createdCategoryId,
          name: 'Smart Watch Series 9',
          sku: 'SW-S9-45MM',
          barcode: '8909998887771',
          costPrice: 20000,
          sellingPrice: 35000,
          unit: 'pcs',
          lowStockThreshold: 3,
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.product.name).toBe('Smart Watch Series 9');
      createdProductId = res.body.data.product.id;
    });

    it('3. Owner performs STOCK_IN to add inventory', async () => {
      const res = await request(app)
        .post('/api/v1/inventory/transaction')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          productId: createdProductId,
          type: 'STOCK_IN',
          quantity: 10,
          note: 'Initial batch from supplier',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(parseFloat(res.body.data.transaction.quantity_after)).toBe(10);
    });

    it('4. User searches for the product in catalogue', async () => {
      const res = await request(app)
        .get('/api/v1/products?search=Smart Watch')
        .set('Authorization', `Bearer ${cashierToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.products.length).toBeGreaterThanOrEqual(1);
      expect(res.body.data.products[0].id).toBe(createdProductId);
    });

    it('5. Cashier executes a POS sale of 2 units', async () => {
      const res = await request(app)
        .post('/api/v1/sales')
        .set('Authorization', `Bearer ${cashierToken}`)
        .send({
          items: [{ productId: createdProductId, quantity: 2, discount: 0 }],
          paymentMethod: 'UPI',
          discountAmount: 1000,
          taxAmount: 0,
          note: 'In-store customer purchase',
        });

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(parseFloat(res.body.data.sale.total_amount)).toBe(69000); // (35000*2) - 1000 = 69000
    });

    it('6. Verifies inventory level decremented from 10 to 8', async () => {
      const invRes = await db.query(
        'SELECT quantity FROM inventory WHERE product_id = $1',
        [createdProductId]
      );
      expect(parseFloat(invRes.rows[0].quantity)).toBe(8);
    });

    it('7. Verifies audit ledger recorded the sale movement', async () => {
      const auditRes = await db.query(
        'SELECT * FROM inventory_transactions WHERE product_id = $1 AND type = $2',
        [createdProductId, 'SALE']
      );
      expect(auditRes.rows.length).toBe(1);
      expect(parseFloat(auditRes.rows[0].quantity)).toBe(-2);
      expect(parseFloat(auditRes.rows[0].quantity_before)).toBe(10);
      expect(parseFloat(auditRes.rows[0].quantity_after)).toBe(8);
    });

    it('8. Verifies analytics summary reflects the new revenue and sales', async () => {
      const res = await request(app)
        .get('/api/v1/analytics/summary')
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.sales.today_sales).toBeGreaterThanOrEqual(1);
      expect(parseFloat(res.body.data.sales.today_revenue)).toBeGreaterThanOrEqual(69000);
    });

    it('9. Enforces RBAC restrictions: Cashier is blocked from Owner endpoints', async () => {
      // Cashier attempts to access Owner profit report
      const profitRes = await request(app)
        .get('/api/v1/analytics/profit')
        .set('Authorization', `Bearer ${cashierToken}`);

      expect(profitRes.status).toBe(403);
      expect(profitRes.body.success).toBe(false);

      // Cashier attempts to create a product
      const createProdRes = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${cashierToken}`)
        .send({ name: 'Unauthorized Item', categoryId: createdCategoryId, costPrice: 10, sellingPrice: 20 });

      expect(createProdRes.status).toBe(403);
      expect(createProdRes.body.success).toBe(false);
    });
  });
});
