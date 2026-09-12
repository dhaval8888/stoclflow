/**
 * Categories Repository
 */
const { pool } = require('../../config/db');

const findAll = async (businessId, db = pool) => {
  const { rows } = await db.query(
    `SELECT c.id, c.name, c.description, c.color_hex, c.created_at,
            COUNT(p.id)::int AS product_count
     FROM categories c
     LEFT JOIN products p ON p.category_id = c.id AND p.is_active = TRUE
     WHERE c.business_id = $1
     GROUP BY c.id
     ORDER BY c.name`,
    [businessId]
  );
  return rows;
};

const findById = async (businessId, categoryId, db = pool) => {
  const { rows } = await db.query(
    'SELECT * FROM categories WHERE id = $1 AND business_id = $2',
    [categoryId, businessId]
  );
  return rows[0] || null;
};

const nameExists = async (businessId, name, excludeId = null, db = pool) => {
  const query = excludeId
    ? 'SELECT id FROM categories WHERE business_id = $1 AND LOWER(name) = LOWER($2) AND id != $3'
    : 'SELECT id FROM categories WHERE business_id = $1 AND LOWER(name) = LOWER($2)';
  const params = excludeId ? [businessId, name, excludeId] : [businessId, name];
  const { rows } = await db.query(query, params);
  return rows.length > 0;
};

const create = async ({ id, businessId, name, description, colorHex }, db = pool) => {
  const { rows } = await db.query(
    `INSERT INTO categories (id, business_id, name, description, color_hex)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [id, businessId, name.trim(), description || null, colorHex || null]
  );
  return rows[0];
};

const update = async (businessId, categoryId, { name, description, colorHex }, db = pool) => {
  const { rows } = await db.query(
    `UPDATE categories
     SET name        = COALESCE($3, name),
         description = COALESCE($4, description),
         color_hex   = COALESCE($5, color_hex)
     WHERE id = $1 AND business_id = $2
     RETURNING *`,
    [categoryId, businessId, name ?? null, description ?? null, colorHex ?? null]
  );
  return rows[0] || null;
};

const remove = async (businessId, categoryId, db = pool) => {
  const { rows } = await db.query(
    'DELETE FROM categories WHERE id = $1 AND business_id = $2 RETURNING id, name',
    [categoryId, businessId]
  );
  return rows[0] || null;
};

const countActiveProducts = async (businessId, categoryId, db = pool) => {
  const { rows } = await db.query(
    'SELECT COUNT(*)::int AS count FROM products WHERE business_id = $1 AND category_id = $2 AND is_active = TRUE',
    [businessId, categoryId]
  );
  return rows[0] ? rows[0].count : 0;
};

module.exports = { findAll, findById, nameExists, create, update, remove, countActiveProducts };
