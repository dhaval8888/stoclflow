/**
 * Business Repository
 * All database operations for the businesses table.
 */
const { pool } = require('../../config/db');

const findById = async (businessId, db = pool) => {
  const { rows } = await db.query(
    `SELECT id, name, address, phone, email, currency, timezone, logo_url, created_at, updated_at
     FROM businesses WHERE id = $1`,
    [businessId]
  );
  return rows[0] || null;
};

const update = async (businessId, fields, db = pool) => {
  const { name, address, phone, email, currency, timezone } = fields;
  const { rows } = await db.query(
    `UPDATE businesses
     SET name      = COALESCE($2, name),
         address   = COALESCE($3, address),
         phone     = COALESCE($4, phone),
         email     = COALESCE($5, email),
         currency  = COALESCE($6, currency),
         timezone  = COALESCE($7, timezone),
         updated_at = NOW()
     WHERE id = $1
     RETURNING id, name, address, phone, email, currency, timezone, logo_url, updated_at`,
    [businessId, name, address, phone, email, currency, timezone]
  );
  return rows[0] || null;
};

const updateLogo = async (businessId, logoUrl, db = pool) => {
  const { rows } = await db.query(
    `UPDATE businesses SET logo_url = $2, updated_at = NOW()
     WHERE id = $1 RETURNING id, logo_url`,
    [businessId, logoUrl]
  );
  return rows[0] || null;
};

module.exports = { findById, update, updateLogo };
