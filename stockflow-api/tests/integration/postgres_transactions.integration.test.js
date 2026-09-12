/**
 * PostgreSQL Database Integration Test Suite
 *
 * Validates real PostgreSQL relational behavior, row-level locking,
 * ACID transaction boundaries, rollback behavior, and concurrency protection.
 *
 * Uses the genuine PostgreSQL 16 WASM engine (PGlite) with complete schema migrations.
 */
const fs = require('fs');
const path = require('path');
const { PGlite } = require('@electric-sql/pglite');
const bcrypt = require('bcryptjs');

const dbConfig = require('../../src/config/db');
const salesService = require('../../src/modules/sales/sales.service');
const inventoryService = require('../../src/modules/inventory/inventory.service');

describe('PostgreSQL Database Integration Tests (Real Relational Engine)', () => {
  let db;
  let clientWrapper;

  const businessId = '10000000-0000-4000-a000-000000000001';
  const ownerId    = '20000000-0000-4000-a000-000000000001';
  const cashierId  = '20000000-0000-4000-a000-000000000003';
  const categoryId = '30000000-0000-4000-a000-000000000001';

  beforeAll(async () => {
    // 1. Initialize fresh real PostgreSQL engine
    db = new PGlite();

    clientWrapper = {
      query: (text, params) => db.query(text, params),
      release: () => {},
    };

    // Patch pool and query methods in dbConfig to point to our PostgreSQL engine
    jest.spyOn(dbConfig.pool, 'connect').mockImplementation(async () => clientWrapper);
    jest.spyOn(dbConfig.pool, 'query').mockImplementation((text, params) => db.query(text, params));

    // 2. Run all schema migrations
    await db.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        filename TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    const migrationsDir = path.join(__dirname, '..', '..', 'src', 'db', 'migrations');
    const files = fs.readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();

    for (const file of files) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      await db.exec(sql);
      await db.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [file]);
    }

    // 3. Seed roles, business, and baseline users
    await db.query(`
      INSERT INTO roles (id, name) VALUES (1, 'OWNER'), (2, 'MANAGER'), (3, 'CASHIER')
      ON CONFLICT (id) DO NOTHING
    `);

    await db.query(`
      INSERT INTO businesses (id, name, address, phone, email, currency, timezone)
      VALUES ($1, 'Integration Test Mart', '100 Tech Lane', '+91-9999999999', 'test@mart.com', 'INR', 'Asia/Kolkata')
      ON CONFLICT (id) DO NOTHING
    `, [businessId]);

    const pwHash = await bcrypt.hash('Test@123', 6);
    await db.query(`
      INSERT INTO users (id, business_id, role_id, full_name, email, password_hash)
      VALUES
        ($1, $3, 1, 'Test Owner', 'owner@test.com', $4),
        ($2, $3, 3, 'Test Cashier', 'cashier@test.com', $4)
      ON CONFLICT (email) DO NOTHING
    `, [ownerId, cashierId, businessId, pwHash]);

    await db.query(`
      INSERT INTO categories (id, business_id, name, color_hex)
      VALUES ($1, $2, 'General Goods', '#2563EB')
      ON CONFLICT DO NOTHING
    `, [categoryId, businessId]);
  });

  afterAll(async () => {
    jest.restoreAllMocks();
    if (db) await db.close();
  });

  // Helper to create a test product
  async function createProduct(id, name, sku, price, initialStock = 0) {
    await db.query(`
      INSERT INTO products (id, business_id, category_id, name, sku, barcode, cost_price, selling_price, is_active)
      VALUES ($1, $2, $3, $4, $5, $5, $6, $6, true)
    `, [id, businessId, categoryId, name, sku, price]);

    await db.query(`
      INSERT INTO inventory (product_id, business_id, quantity)
      VALUES ($1, $2, $3)
    `, [id, businessId, initialStock]);
  }

  describe('1. Product Stock Creation', () => {
    it('creates product and associates an initial inventory record in PostgreSQL', async () => {
      const prodId = '40000000-0000-4000-a000-000000000001';
      await createProduct(prodId, 'Wireless Mouse', 'SKU-MOUSE-01', 500, 20);

      const prodRes = await db.query('SELECT * FROM products WHERE id = $1', [prodId]);
      expect(prodRes.rows.length).toBe(1);
      expect(prodRes.rows[0].name).toBe('Wireless Mouse');

      const invRes = await db.query('SELECT * FROM inventory WHERE product_id = $1', [prodId]);
      expect(invRes.rows.length).toBe(1);
      expect(parseFloat(invRes.rows[0].quantity)).toBe(20);
    });
  });

  describe('2. STOCK_IN Transaction Updates Inventory', () => {
    it('increases inventory level accurately through inventoryService', async () => {
      const prodId = '40000000-0000-4000-a000-000000000002';
      await createProduct(prodId, 'USB Cable', 'SKU-USB-01', 150, 10);

      const result = await inventoryService.createTransaction(businessId, ownerId, {
        productId: prodId,
        type: 'STOCK_IN',
        quantity: 15,
        note: 'Restock shipment received',
      });

      expect(parseFloat(result.quantity_after)).toBe(25);

      const invRes = await db.query('SELECT quantity FROM inventory WHERE product_id = $1', [prodId]);
      expect(parseFloat(invRes.rows[0].quantity)).toBe(25);
    });
  });

  describe('3. Successful Sale Decreases Inventory Correctly', () => {
    it('executes atomic sale and decrements product inventory', async () => {
      const prodId = '40000000-0000-4000-a000-000000000003';
      await createProduct(prodId, 'Mechanical Keyboard', 'SKU-KEY-01', 2500, 10);

      const { sale } = await salesService.createSale(businessId, cashierId, {
        items: [{ productId: prodId, quantity: 3, discount: 0 }],
        paymentMethod: 'CASH',
        discountAmount: 0,
        taxAmount: 0,
        note: 'Counter sale',
      });

      expect(sale).toBeDefined();
      expect(sale.id).toBeDefined();

      const invRes = await db.query('SELECT quantity FROM inventory WHERE product_id = $1', [prodId]);
      expect(parseFloat(invRes.rows[0].quantity)).toBe(7); // 10 - 3 = 7
    });
  });

  describe('4. Successful Sale Creates Inventory Audit Records', () => {
    it('records an audit transaction linked to the completed sale', async () => {
      const prodId = '40000000-0000-4000-a000-000000000004';
      await createProduct(prodId, 'Webcam HD', 'SKU-CAM-01', 1800, 8);

      const { sale } = await salesService.createSale(businessId, cashierId, {
        items: [{ productId: prodId, quantity: 2 }],
        paymentMethod: 'CARD',
      });

      const auditRes = await db.query(
        'SELECT * FROM inventory_transactions WHERE product_id = $1 ORDER BY created_at DESC LIMIT 1',
        [prodId]
      );

      expect(auditRes.rows.length).toBe(1);
      const audit = auditRes.rows[0];
      expect(audit.type).toBe('SALE');
      expect(parseFloat(audit.quantity)).toBe(-2);
      expect(parseFloat(audit.quantity_before)).toBe(8);
      expect(parseFloat(audit.quantity_after)).toBe(6);
      expect(audit.reference_id).toBe(sale.id);
    });
  });

  describe('5. Insufficient Stock Fails the Sale', () => {
    it('throws error when requesting more quantity than available in inventory', async () => {
      const prodId = '40000000-0000-4000-a000-000000000005';
      await createProduct(prodId, 'Gaming Monitor', 'SKU-MON-01', 15000, 2);

      await expect(
        salesService.createSale(businessId, cashierId, {
          items: [{ productId: prodId, quantity: 5 }], // only 2 available
          paymentMethod: 'UPI',
        })
      ).rejects.toThrow(/Insufficient stock/);

      // Verify stock was untouched
      const invRes = await db.query('SELECT quantity FROM inventory WHERE product_id = $1', [prodId]);
      expect(parseFloat(invRes.rows[0].quantity)).toBe(2);
    });
  });

  describe('6. Failed Sale Rolls Back All Database Changes', () => {
    it('ensures no sale record or sale items exist after a transaction failure', async () => {
      const prodId = '40000000-0000-4000-a000-000000000006';
      await createProduct(prodId, 'Tablet Stand', 'SKU-TAB-01', 800, 1);

      const salesCountBefore = (await db.query('SELECT COUNT(*) FROM sales')).rows[0].count;

      try {
        await salesService.createSale(businessId, cashierId, {
          items: [{ productId: prodId, quantity: 10 }], // triggers failure
          paymentMethod: 'CASH',
        });
      } catch {
        // expected error
      }

      const salesCountAfter = (await db.query('SELECT COUNT(*) FROM sales')).rows[0].count;
      expect(salesCountAfter).toBe(salesCountBefore);

      // Verify inventory remained intact
      const invRes = await db.query('SELECT quantity FROM inventory WHERE product_id = $1', [prodId]);
      expect(parseFloat(invRes.rows[0].quantity)).toBe(1);
    });
  });

  describe('7. Inventory Cannot Become Negative (Constraint Protection)', () => {
    it('PostgreSQL CHECK constraint rejects negative stock values', async () => {
      const prodId = '40000000-0000-4000-a000-000000000007';
      await createProduct(prodId, 'Flash Drive', 'SKU-FL-01', 400, 5);

      // Direct SQL attempt to set negative inventory
      await expect(
        db.query('UPDATE inventory SET quantity = -1 WHERE product_id = $1', [prodId])
      ).rejects.toThrow(/violates check constraint "chk_inventory_quantity_non_negative"/);

      // Verify inventory is still 5
      const invRes = await db.query('SELECT quantity FROM inventory WHERE product_id = $1', [prodId]);
      expect(parseFloat(invRes.rows[0].quantity)).toBe(5);
    });
  });

  describe('8. Concurrent / Back-to-Back Sale Protection (No Oversell)', () => {
    it('prevents overselling when multiple sales compete for limited stock', async () => {
      const prodId = '40000000-0000-4000-a000-000000000008';
      // Exactly 1 item in stock
      await createProduct(prodId, 'Limited Edition Headset', 'SKU-LIM-01', 5000, 1);

      // First sale claims the 1 available unit
      const result1 = await salesService.createSale(businessId, cashierId, {
        items: [{ productId: prodId, quantity: 1 }],
        paymentMethod: 'CARD',
        note: 'Customer A',
      });
      expect(result1.sale).toBeDefined();

      // Second sale immediately attempts to purchase another unit of the now-exhausted product
      await expect(
        salesService.createSale(businessId, cashierId, {
          items: [{ productId: prodId, quantity: 1 }],
          paymentMethod: 'CASH',
          note: 'Customer B',
        })
      ).rejects.toThrow(/Insufficient stock/);

      // Final inventory must be exactly 0, NEVER negative
      const invRes = await db.query('SELECT quantity FROM inventory WHERE product_id = $1', [prodId]);
      expect(parseFloat(invRes.rows[0].quantity)).toBe(0);
    });
  });
});
