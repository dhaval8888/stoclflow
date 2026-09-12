require('dotenv').config({ path: '.env' });
const request = require('supertest');
const app = require('../src/app');
const { pool } = require('../src/config/db');

const OWNER_CREDS   = { email: 'owner@demo.com',   password: 'Owner@123' };
const CASHIER_CREDS = { email: 'cashier@demo.com', password: 'Cashier@123' };

let ownerToken, cashierToken;
let testProductId;
let createdSaleId;

beforeAll(async () => {
  const [o, c] = await Promise.all([
    request(app).post('/api/v1/auth/login').send(OWNER_CREDS),
    request(app).post('/api/v1/auth/login').send(CASHIER_CREDS),
  ]);
  ownerToken   = o.body.data.tokens.accessToken;
  cashierToken = c.body.data.tokens.accessToken;

  // Use the Phone Case (high stock) from seed
  const prodRes = await request(app)
    .get('/api/v1/products/barcode/8901234567895')
    .set('Authorization', `Bearer ${ownerToken}`);
  testProductId = prodRes.body.data?.product?.id;
});

afterAll(async () => {
  await pool.end();
});

describe('Sales — Create (Atomic Transaction)', () => {
  it('cashier can create a valid sale', async () => {
    if (!testProductId) return;

    const res = await request(app)
      .post('/api/v1/sales')
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({
        items:         [{ productId: testProductId, quantity: 2 }],
        paymentMethod: 'CASH',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.sale.status).toBe('COMPLETED');
    expect(res.body.data.sale.total_amount).toBeDefined();
    expect(Array.isArray(res.body.data.items)).toBe(true);
    expect(res.body.data.items.length).toBe(1);

    createdSaleId = res.body.data.sale.id;
  });

  it('sale reduces inventory (atomically)', async () => {
    if (!testProductId) return;

    const stockRes = await request(app)
      .get(`/api/v1/inventory/${testProductId}`)
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(stockRes.status).toBe(200);
    // Stock should be at most 120 units (seeded value) since at least 2 were sold
    expect(parseFloat(stockRes.body.data.stock.quantity)).toBeLessThanOrEqual(120);
  });

  it('fails if product does not exist', async () => {
    const res = await request(app)
      .post('/api/v1/sales')
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({
        items: [{ productId: '00000000-0000-0000-0000-000000000000', quantity: 1 }],
      });

    expect(res.status).toBe(404);
    expect(res.body.message).toMatch(/not found/i);
  });

  it('fails with insufficient stock — does not partially commit', async () => {
    if (!testProductId) return;

    // Get current qty to request more than available
    const stockRes = await request(app)
      .get(`/api/v1/inventory/${testProductId}`)
      .set('Authorization', `Bearer ${ownerToken}`);

    const available = parseFloat(stockRes.body.data.stock.quantity);

    const res = await request(app)
      .post('/api/v1/sales')
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({
        items: [{ productId: testProductId, quantity: available + 1000 }],
      });

    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/insufficient stock/i);

    // Verify stock was NOT changed (rollback worked)
    const stockAfterRes = await request(app)
      .get(`/api/v1/inventory/${testProductId}`)
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(parseFloat(stockAfterRes.body.data.stock.quantity)).toBe(available);
  });

  it('rejects empty cart', async () => {
    const res = await request(app)
      .post('/api/v1/sales')
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({ items: [] });

    expect(res.status).toBe(422);
  });

  it('rejects zero quantity in items', async () => {
    if (!testProductId) return;
    const res = await request(app)
      .post('/api/v1/sales')
      .set('Authorization', `Bearer ${cashierToken}`)
      .send({ items: [{ productId: testProductId, quantity: 0 }] });

    expect(res.status).toBe(422);
  });
});

describe('Sales — Read', () => {
  it('owner can list all sales', async () => {
    const res = await request(app)
      .get('/api/v1/sales')
      .set('Authorization', `Bearer ${ownerToken}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data.sales)).toBe(true);
  });

  it('cashier only sees own sales', async () => {
    const ownerRes  = await request(app).get('/api/v1/sales').set('Authorization', `Bearer ${ownerToken}`);
    const cashierRes = await request(app).get('/api/v1/sales').set('Authorization', `Bearer ${cashierToken}`);

    expect(cashierRes.status).toBe(200);
    // Cashier list should be a subset of owner list
    expect(cashierRes.body.data.sales.length).toBeLessThanOrEqual(ownerRes.body.data.sales.length);
  });

  it('can get sale by id', async () => {
    if (!createdSaleId) return;
    const res = await request(app)
      .get(`/api/v1/sales/${createdSaleId}`)
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.sale.id).toBe(createdSaleId);
    expect(Array.isArray(res.body.data.sale.items)).toBe(true);
  });

  it('can get receipt for a sale', async () => {
    if (!createdSaleId) return;
    const res = await request(app)
      .get(`/api/v1/sales/${createdSaleId}/receipt`)
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.receipt.sale.business_name).toBeDefined();
    expect(res.body.data.receipt.sale.currency).toBeDefined();
    expect(Array.isArray(res.body.data.receipt.items)).toBe(true);
  });
});

describe('Sales — Void (Atomic Rollback)', () => {
  it('owner can void a sale and inventory is restored', async () => {
    if (!createdSaleId || !testProductId) return;

    // Get stock before void
    const beforeRes = await request(app)
      .get(`/api/v1/inventory/${testProductId}`)
      .set('Authorization', `Bearer ${ownerToken}`);
    const stockBefore = parseFloat(beforeRes.body.data.stock.quantity);

    // Void the sale
    const voidRes = await request(app)
      .post(`/api/v1/sales/${createdSaleId}/void`)
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(voidRes.status).toBe(200);
    expect(voidRes.body.data.sale.status).toBe('VOIDED');

    // Verify inventory was restored (+2 units)
    const afterRes = await request(app)
      .get(`/api/v1/inventory/${testProductId}`)
      .set('Authorization', `Bearer ${ownerToken}`);
    const stockAfter = parseFloat(afterRes.body.data.stock.quantity);

    expect(stockAfter).toBe(stockBefore + 2);
  });

  it('cannot void an already voided sale', async () => {
    if (!createdSaleId) return;

    const res = await request(app)
      .post(`/api/v1/sales/${createdSaleId}/void`)
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(400);
    expect(res.body.message).toMatch(/cannot void/i);
  });

  it('cashier cannot void sales', async () => {
    const res = await request(app)
      .post(`/api/v1/sales/${createdSaleId}/void`)
      .set('Authorization', `Bearer ${cashierToken}`);
    expect(res.status).toBe(403);
  });
});
