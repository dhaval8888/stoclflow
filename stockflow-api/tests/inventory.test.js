require('dotenv').config({ path: '.env' });
const request = require('supertest');
const app = require('../src/app');
const { pool } = require('../src/config/db');

const OWNER_CREDS   = { email: 'owner@demo.com',   password: 'Owner@123' };
const MANAGER_CREDS = { email: 'manager@demo.com', password: 'Manager@123' };
const CASHIER_CREDS = { email: 'cashier@demo.com', password: 'Cashier@123' };

let ownerToken, managerToken, cashierToken;
let productId; // A product we know exists from seed

beforeAll(async () => {
  const [o, m, c] = await Promise.all([
    request(app).post('/api/v1/auth/login').send(OWNER_CREDS),
    request(app).post('/api/v1/auth/login').send(MANAGER_CREDS),
    request(app).post('/api/v1/auth/login').send(CASHIER_CREDS),
  ]);
  ownerToken   = o.body.data.tokens.accessToken;
  managerToken = m.body.data.tokens.accessToken;
  cashierToken = c.body.data.tokens.accessToken;

  // Get a product ID from the seeded data
  const prodRes = await request(app)
    .get('/api/v1/products?limit=1')
    .set('Authorization', `Bearer ${ownerToken}`);
  productId = prodRes.body.data.products[0]?.id;
});

afterAll(async () => {
  await pool.end();
});

describe('Inventory — Stock List', () => {
  it('OWNER can list all stock', async () => {
    const res = await request(app)
      .get('/api/v1/inventory')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data.inventory)).toBe(true);
    expect(res.body.data.meta).toBeDefined();
  });

  it('MANAGER can list all stock', async () => {
    const res = await request(app)
      .get('/api/v1/inventory')
      .set('Authorization', `Bearer ${managerToken}`);
    expect(res.status).toBe(200);
  });

  it('CASHIER is denied access', async () => {
    const res = await request(app)
      .get('/api/v1/inventory')
      .set('Authorization', `Bearer ${cashierToken}`);
    expect(res.status).toBe(403);
  });

  it('can get stock for a specific product', async () => {
    if (!productId) return;
    const res = await request(app)
      .get(`/api/v1/inventory/${productId}`)
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data.stock).toBeDefined();
    expect(typeof res.body.data.stock.quantity).toBe('string');
  });

  it('returns 404 for unknown product', async () => {
    const res = await request(app)
      .get('/api/v1/inventory/00000000-0000-0000-0000-000000000000')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(res.status).toBe(404);
  });
});

describe('Inventory — Low Stock & Out of Stock', () => {
  it('can fetch low-stock products', async () => {
    const res = await request(app)
      .get('/api/v1/inventory/low-stock')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data.products)).toBe(true);
    expect(typeof res.body.data.count).toBe('number');
  });

  it('can fetch out-of-stock products', async () => {
    const res = await request(app)
      .get('/api/v1/inventory/out-of-stock')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data.products)).toBe(true);
  });
});

describe('Inventory — Stock Transactions', () => {
  it('STOCK_IN increases inventory', async () => {
    if (!productId) return;

    // Get current qty
    const before = await request(app)
      .get(`/api/v1/inventory/${productId}`)
      .set('Authorization', `Bearer ${ownerToken}`);

    const quantityBefore = parseFloat(before.body.data.stock.quantity);

    const res = await request(app)
      .post('/api/v1/inventory/transaction')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ productId, type: 'STOCK_IN', quantity: 10, note: 'Test stock in' });

    expect(res.status).toBe(201);
    expect(res.body.data.transaction.type).toBe('STOCK_IN');

    const after = await request(app)
      .get(`/api/v1/inventory/${productId}`)
      .set('Authorization', `Bearer ${ownerToken}`);

    const quantityAfter = parseFloat(after.body.data.stock.quantity);
    expect(quantityAfter).toBe(quantityBefore + 10);
  });

  it('STOCK_OUT decreases inventory', async () => {
    if (!productId) return;

    const before = await request(app)
      .get(`/api/v1/inventory/${productId}`)
      .set('Authorization', `Bearer ${ownerToken}`);

    const quantityBefore = parseFloat(before.body.data.stock.quantity);

    const res = await request(app)
      .post('/api/v1/inventory/transaction')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ productId, type: 'STOCK_OUT', quantity: 5, note: 'Test stock out' });

    expect(res.status).toBe(201);

    const after = await request(app)
      .get(`/api/v1/inventory/${productId}`)
      .set('Authorization', `Bearer ${ownerToken}`);

    const quantityAfter = parseFloat(after.body.data.stock.quantity);
    expect(quantityAfter).toBe(quantityBefore - 5);
  });

  it('blocks STOCK_OUT that would result in negative stock', async () => {
    if (!productId) return;

    const res = await request(app)
      .post('/api/v1/inventory/transaction')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ productId, type: 'STOCK_OUT', quantity: 99999, note: 'Should fail' });

    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/insufficient/i);
  });

  it('rejects zero quantity', async () => {
    if (!productId) return;
    const res = await request(app)
      .post('/api/v1/inventory/transaction')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ productId, type: 'STOCK_IN', quantity: 0 });
    expect(res.status).toBe(422);
  });

  it('rejects invalid transaction type', async () => {
    if (!productId) return;
    const res = await request(app)
      .post('/api/v1/inventory/transaction')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ productId, type: 'SALE', quantity: 1 }); // SALE is not allowed directly
    expect(res.status).toBe(422);
  });

  it('can list transaction history', async () => {
    const res = await request(app)
      .get('/api/v1/inventory/transactions')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data.transactions)).toBe(true);
  });

  it('can filter transactions by type', async () => {
    const res = await request(app)
      .get('/api/v1/inventory/transactions?type=STOCK_IN')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(res.status).toBe(200);
    const all = res.body.data.transactions;
    if (all.length > 0) {
      expect(all.every((t) => t.type === 'STOCK_IN')).toBe(true);
    }
  });
});
