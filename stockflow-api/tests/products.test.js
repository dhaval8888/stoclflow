require('dotenv').config({ path: '.env' });
const request = require('supertest');
const app = require('../src/app');
const { pool } = require('../src/config/db');

const OWNER_CREDS   = { email: 'owner@demo.com',   password: 'Owner@123' };
const MANAGER_CREDS = { email: 'manager@demo.com', password: 'Manager@123' };
const CASHIER_CREDS = { email: 'cashier@demo.com', password: 'Cashier@123' };

let ownerToken;
let managerToken;
let cashierToken;

beforeAll(async () => {
  const [ownerRes, managerRes, cashierRes] = await Promise.all([
    request(app).post('/api/v1/auth/login').send(OWNER_CREDS),
    request(app).post('/api/v1/auth/login').send(MANAGER_CREDS),
    request(app).post('/api/v1/auth/login').send(CASHIER_CREDS),
  ]);
  ownerToken   = ownerRes.body.data.tokens.accessToken;
  managerToken = managerRes.body.data.tokens.accessToken;
  cashierToken = cashierRes.body.data.tokens.accessToken;
});

afterAll(async () => {
  await pool.end();
});

describe('Products API', () => {
  describe('GET /api/v1/products', () => {
    it('owner can list products', async () => {
      const res = await request(app)
        .get('/api/v1/products')
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data.products)).toBe(true);
      expect(res.body.data.meta).toBeDefined();
    });

    it('cashier can list products', async () => {
      const res = await request(app)
        .get('/api/v1/products')
        .set('Authorization', `Bearer ${cashierToken}`);

      expect(res.status).toBe(200);
    });

    it('supports search filter', async () => {
      const res = await request(app)
        .get('/api/v1/products?search=iPhone')
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);
      const found = res.body.data.products.some((p) =>
        p.name.toLowerCase().includes('iphone')
      );
      expect(found).toBe(true);
    });

    it('supports pagination', async () => {
      const res = await request(app)
        .get('/api/v1/products?page=1&limit=3')
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.products.length).toBeLessThanOrEqual(3);
      expect(res.body.data.meta.limit).toBe(3);
    });
  });

  describe('GET /api/v1/products/barcode/:code', () => {
    it('should return product by barcode', async () => {
      const res = await request(app)
        .get('/api/v1/products/barcode/8901234567890')
        .set('Authorization', `Bearer ${cashierToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.product.barcode).toBe('8901234567890');
    });

    it('should 404 for unknown barcode', async () => {
      const res = await request(app)
        .get('/api/v1/products/barcode/0000000000000')
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(404);
    });
  });

  describe('POST /api/v1/products', () => {
    it('cashier cannot create products', async () => {
      const res = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${cashierToken}`)
        .send({ name: 'Test Product', costPrice: 100, sellingPrice: 200 });

      expect(res.status).toBe(403);
    });

    it('manager can create a product', async () => {
      const res = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          name:         'Test Keyboard',
          sku:          `KBD-TEST-${Date.now()}`,
          costPrice:    500,
          sellingPrice: 999,
          unit:         'pcs',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.product.name).toBe('Test Keyboard');

      // Cleanup
      const productId = res.body.data.product.id;
      await request(app)
        .delete(`/api/v1/products/${productId}`)
        .set('Authorization', `Bearer ${ownerToken}`);
    });

    it('should reject missing required fields', async () => {
      const res = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({ name: 'Missing prices' });

      expect(res.status).toBe(422);
    });
  });
});

describe('Inventory API', () => {
  it('owner can view stock', async () => {
    const res = await request(app)
      .get('/api/v1/inventory')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data.inventory)).toBe(true);
  });

  it('cashier cannot access inventory', async () => {
    const res = await request(app)
      .get('/api/v1/inventory')
      .set('Authorization', `Bearer ${cashierToken}`);

    expect(res.status).toBe(403);
  });

  it('can get low stock products', async () => {
    const res = await request(app)
      .get('/api/v1/inventory/low-stock')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data.products)).toBe(true);
  });
});

describe('Sales API — Atomic Transaction', () => {
  let createdSaleId;

  const getSeedProduct = async (token) => {
    const res = await request(app)
      .get('/api/v1/products/barcode/8901234567895') // Phone Case — high stock
      .set('Authorization', `Bearer ${token}`);
    return res.body.data.product;
  };

  it('cashier can create a sale', async () => {
    const product = await getSeedProduct(cashierToken);

    const res = await request(app)
      .post('/api/v1/sales')
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({
        items: [{ productId: product.id, quantity: 2 }],
        paymentMethod: 'CASH',
      });

    expect(res.status).toBe(201);
    expect(res.body.data.sale.status).toBe('COMPLETED');
    expect(res.body.data.sale.total_amount).toBeGreaterThan(0);
    createdSaleId = res.body.data.sale.id;
  });

  it('sale should reduce stock', async () => {
    const product = await getSeedProduct(ownerToken);
    const stockAfter = parseFloat(product.stock_quantity);
    expect(stockAfter).toBeLessThanOrEqual(120); // Started at 120
  });

  it('should reject sale with zero quantity', async () => {
    const product = await getSeedProduct(cashierToken);

    const res = await request(app)
      .post('/api/v1/sales')
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({
        items: [{ productId: product.id, quantity: 0 }],
        paymentMethod: 'CASH',
      });

    expect(res.status).toBe(422);
  });

  it('owner can void a sale', async () => {
    if (!createdSaleId) return;

    const res = await request(app)
      .post(`/api/v1/sales/${createdSaleId}/void`)
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.sale.status).toBe('VOIDED');
  });

  it('cashier cannot void a sale', async () => {
    if (!createdSaleId) return;

    const res = await request(app)
      .post(`/api/v1/sales/${createdSaleId}/void`)
      .set('Authorization', `Bearer ${cashierToken}`);

    expect(res.status).toBe(403);
  });
});
