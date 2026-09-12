/**
 * Development seed script.
 * Creates a demo business, owner, manager, cashier, categories, products,
 * and initial inventory. Safe to run multiple times (uses upserts where possible).
 *
 * Usage: node src/db/seed.js
 */
require('dotenv').config();
const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../config/db');

const SALT_ROUNDS = 10;

async function seed() {
  console.log('🌱  Seeding database...\n');
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // ─── Roles ────────────────────────────────────────────────────────────
    await client.query(`
      INSERT INTO roles (id, name) VALUES
        (1, 'OWNER'), (2, 'MANAGER'), (3, 'CASHIER')
      ON CONFLICT (id) DO NOTHING
    `);
    console.log('  ✅  Roles seeded');

    // ─── Business ─────────────────────────────────────────────────────────
    const businessId = 'b1000000-0000-4000-a000-000000000001';
    await client.query(`
      INSERT INTO businesses (id, name, address, phone, email, currency, timezone)
      VALUES ($1, 'Demo Electronics', '42 Market Street, Ahmedabad, Gujarat', '+91-9876543210',
              'admin@demoelectronics.com', 'INR', 'Asia/Kolkata')
      ON CONFLICT (id) DO NOTHING
    `, [businessId]);
    console.log('  ✅  Business seeded');

    // ─── Users ────────────────────────────────────────────────────────────
    const ownerHash   = await bcrypt.hash('Owner@123',   SALT_ROUNDS);
    const managerHash = await bcrypt.hash('Manager@123', SALT_ROUNDS);
    const cashierHash = await bcrypt.hash('Cashier@123', SALT_ROUNDS);

    const ownerId   = 'a1000000-0000-4000-a000-000000000001';
    const managerId = 'a1000000-0000-4000-a000-000000000002';
    const cashierId = 'a1000000-0000-4000-a000-000000000003';

    await client.query(`
      INSERT INTO users (id, business_id, role_id, full_name, email, password_hash) VALUES
        ($1, $4, 1, 'Arjun Mehta',   'owner@demo.com',   $5),
        ($2, $4, 2, 'Priya Sharma',  'manager@demo.com', $6),
        ($3, $4, 3, 'Rohit Patel',   'cashier@demo.com', $7)
      ON CONFLICT (email) DO NOTHING
    `, [ownerId, managerId, cashierId, businessId, ownerHash, managerHash, cashierHash]);
    console.log('  ✅  Users seeded');
    console.log('     📋  owner@demo.com    / Owner@123   (OWNER)');
    console.log('     📋  manager@demo.com  / Manager@123 (MANAGER)');
    console.log('     📋  cashier@demo.com  / Cashier@123 (CASHIER)');

    // ─── Categories ───────────────────────────────────────────────────────
    const cats = [
      ['c1000000-0000-4000-a000-000000000001', businessId, 'Smartphones',    '#3D5A99'],
      ['c1000000-0000-4000-a000-000000000002', businessId, 'Laptops',         '#2E7D32'],
      ['c1000000-0000-4000-a000-000000000003', businessId, 'Accessories',     '#E65100'],
      ['c1000000-0000-4000-a000-000000000004', businessId, 'Audio',           '#7B1FA2'],
      ['c1000000-0000-4000-a000-000000000005', businessId, 'Tablets',         '#00838F'],
    ];
    for (const [id, bid, name, color] of cats) {
      await client.query(`
        INSERT INTO categories (id, business_id, name, color_hex)
        VALUES ($1, $2, $3, $4) ON CONFLICT DO NOTHING
      `, [id, bid, name, color]);
    }
    console.log('  ✅  Categories seeded');

    // ─── Products ─────────────────────────────────────────────────────────
    const products = [
      {
        id: 'd1000000-0000-4000-a000-000000000001', catId: cats[0][0],
        name: 'iPhone 15 Pro',        sku: 'IPH-15P-256', barcode: '8901234567890',
        cost: 95000, price: 129900, unit: 'pcs', threshold: 5,
      },
      {
        id: 'd1000000-0000-4000-a000-000000000002', catId: cats[0][0],
        name: 'Samsung Galaxy S24',   sku: 'SAM-S24-128',  barcode: '8901234567891',
        cost: 65000, price: 79999, unit: 'pcs', threshold: 5,
      },
      {
        id: 'd1000000-0000-4000-a000-000000000003', catId: cats[1][0],
        name: 'MacBook Air M3',       sku: 'MBA-M3-512',   barcode: '8901234567892',
        cost: 90000, price: 119900, unit: 'pcs', threshold: 3,
      },
      {
        id: 'd1000000-0000-4000-a000-000000000004', catId: cats[1][0],
        name: 'Dell XPS 15',          sku: 'DLL-XPS-15',   barcode: '8901234567893',
        cost: 85000, price: 109999, unit: 'pcs', threshold: 3,
      },
      {
        id: 'd1000000-0000-4000-a000-000000000005', catId: cats[2][0],
        name: 'USB-C Hub 7-in-1',     sku: 'ACC-USBC-H7',  barcode: '8901234567894',
        cost: 1200, price: 2499, unit: 'pcs', threshold: 20,
      },
      {
        id: 'd1000000-0000-4000-a000-000000000006', catId: cats[2][0],
        name: 'Phone Case - Universal', sku: 'ACC-CASE-UNI', barcode: '8901234567895',
        cost: 150, price: 399, unit: 'pcs', threshold: 50,
      },
      {
        id: 'd1000000-0000-4000-a000-000000000007', catId: cats[3][0],
        name: 'Sony WH-1000XM5',      sku: 'AUD-SONY-XM5', barcode: '8901234567896',
        cost: 22000, price: 29999, unit: 'pcs', threshold: 8,
      },
      {
        id: 'd1000000-0000-4000-a000-000000000008', catId: cats[3][0],
        name: 'AirPods Pro 2nd Gen',  sku: 'AUD-APR-2G',   barcode: '8901234567897',
        cost: 18000, price: 24900, unit: 'pcs', threshold: 8,
      },
      {
        id: 'd1000000-0000-4000-a000-000000000009', catId: cats[4][0],
        name: 'iPad Air 5th Gen',     sku: 'TAB-IPAD-A5',  barcode: '8901234567898',
        cost: 48000, price: 59900, unit: 'pcs', threshold: 4,
      },
      {
        id: 'd1000000-0000-4000-a000-000000000010', catId: cats[2][0],
        name: 'Screen Protector Glass', sku: 'ACC-SPG-UNI', barcode: '8901234567899',
        cost: 100, price: 299, unit: 'pcs', threshold: 100,
      },
    ];

    for (const p of products) {
      await client.query(`
        INSERT INTO products
          (id, business_id, category_id, name, sku, barcode, unit, cost_price, selling_price, low_stock_threshold)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
        ON CONFLICT DO NOTHING
      `, [p.id, businessId, p.catId, p.name, p.sku, p.barcode, p.unit, p.cost, p.price, p.threshold]);
    }
    console.log(`  ✅  ${products.length} Products seeded`);

    // ─── Inventory ────────────────────────────────────────────────────────
    const stockQtys = [12, 8, 5, 4, 45, 120, 15, 18, 7, 200];
    for (let i = 0; i < products.length; i++) {
      const p = products[i];
      const qty = stockQtys[i];

      await client.query(`
        INSERT INTO inventory (product_id, business_id, quantity)
        VALUES ($1, $2, $3)
        ON CONFLICT (product_id) DO UPDATE SET quantity = EXCLUDED.quantity
      `, [p.id, businessId, qty]);

      // Seed inventory transaction for initial stock
      await client.query(`
        INSERT INTO inventory_transactions
          (id, business_id, product_id, user_id, type, quantity, quantity_before, quantity_after, note)
        VALUES ($1, $2, $3, $4, 'STOCK_IN', $5, 0, $5, 'Initial stock — seeded')
        ON CONFLICT DO NOTHING
      `, [uuidv4(), businessId, p.id, ownerId, qty]);
    }
    console.log('  ✅  Inventory seeded');

    await client.query('COMMIT');
    console.log('\n  🎉  Seed complete!\n');

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('❌  Seed failed:', err.message);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

seed().catch((err) => {
  console.error(err);
  process.exit(1);
});
