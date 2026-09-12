/**
 * Users Repository
 * All database operations for users / employees.
 */
const { pool } = require('../../config/db');

const SAFE_SELECT = `
  u.id, u.business_id, u.role_id, u.full_name, u.email, u.phone,
  u.is_active, u.last_login_at, u.created_at, u.updated_at,
  r.name AS role_name
`;

const findAll = async (businessId, { role, search, isActive, limit, offset }, db = pool) => {
  const conditions = ['u.business_id = $1'];
  const params = [businessId];
  let idx = 2;

  if (role) { conditions.push(`r.name = $${idx++}`); params.push(role.toUpperCase()); }
  if (isActive !== undefined) { conditions.push(`u.is_active = $${idx++}`); params.push(isActive); }
  if (search) {
    conditions.push(`(u.full_name ILIKE $${idx} OR u.email ILIKE $${idx})`);
    params.push(`%${search}%`); idx++;
  }

  const where = conditions.join(' AND ');

  const [countRes, dataRes] = await Promise.all([
    db.query(
      `SELECT COUNT(*) FROM users u JOIN roles r ON r.id = u.role_id WHERE ${where}`,
      params
    ),
    db.query(
      `SELECT ${SAFE_SELECT}
       FROM users u JOIN roles r ON r.id = u.role_id
       WHERE ${where}
       ORDER BY u.created_at DESC
       LIMIT $${idx} OFFSET $${idx + 1}`,
      [...params, limit, offset]
    ),
  ]);

  return { rows: dataRes.rows, total: parseInt(countRes.rows[0].count, 10) };
};

const findById = async (businessId, userId, db = pool) => {
  const { rows } = await db.query(
    `SELECT ${SAFE_SELECT}
     FROM users u JOIN roles r ON r.id = u.role_id
     WHERE u.id = $1 AND u.business_id = $2`,
    [userId, businessId]
  );
  return rows[0] || null;
};

const emailExists = async (email, db = pool) => {
  const { rows } = await db.query('SELECT id FROM users WHERE email = $1', [email]);
  return rows.length > 0;
};

const create = async ({ id, businessId, roleId, fullName, email, phone, passwordHash }, db = pool) => {
  const { rows } = await db.query(
    `INSERT INTO users (id, business_id, role_id, full_name, email, phone, password_hash)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, business_id, role_id, full_name, email, phone, is_active, created_at`,
    [id, businessId, roleId, fullName, email, phone || null, passwordHash]
  );
  return rows[0];
};

const update = async (businessId, userId, { fullName, phone, roleId, isActive }, db = pool) => {
  const { rows } = await db.query(
    `UPDATE users
     SET full_name  = COALESCE($3, full_name),
         phone      = COALESCE($4, phone),
         role_id    = COALESCE($5, role_id),
         is_active  = COALESCE($6, is_active),
         updated_at = NOW()
     WHERE id = $1 AND business_id = $2
     RETURNING id, full_name, email, phone, role_id, is_active`,
    [userId, businessId, fullName ?? null, phone ?? null, roleId ?? null, isActive ?? null]
  );
  return rows[0] || null;
};

const deactivate = async (businessId, userId, db = pool) => {
  const { rows } = await db.query(
    `UPDATE users SET is_active = FALSE, updated_at = NOW()
     WHERE id = $1 AND business_id = $2
     RETURNING id, full_name, email, is_active`,
    [userId, businessId]
  );
  return rows[0] || null;
};

module.exports = { findAll, findById, emailExists, create, update, deactivate };
