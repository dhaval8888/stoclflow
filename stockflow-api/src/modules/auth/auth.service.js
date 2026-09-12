const { pool } = require('../../config/db');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcryptjs');
const AppError = require('../../utils/AppError');
const { generateAccessToken, generateRefreshToken, hashToken, verifyToken } = require('../../utils/tokens');
const authRepo = require('./auth.repository');

/**
 * Register a new business with the OWNER user.
 * Atomic: business + user created in one transaction.
 */
const register = async ({ businessName, businessAddress, businessPhone, fullName, email, password }) => {
  if (await authRepo.emailExists(email)) {
    throw new AppError('An account with this email already exists', 409);
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const passwordHash = await bcrypt.hash(password, 12);
    const businessId   = uuidv4();
    const userId       = uuidv4();

    const business = await authRepo.createBusiness(
      { id: businessId, name: businessName, address: businessAddress, phone: businessPhone },
      client
    );

    // Role 1 = OWNER (from seeded roles table)
    const user = await authRepo.createUser(
      { id: userId, businessId, roleId: 1, fullName, email, passwordHash },
      client
    );

    await client.query('COMMIT');
    return { business, user };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
};

/**
 * Authenticate user and issue JWT pair.
 */
const login = async ({ email, password }) => {
  const user = await authRepo.findUserByEmail(email);

  if (!user || !user.password_hash) {
    throw new AppError('Invalid email or password', 401);
  }
  if (!user.is_active) {
    throw new AppError('Your account has been deactivated. Contact your manager.', 403);
  }

  const passwordMatch = await bcrypt.compare(password, user.password_hash);
  if (!passwordMatch) throw new AppError('Invalid email or password', 401);

  await authRepo.updateLastLogin(user.id);

  const payload = {
    id:         user.id,
    businessId: user.business_id,
    roleName:   user.role_name,
  };

  const accessToken  = generateAccessToken(payload);
  const refreshToken = generateRefreshToken(payload);
  const tokenHash    = hashToken(refreshToken);
  const expiresAt    = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  await authRepo.storeRefreshToken({ id: uuidv4(), userId: user.id, tokenHash, expiresAt });
  await authRepo.pruneUserRefreshTokens(user.id, 5);

  const { password_hash, ...safeUser } = user;

  return {
    tokens: { accessToken, refreshToken },
    user:   { ...safeUser, role: user.role_name },
  };
};

/**
 * Proper Refresh Token Rotation:
 * 1. Validate the incoming refresh token.
 * 2. Verify it exists in database and is not expired/revoked.
 * 3. Remove/revoke the old refresh token (single-use rotation).
 * 4. Generate a new access token.
 * 5. Generate a new refresh token.
 * 6. Store the hash of the new refresh token (never raw token).
 * 7. Return the new token pair.
 */
const refreshToken = async (incomingToken) => {
  if (!incomingToken) throw new AppError('Refresh token required', 401);

  // 1. Validate token signature
  try {
    verifyToken(incomingToken);
  } catch (err) {
    throw new AppError('Invalid or expired refresh token', 401);
  }

  // 2. Look up stored hash in database
  const tokenHash = hashToken(incomingToken);
  const stored    = await authRepo.findRefreshToken(tokenHash);

  if (!stored) {
    throw new AppError('Invalid refresh token', 401);
  }

  // If expired, delete and reject
  if (new Date(stored.expires_at) < new Date()) {
    await authRepo.deleteRefreshToken(tokenHash);
    throw new AppError('Refresh token expired. Please log in again.', 401);
  }

  // 3. Invalidate old refresh token (single-use rotation)
  await authRepo.deleteRefreshToken(tokenHash);

  // 4. Verify user exists and is active
  const user = await authRepo.findUserById(stored.user_id);
  if (!user || !user.is_active) {
    throw new AppError('User account not found or deactivated', 401);
  }

  // 5. Generate new access token and new refresh token
  const payload = { id: user.id, businessId: user.business_id, roleName: user.role_name };
  const newAccessToken  = generateAccessToken(payload);
  const newRefreshToken = generateRefreshToken(payload);

  // 6. Store hash of the new refresh token
  const newTokenHash = hashToken(newRefreshToken);
  const expiresAt    = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

  await authRepo.storeRefreshToken({
    id:        uuidv4(),
    userId:    user.id,
    tokenHash: newTokenHash,
    expiresAt,
  });
  await authRepo.pruneUserRefreshTokens(user.id, 5);

  // 7. Return the new token pair
  return {
    accessToken:  newAccessToken,
    refreshToken: newRefreshToken,
  };
};

/**
 * Invalidate refresh token on logout.
 */
const logout = async (incomingToken) => {
  if (!incomingToken) return;
  await authRepo.deleteRefreshToken(hashToken(incomingToken));
};

/**
 * Return the authenticated user's profile.
 */
const getProfile = async (userId) => {
  const user = await authRepo.findUserById(userId);
  if (!user) throw new AppError('User not found', 404);
  return user;
};

module.exports = {
  register,
  login,
  refreshToken,
  refreshAccess: refreshToken, // backward compatibility alias
  logout,
  getProfile,
};
