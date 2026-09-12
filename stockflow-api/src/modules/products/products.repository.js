/**
 * Products Repository
 * All database operations for products and product_images.
 */
const { pool } = require('../../config/db');

// Reusable SELECT fragment — stock status computed in SQL
const PRODUCT_SELECT = `
  p.id, p.business_id, p.category_id, p.name, p.description, p.sku, p.barcode,
  p.unit, p.cost_price, p.selling_price, p.low_stock_threshold, p.is_active,
  p.created_at, p.updated_at,
  c.name AS category_name, c.color_hex AS category_color,
  COALESCE(inv.quantity, 0)::FLOAT AS stock_quantity,
  COALESCE(inv.quantity, 0)::FLOAT AS current_quantity,
  CASE
    WHEN COALESCE(inv.quantity, 0) = 0 THEN 'OUT_OF_STOCK'
    WHEN COALESCE(inv.quantity, 0) <= p.low_stock_threshold THEN 'LOW_STOCK'
    ELSE 'IN_STOCK'
  END AS stock_status
`;

const PRODUCT_JOINS = `
  FROM products p
  LEFT JOIN categories c ON c.id = p.category_id
  LEFT JOIN inventory inv ON inv.product_id = p.id
`;

/**
 * Build WHERE clause and params from filter options.
 */
const buildFilters = (businessId, { search, categoryId, stockStatus, isActive = 'true' }) => {
  const conditions = ['p.business_id = $1'];
  const params = [businessId];
  let idx = 2;

  if (isActive !== 'all') {
    conditions.push(`p.is_active = $${idx++}`);
    params.push(isActive !== 'false');
  }
  if (categoryId) { conditions.push(`p.category_id = $${idx++}`); params.push(categoryId); }
  if (search) {
    conditions.push(`(p.name ILIKE $${idx} OR p.sku ILIKE $${idx} OR p.barcode ILIKE $${idx})`);
    params.push(`%${search}%`); idx++;
  }

  const stockHaving = {
    LOW_STOCK:    `HAVING COALESCE(inv.quantity,0) > 0 AND COALESCE(inv.quantity,0) <= p.low_stock_threshold`,
    OUT_OF_STOCK: `HAVING COALESCE(inv.quantity,0) = 0`,
    IN_STOCK:     `HAVING COALESCE(inv.quantity,0) > p.low_stock_threshold`,
  };

  return {
    where:  conditions.join(' AND '),
    having: stockHaving[stockStatus] || '',
    params,
    nextIdx: idx,
  };
};

const count = async (businessId, filters, db = pool) => {
  const { where, having, params } = buildFilters(businessId, filters);
  const { rows } = await db.query(
    `SELECT COUNT(*) FROM (
       SELECT p.id ${PRODUCT_JOINS} WHERE ${where}
       GROUP BY p.id, c.id, inv.quantity ${having}
     ) sub`,
    params
  );
  return parseInt(rows[0].count, 10);
};

const findAll = async (businessId, filters, limit, offset, db = pool) => {
  const { where, having, params, nextIdx } = buildFilters(businessId, filters);
  const { rows } = await db.query(
    `SELECT ${PRODUCT_SELECT} ${PRODUCT_JOINS}
     WHERE ${where}
     GROUP BY p.id, c.id, inv.quantity ${having}
     ORDER BY p.name ASC
     LIMIT $${nextIdx} OFFSET $${nextIdx + 1}`,
    [...params, limit, offset]
  );
  return rows;
};

const findById = async (businessId, productId, db = pool) => {
  const { rows } = await db.query(
    `SELECT ${PRODUCT_SELECT} ${PRODUCT_JOINS}
     WHERE p.id = $1 AND p.business_id = $2
     GROUP BY p.id, c.id, inv.quantity`,
    [productId, businessId]
  );
  return rows[0] || null;
};

const findByBarcode = async (businessId, barcode, db = pool) => {
  const { rows } = await db.query(
    `SELECT ${PRODUCT_SELECT} ${PRODUCT_JOINS}
     WHERE p.barcode = $1 AND p.business_id = $2 AND p.is_active = TRUE
     GROUP BY p.id, c.id, inv.quantity`,
    [barcode, businessId]
  );
  return rows[0] || null;
};

const findBySku = async (businessId, sku, db = pool) => {
  const { rows } = await db.query(
    `SELECT ${PRODUCT_SELECT} ${PRODUCT_JOINS}
     WHERE p.sku = $1 AND p.business_id = $2
     GROUP BY p.id, c.id, inv.quantity`,
    [sku, businessId]
  );
  return rows[0] || null;
};

// Used for active stock check inside sales transaction
const findByIdForUpdate = async (productId, businessId, db = pool) => {
  const { rows } = await db.query(
    `SELECT p.id, p.name, p.selling_price, p.cost_price, p.is_active
     FROM products p WHERE p.id = $1 AND p.business_id = $2`,
    [productId, businessId]
  );
  return rows[0] || null;
};

const skuExists = async (businessId, sku, excludeId = null, db = pool) => {
  const q = excludeId
    ? 'SELECT id FROM products WHERE business_id=$1 AND sku=$2 AND id!=$3'
    : 'SELECT id FROM products WHERE business_id=$1 AND sku=$2';
  const p = excludeId ? [businessId, sku, excludeId] : [businessId, sku];
  const { rows } = await db.query(q, p);
  return rows.length > 0;
};

const barcodeExists = async (businessId, barcode, excludeId = null, db = pool) => {
  const q = excludeId
    ? 'SELECT id FROM products WHERE business_id=$1 AND barcode=$2 AND id!=$3'
    : 'SELECT id FROM products WHERE business_id=$1 AND barcode=$2';
  const p = excludeId ? [businessId, barcode, excludeId] : [businessId, barcode];
  const { rows } = await db.query(q, p);
  return rows.length > 0;
};

const create = async ({
  id, businessId, categoryId, name, description, sku, barcode,
  unit, costPrice, sellingPrice, lowStockThreshold,
}, db = pool) => {
  const { rows } = await db.query(
    `INSERT INTO products
       (id, business_id, category_id, name, description, sku, barcode,
        unit, cost_price, selling_price, low_stock_threshold)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
     RETURNING *`,
    [id, businessId, categoryId || null, name.trim(), description || null,
     sku || null, barcode || null, unit || 'pcs', costPrice, sellingPrice,
     lowStockThreshold || 10]
  );
  return rows[0];
};

const createInventoryRow = async (productId, businessId, initialQuantity = 0, db = pool) => {
  await db.query(
    'INSERT INTO inventory (product_id, business_id, quantity) VALUES ($1, $2, $3)',
    [productId, businessId, initialQuantity]
  );
};

const update = async (productId, businessId, fields, db = pool) => {
  const allowed = {
    name: 'name', description: 'description', categoryId: 'category_id',
    sku: 'sku', barcode: 'barcode', unit: 'unit',
    costPrice: 'cost_price', sellingPrice: 'selling_price',
    lowStockThreshold: 'low_stock_threshold',
  };

  const setClauses = [];
  const params = [productId, businessId];
  let idx = 3;

  for (const [key, col] of Object.entries(allowed)) {
    if (fields[key] !== undefined) {
      setClauses.push(`${col} = $${idx++}`);
      params.push(fields[key]);
    }
  }

  if (!setClauses.length) return null;
  setClauses.push('updated_at = NOW()');

  const { rows } = await db.query(
    `UPDATE products SET ${setClauses.join(', ')}
     WHERE id = $1 AND business_id = $2 RETURNING *`,
    params
  );
  return rows[0] || null;
};

const softDelete = async (productId, businessId, db = pool) => {
  const { rows } = await db.query(
    `UPDATE products SET is_active = FALSE, updated_at = NOW()
     WHERE id = $1 AND business_id = $2 RETURNING id, name`,
    [productId, businessId]
  );
  return rows[0] || null;
};

// ─── Images ──────────────────────────────────────────────────────────────────

const findImages = async (productId, db = pool) => {
  const { rows } = await db.query(
    'SELECT id, cloudinary_id, url, is_primary, created_at FROM product_images WHERE product_id = $1 ORDER BY is_primary DESC, created_at ASC',
    [productId]
  );
  return rows;
};

const findImagesByProductIds = async (productIds, db = pool) => {
  const { rows } = await db.query(
    `SELECT pi.product_id, pi.id, pi.cloudinary_id, pi.url, pi.is_primary
     FROM product_images pi WHERE pi.product_id = ANY($1::uuid[])`,
    [productIds]
  );
  return rows;
};

const hasPrimaryImage = async (productId, db = pool) => {
  const { rows } = await db.query(
    'SELECT id FROM product_images WHERE product_id = $1 AND is_primary = TRUE',
    [productId]
  );
  return rows.length > 0;
};

const createImage = async ({ id, productId, cloudinaryId, url, isPrimary }, db = pool) => {
  const { rows } = await db.query(
    'INSERT INTO product_images (id, product_id, cloudinary_id, url, is_primary) VALUES ($1,$2,$3,$4,$5) RETURNING *',
    [id, productId, cloudinaryId, url, isPrimary]
  );
  return rows[0];
};

const findImageById = async (imageId, productId, businessId, db = pool) => {
  const { rows } = await db.query(
    `SELECT pi.id, pi.cloudinary_id, pi.is_primary
     FROM product_images pi
     JOIN products p ON p.id = pi.product_id
     WHERE pi.id = $1 AND pi.product_id = $2 AND p.business_id = $3`,
    [imageId, productId, businessId]
  );
  return rows[0] || null;
};

const deleteImage = async (imageId, db = pool) => {
  await db.query('DELETE FROM product_images WHERE id = $1', [imageId]);
};

const promotePrimaryImage = async (productId, db = pool) => {
  await db.query(
    `UPDATE product_images SET is_primary = TRUE
     WHERE id = (
       SELECT id FROM product_images WHERE product_id = $1
       ORDER BY created_at ASC LIMIT 1
     )`,
    [productId]
  );
};

module.exports = {
  findAll, count, findById, findByBarcode, findBySku, findByIdForUpdate,
  skuExists, barcodeExists,
  create, createInventoryRow, update, softDelete,
  findImages, findImagesByProductIds, hasPrimaryImage,
  createImage, findImageById, deleteImage, promotePrimaryImage,
};
