const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');

/**
 * Sign a short-lived access token.
 * @param {object} payload - { id, businessId, roleId, roleName }
 * @returns {string} JWT string
 */
const getAccessSecret = () => process.env.JWT_ACCESS_SECRET || process.env.JWT_SECRET || 'fallback_stockflow_jwt_secret';
const getRefreshSecret = () => process.env.JWT_REFRESH_SECRET || process.env.JWT_SECRET || 'fallback_stockflow_jwt_secret';

/**
 * Sign a short-lived access token.
 * @param {object} payload - { id, businessId, roleId, roleName }
 * @returns {string} JWT string
 */
const signAccessToken = (payload) =>
  jwt.sign(payload, getAccessSecret(), {
    expiresIn: process.env.JWT_ACCESS_EXPIRES || '15m',
  });

/**
 * Sign a long-lived refresh token.
 * Includes unique jti (JWT ID) so every rotated token has a unique signature.
 * @param {object} payload - { id, businessId, roleId, roleName }
 * @returns {string} JWT string
 */
const signRefreshToken = (payload) =>
  jwt.sign({ ...payload, jti: uuidv4() }, getRefreshSecret(), {
    expiresIn: process.env.JWT_REFRESH_EXPIRES || '7d',
  });

/**
 * Verify and decode a JWT.
 * Throws if invalid or expired.
 * @param {string} token
 * @returns {object} decoded payload
 */
const verifyToken = (token) => {
  try {
    return jwt.verify(token, getAccessSecret());
  } catch (err) {
    // If access secret fails, try refresh secret
    return jwt.verify(token, getRefreshSecret());
  }
};

/**
 * Hash a token string with SHA-256 for DB storage.
 * Never store raw refresh tokens in the DB.
 * @param {string} token
 * @returns {string} hex hash
 */
const hashToken = (token) =>
  crypto.createHash('sha256').update(token).digest('hex');

module.exports = {
  signAccessToken,
  signRefreshToken,
  verifyToken,
  hashToken,
  generateAccessToken: signAccessToken,
  generateRefreshToken: signRefreshToken,
};
