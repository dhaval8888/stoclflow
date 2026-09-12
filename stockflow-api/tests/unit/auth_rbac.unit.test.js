process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'super_secret_test_key_minimum_32_characters_long_123';

const authenticate = require('../../src/middleware/auth');
const { authorize, ROLES } = require('../../src/middleware/authorize');
const { generateAccessToken, generateRefreshToken, hashToken, verifyToken } = require('../../src/utils/tokens');
const AppError = require('../../src/utils/AppError');

describe('Authentication & RBAC Unit Tests', () => {
  const testUser = {
    id: '11111111-1111-1111-1111-111111111111',
    businessId: '22222222-2222-2222-2222-222222222222',
    roleId: '33333333-3333-3333-3333-333333333333',
    roleName: ROLES.OWNER,
  };

  describe('1. JWT Token Utilities', () => {
    it('generates a valid access token that decodes correctly', () => {
      const token = generateAccessToken(testUser);
      expect(typeof token).toBe('string');

      const decoded = verifyToken(token);
      expect(decoded.id).toBe(testUser.id);
      expect(decoded.businessId).toBe(testUser.businessId);
      expect(decoded.roleName).toBe(ROLES.OWNER);
    });

    it('generates high-entropy refresh tokens and SHA-256 hashes', () => {
      const rawToken = generateRefreshToken();
      expect(typeof rawToken).toBe('string');
      expect(rawToken.length).toBeGreaterThanOrEqual(64);

      const hash1 = hashToken(rawToken);
      const hash2 = hashToken(rawToken);
      expect(hash1).toBe(hash2); // Deterministic hash
      expect(hash1).not.toBe(rawToken);
    });

    it('rejects invalid or tampered tokens', () => {
      expect(() => verifyToken('invalid.jwt.token')).toThrow();
    });
  });

  describe('2. Authentication Middleware', () => {
    it('rejects requests without Authorization header', async () => {
      const req = { headers: {} };
      const res = {};
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(next).toHaveBeenCalledWith(expect.any(AppError));
      expect(next.mock.calls[0][0].statusCode).toBe(401);
      expect(next.mock.calls[0][0].message).toMatch(/Authentication required/);
    });

    it('rejects requests with malformed header scheme', async () => {
      const req = { headers: { authorization: 'Basic xyz123' } };
      const res = {};
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(next).toHaveBeenCalledWith(expect.any(AppError));
      expect(next.mock.calls[0][0].statusCode).toBe(401);
    });

    it('attaches user context to request when Bearer token is valid', async () => {
      const token = generateAccessToken(testUser);
      const req = { headers: { authorization: `Bearer ${token}` } };
      const res = {};
      const next = jest.fn();

      await authenticate(req, res, next);

      expect(next).toHaveBeenCalledWith(); // Called with no error
      expect(req.user).toBeDefined();
      expect(req.user.id).toBe(testUser.id);
      expect(req.user.businessId).toBe(testUser.businessId);
      expect(req.user.roleName).toBe(ROLES.OWNER);
    });
  });

  describe('3. Role-Based Access Control (RBAC) Middleware', () => {
    it('denies access (403) when user role is not permitted', () => {
      const req = { user: { ...testUser, roleName: ROLES.CASHIER } };
      const res = {};
      const next = jest.fn();

      const middleware = authorize(ROLES.OWNER, ROLES.MANAGER);
      middleware(req, res, next);

      expect(next).toHaveBeenCalledWith(expect.any(AppError));
      expect(next.mock.calls[0][0].statusCode).toBe(403);
      expect(next.mock.calls[0][0].message).toMatch(/Access denied/);
    });

    it('grants access when user role matches one of allowed roles', () => {
      const req = { user: { ...testUser, roleName: ROLES.MANAGER } };
      const res = {};
      const next = jest.fn();

      const middleware = authorize(ROLES.OWNER, ROLES.MANAGER);
      middleware(req, res, next);

      expect(next).toHaveBeenCalledWith(); // No error passed
    });

    it('blocks unauthenticated requests missing req.user', () => {
      const req = {};
      const res = {};
      const next = jest.fn();

      const middleware = authorize(ROLES.OWNER);
      middleware(req, res, next);

      expect(next).toHaveBeenCalledWith(expect.any(AppError));
      expect(next.mock.calls[0][0].statusCode).toBe(401);
    });
  });
});
