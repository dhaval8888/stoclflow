/**
 * Auth Repository
 * All authentication-related database operations.
 * Pass a pg client for transaction support.
 */
const { pool } = require('../../config/db');

const findUserByEmail = async (email, db = pool) => {
  const { rows } = await db.query(
    `SELECT u.id, u.business_id, u.role_id, u.full_name, u.email, u.phone,
            u.password_hash, u.is_active, u.last_login_at, u.created_at,
            r.name AS role_name,
            b.name AS business_name, b.currency, b.timezone, b.logo_url
     FROM users u
     JOIN roles r ON r.id = u.role_id
     JOIN businesses b ON b.id = u.business_id
     WHERE u.email = $1`,
    [email]
  );
  return rows[0] || null;
};

const findUserById = async (id, db = pool) => {
  const { rows } = await db.query(
    `SELECT u.id, u.business_id, u.full_name, u.email, u.phone, u.is_active,
            u.last_login_at, u.created_at, r.name AS role_name,
            b.name AS business_name, b.currency, b.timezone, b.logo_url
     FROM users u
     JOIN roles r ON r.id = u.role_id
     JOIN businesses b ON b.id = u.business_id
     WHERE u.id = $1`,
    [id]
  );
  return rows[0] || null;
};

const emailExists = async (email, db = pool) => {
  const { rows } = await db.query('SELECT id FROM users WHERE email = $1', [email]);
  return rows.length > 0;
};

const createBusiness = async ({ id, name, address, phone, currency, timezone }, db = pool) => {
  const { rows } = await db.query(
    `INSERT INTO businesses (id, name, address, phone, currency, timezone)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [id, name, address || null, phone || null, currency || 'INR', timezone || 'Asia/Kolkata']
  );
  return rows[0];
};

const createUser = async ({ id, businessId, roleId, fullName, email, passwordHash }, db = pool) => {
  const { rows } = await db.query(
    `INSERT INTO users (id, business_id, role_id, full_name, email, password_hash)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, business_id, role_id, full_name, email, phone, is_active, created_at`,
    [id, businessId, roleId, fullName, email, passwordHash]
  );
  return rows[0];
};

const updateLastLogin = async (userId, db = pool) => {
  await db.query('UPDATE users SET last_login_at = NOW() WHERE id = $1', [userId]);
};

const storeRefreshToken = async ({ id, userId, tokenHash, expiresAt }, db = pool) => {
  await db.query(
    `INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at)
     VALUES ($1, $2, $3, $4) ON CONFLICT (token_hash) DO NOTHING`,
    [id, userId, tokenHash, expiresAt]
  );
};

const findRefreshToken = async (tokenHash, db = pool) => {
  const { rows } = await db.query(
    'SELECT id, user_id, expires_at FROM refresh_tokens WHERE token_hash = $1',
    [tokenHash]
  );
  return rows[0] || null;
};

const deleteRefreshToken = async (tokenHash, db = pool) => {
  await db.query('DELETE FROM refresh_tokens WHERE token_hash = $1', [tokenHash]);
};

const pruneUserRefreshTokens = async (userId, keepCount = 5, db = pool) => {
  await db.query(
    `DELETE FROM refresh_tokens
     WHERE user_id = $1
       AND id NOT IN (
         SELECT id FROM refresh_tokens
         WHERE user_id = $1
         ORDER BY created_at DESC
         LIMIT $2
       )`,
    [userId, keepCount]
  );
};

module.exports = {
  findUserByEmail, findUserById, emailExists,
  createBusiness, createUser, updateLastLogin,
  storeRefreshToken, findRefreshToken, deleteRefreshToken, pruneUserRefreshTokens,
};
