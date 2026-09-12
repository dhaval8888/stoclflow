/**
 * Sales Repository
 * All database operations for sales and sale_items.
 * Functions accept a `db` parameter to support PostgreSQL transactions.
 */
const { pool } = require('../../config/db');

const findProductsById = async (productIds, businessId, db = pool) => {
  const { rows } = await db.query(
    `SELECT p.id, p.name, p.selling_price, p.cost_price, p.is_active
     FROM products p
     WHERE p.id = ANY($1::uuid[]) AND p.business_id = $2`,
    [productIds, businessId]
  );
  return rows;
};

const createSale = async ({
  id, businessId, cashierId, status, paymentMethod,
  subtotal, discountAmount, taxAmount, totalAmount, note,
}, db = pool) => {
  const { rows } = await db.query(
    `INSERT INTO sales
       (id, business_id, cashier_id, status, payment_method,
        subtotal, discount_amount, tax_amount, total_amount, note)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
     RETURNING *`,
    [id, businessId, cashierId, status || 'COMPLETED', paymentMethod || 'CASH',
     subtotal, discountAmount || 0, taxAmount || 0, totalAmount, note || null]
  );
  return rows[0];
};

const createSaleItem = async ({
  id, saleId, productId, productName, unitPrice, quantity, discount, lineTotal,
}, db = pool) => {
  const { rows } = await db.query(
    `INSERT INTO sale_items (id, sale_id, product_id, product_name, unit_price, quantity, discount, line_total)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
    [id, saleId, productId, productName, unitPrice, quantity, discount, lineTotal]
  );
  return rows[0];
};

const findAll = async (businessId, {
  cashierId, status, paymentMethod, startDate, endDate,
  limit, offset,
}, db = pool) => {
  const conditions = ['s.business_id = $1'];
  const params = [businessId];
  let idx = 2;

  if (cashierId)     { conditions.push(`s.cashier_id = $${idx++}`);      params.push(cashierId); }
  if (status)        { conditions.push(`s.status = $${idx++}`);           params.push(status.toUpperCase()); }
  if (paymentMethod) { conditions.push(`s.payment_method = $${idx++}`);   params.push(paymentMethod.toUpperCase()); }
  if (startDate)     { conditions.push(`s.created_at >= $${idx++}`);      params.push(startDate); }
  if (endDate)       { conditions.push(`s.created_at <= $${idx++}`);      params.push(endDate); }

  const where = conditions.join(' AND ');

  const [countRes, dataRes] = await Promise.all([
    db.query(`SELECT COUNT(*) FROM sales s WHERE ${where}`, params),
    db.query(
      `SELECT s.*, u.full_name AS cashier_name, COUNT(si.id)::int AS item_count
       FROM sales s
       JOIN users u ON u.id = s.cashier_id
       LEFT JOIN sale_items si ON si.sale_id = s.id
       WHERE ${where}
       GROUP BY s.id, u.full_name
       ORDER BY s.created_at DESC
       LIMIT $${idx} OFFSET $${idx + 1}`,
      [...params, limit, offset]
    ),
  ]);

  return { rows: dataRes.rows, total: parseInt(countRes.rows[0].count, 10) };
};

const findById = async (businessId, saleId, db = pool) => {
  const { rows } = await db.query(
    `SELECT s.*, u.full_name AS cashier_name
     FROM sales s JOIN users u ON u.id = s.cashier_id
     WHERE s.id = $1 AND s.business_id = $2`,
    [saleId, businessId]
  );
  return rows[0] || null;
};

/**
 * Lock sale row for void operation — must be inside a transaction.
 */
const findByIdForUpdate = async (businessId, saleId, db) => {
  const { rows } = await db.query(
    'SELECT * FROM sales WHERE id = $1 AND business_id = $2 FOR UPDATE',
    [saleId, businessId]
  );
  return rows[0] || null;
};

const findItems = async (saleId, db = pool) => {
  const { rows } = await db.query(
    `SELECT si.*, p.cost_price
     FROM sale_items si
     LEFT JOIN products p ON p.id = si.product_id
     WHERE si.sale_id = $1
     ORDER BY si.product_name`,
    [saleId]
  );
  return rows;
};

const updateStatus = async (saleId, status, db = pool) => {
  const { rows } = await db.query(
    `UPDATE sales SET status = $2 WHERE id = $1 RETURNING *`,
    [saleId, status]
  );
  return rows[0];
};

const findReceiptData = async (businessId, saleId, db = pool) => {
  const saleRes = await db.query(
    `SELECT s.id, s.status, s.payment_method, s.subtotal, s.discount_amount,
            s.tax_amount, s.total_amount, s.note, s.created_at,
            u.full_name AS cashier_name,
            b.name AS business_name, b.address AS business_address,
            b.phone AS business_phone, b.currency
     FROM sales s
     JOIN users u ON u.id = s.cashier_id
     JOIN businesses b ON b.id = s.business_id
     WHERE s.id = $1 AND s.business_id = $2`,
    [saleId, businessId]
  );
  if (!saleRes.rows.length) return null;

  const itemsRes = await db.query(
    `SELECT product_name, unit_price, quantity, discount, line_total
     FROM sale_items WHERE sale_id = $1 ORDER BY product_name`,
    [saleId]
  );

  return { sale: saleRes.rows[0], items: itemsRes.rows };
};

module.exports = {
  findProductsById, createSale, createSaleItem,
  findAll, findById, findByIdForUpdate, findItems,
  updateStatus, findReceiptData,
};
