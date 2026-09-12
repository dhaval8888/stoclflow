/**
 * Notifications Repository
 */
const { pool } = require('../../config/db');

const upsertToken = async ({ id, userId, token, platform }, db = pool) => {
  await db.query(
    `INSERT INTO fcm_tokens (id, user_id, token, platform)
     VALUES ($1, $2, $3, $4)
     ON CONFLICT (user_id, token) DO UPDATE SET platform = EXCLUDED.platform`,
    [id, userId, token, platform || null]
  );
};

const deleteToken = async (userId, token, db = pool) => {
  await db.query('DELETE FROM fcm_tokens WHERE user_id = $1 AND token = $2', [userId, token]);
};

const findTokensByBusiness = async (businessId, roleIds, db = pool) => {
  const { rows } = await db.query(
    `SELECT ft.token
     FROM fcm_tokens ft
     JOIN users u ON u.id = ft.user_id
     WHERE u.business_id = $1 AND u.role_id = ANY($2::int[]) AND u.is_active = TRUE`,
    [businessId, roleIds]
  );
  return rows.map((r) => r.token);
};

module.exports = { upsertToken, deleteToken, findTokensByBusiness };
