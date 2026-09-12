/**
 * Inventory Repository
 * All database operations for inventory and inventory_transactions.
 */
const { pool } = require('../../config/db');

const findAllStock = async (businessId, { search, limit, offset }, db = pool) => {
  const conditions = ['p.business_id = $1', 'p.is_active = TRUE'];
  const params = [businessId];
  let idx = 2;

  if (search) {
    conditions.push(`(p.name ILIKE $${idx} OR p.sku ILIKE $${idx})`);
    params.push(`%${search}%`); idx++;
  }

  const where = conditions.join(' AND ');

  const [countRes, dataRes] = await Promise.all([
    db.query(
      `SELECT COUNT(*) FROM products p LEFT JOIN inventory inv ON inv.product_id = p.id
       LEFT JOIN categories c ON c.id = p.category_id WHERE ${where}`,
      params
    ),
    db.query(
      `SELECT p.id, p.id AS product_id, p.name, p.sku, p.barcode, p.unit, p.selling_price, p.cost_price,
              p.low_stock_threshold, c.name AS category_name,
              COALESCE(inv.quantity, 0)::FLOAT AS quantity,
              COALESCE(inv.quantity, 0)::FLOAT AS current_quantity,
              inv.id AS inventory_id,
              inv.last_updated,
              CASE WHEN COALESCE(inv.quantity,0) = 0 THEN 'OUT_OF_STOCK'
                   WHEN COALESCE(inv.quantity,0) <= p.low_stock_threshold THEN 'LOW_STOCK'
                   ELSE 'IN_STOCK' END AS stock_status
       FROM products p
       LEFT JOIN inventory inv ON inv.product_id = p.id
       LEFT JOIN categories c ON c.id = p.category_id
       WHERE ${where}
       ORDER BY p.name ASC
       LIMIT $${idx} OFFSET $${idx + 1}`,
      [...params, limit, offset]
    ),
  ]);

  return { rows: dataRes.rows, total: parseInt(countRes.rows[0].count, 10) };
};

const findStockByProduct = async (businessId, productId, db = pool) => {
  const { rows } = await db.query(
    `SELECT p.id, p.id AS product_id, p.name, p.sku, p.unit, p.low_stock_threshold,
            COALESCE(inv.quantity, 0)::FLOAT AS quantity,
            COALESCE(inv.quantity, 0)::FLOAT AS current_quantity,
            inv.last_updated
     FROM products p LEFT JOIN inventory inv ON inv.product_id = p.id
     WHERE p.id = $1 AND p.business_id = $2`,
    [productId, businessId]
  );
  return rows[0] || null;
};

const findLowStock = async (businessId, db = pool) => {
  const { rows } = await db.query(
    `SELECT p.id, p.id AS product_id, p.name, p.sku, p.unit, p.low_stock_threshold,
            c.name AS category_name,
            COALESCE(inv.quantity, 0)::FLOAT AS quantity,
            COALESCE(inv.quantity, 0)::FLOAT AS current_quantity
     FROM products p
     LEFT JOIN inventory inv ON inv.product_id = p.id
     LEFT JOIN categories c ON c.id = p.category_id
     WHERE p.business_id = $1 AND p.is_active = TRUE
       AND COALESCE(inv.quantity, 0) > 0
       AND COALESCE(inv.quantity, 0) <= p.low_stock_threshold
     ORDER BY COALESCE(inv.quantity, 0) ASC`,
    [businessId]
  );
  return rows;
};

const findOutOfStock = async (businessId, db = pool) => {
  const { rows } = await db.query(
    `SELECT p.id, p.id AS product_id, p.name, p.sku, p.unit, p.low_stock_threshold,
            c.name AS category_name,
            COALESCE(inv.quantity, 0)::FLOAT AS quantity,
            COALESCE(inv.quantity, 0)::FLOAT AS current_quantity,
            inv.last_updated
     FROM products p
     LEFT JOIN inventory inv ON inv.product_id = p.id
     LEFT JOIN categories c ON c.id = p.category_id
     WHERE p.business_id = $1 AND p.is_active = TRUE
       AND COALESCE(inv.quantity, 0) = 0
     ORDER BY p.name ASC`,
    [businessId]
  );
  return rows;
};

/**
 * Lock inventory row for transaction — prevents race conditions.
 * Must be called inside a transaction with a client.
 */
const lockForUpdate = async (productId, businessId, db) => {
  const { rows } = await db.query(
    'SELECT quantity FROM inventory WHERE product_id = $1 AND business_id = $2 FOR UPDATE',
    [productId, businessId]
  );
  return rows[0] ? parseFloat(rows[0].quantity) : null;
};

const lockMultipleForUpdate = async (productIds, businessId, db) => {
  const { rows } = await db.query(
    `SELECT product_id, quantity
     FROM inventory
     WHERE product_id = ANY($1::uuid[]) AND business_id = $2
     FOR UPDATE`,
    [productIds, businessId]
  );
  return Object.fromEntries(rows.map((r) => [r.product_id, parseFloat(r.quantity)]));
};

const updateQuantity = async (productId, newQuantity, businessId = null, db = pool) => {
  let client = db;
  let bId = businessId;
  if (typeof businessId === 'object' && businessId !== null) {
    client = businessId;
    bId = null;
  }

  if (bId) {
    await client.query(
      'UPDATE inventory SET quantity = $1, last_updated = NOW() WHERE product_id = $2 AND business_id = $3',
      [newQuantity, productId, bId]
    );
  } else {
    await client.query(
      'UPDATE inventory SET quantity = $1, last_updated = NOW() WHERE product_id = $2',
      [newQuantity, productId]
    );
  }
};

const createTransaction = async ({
  id, businessId, productId, userId, type, quantity,
  quantityBefore, quantityAfter, referenceId, note,
}, db = pool) => {
  const { rows } = await db.query(
    `INSERT INTO inventory_transactions
       (id, business_id, product_id, user_id, type, quantity,
        quantity_before, quantity_after, reference_id, note)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
     RETURNING *`,
    [id, businessId, productId, userId, type, quantity,
     quantityBefore, quantityAfter, referenceId || null, note || null]
  );
  return rows[0];
};

const findTransactions = async (businessId, { productId, type, startDate, endDate, limit, offset }, db = pool) => {
  const conditions = ['it.business_id = $1'];
  const params = [businessId];
  let idx = 2;

  if (productId) { conditions.push(`it.product_id = $${idx++}`); params.push(productId); }
  if (type)      { conditions.push(`it.type = $${idx++}`);        params.push(type.toUpperCase()); }
  if (startDate) { conditions.push(`it.created_at >= $${idx++}`); params.push(startDate); }
  if (endDate)   { conditions.push(`it.created_at <= $${idx++}`); params.push(endDate); }

  const where = conditions.join(' AND ');

  const [countRes, dataRes] = await Promise.all([
    db.query(`SELECT COUNT(*) FROM inventory_transactions it WHERE ${where}`, params),
    db.query(
      `SELECT it.id, it.business_id, it.product_id, it.user_id, it.type,
              it.quantity::FLOAT AS quantity,
              it.quantity_before::FLOAT AS quantity_before,
              it.quantity_after::FLOAT AS quantity_after,
              it.reference_id, it.note, it.created_at,
              p.name AS product_name, p.sku, p.unit, u.full_name AS user_name
       FROM inventory_transactions it
       JOIN products p ON p.id = it.product_id
       JOIN users u ON u.id = it.user_id
       WHERE ${where}
       ORDER BY it.created_at DESC
       LIMIT $${idx} OFFSET $${idx + 1}`,
      [...params, limit, offset]
    ),
  ]);

  return { rows: dataRes.rows, total: parseInt(countRes.rows[0].count, 10) };
};

module.exports = {
  findAllStock, findStockByProduct, findLowStock, findOutOfStock,
  lockForUpdate, lockMultipleForUpdate, updateQuantity,
  createTransaction, findTransactions,
};
