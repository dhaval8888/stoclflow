require('dotenv').config({ path: '.env' });
const request = require('supertest');
const app = require('../src/app');
const { pool } = require('../src/config/db');

// Test credentials from seed
const OWNER_CREDS   = { email: 'owner@demo.com',   password: 'Owner@123' };
const CASHIER_CREDS = { email: 'cashier@demo.com', password: 'Cashier@123' };

describe('Auth API', () => {
  let ownerToken;
  let refreshToken;

  afterAll(async () => {
    await pool.end();
  });

  describe('POST /api/v1/auth/login', () => {
    it('should login with valid credentials', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send(OWNER_CREDS);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.tokens.accessToken).toBeDefined();
      expect(res.body.data.tokens.refreshToken).toBeDefined();
      expect(res.body.data.user.role).toBe('OWNER');

      ownerToken   = res.body.data.tokens.accessToken;
      refreshToken = res.body.data.tokens.refreshToken;
    });

    it('should reject invalid password', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ email: OWNER_CREDS.email, password: 'wrongpassword' });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it('should reject non-existent email', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ email: 'nobody@example.com', password: 'Test@123' });

      expect(res.status).toBe(401);
    });

    it('should return 422 for invalid email format', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({ email: 'not-an-email', password: 'Test@123' });

      expect(res.status).toBe(422);
    });
  });

  describe('POST /api/v1/auth/refresh', () => {
    it('should rotate tokens and return both new access and refresh tokens', async () => {
      const loginRes = await request(app)
        .post('/api/v1/auth/login')
        .send(OWNER_CREDS);

      const oldRt = loginRes.body.data.tokens.refreshToken;

      const res = await request(app)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: oldRt });

      expect(res.status).toBe(200);
      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();

      // Verify old refresh token is revoked/cannot be reused
      const reuseRes = await request(app)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: oldRt });

      expect(reuseRes.status).toBe(401);
    });

    it('should reject invalid refresh token', async () => {
      const res = await request(app)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: 'totally.invalid.token' });

      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/v1/auth/me', () => {
    it('should return profile with valid token', async () => {
      const loginRes = await request(app).post('/api/v1/auth/login').send(OWNER_CREDS);
      const token = loginRes.body.data.tokens.accessToken;

      const res = await request(app)
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data.profile.email).toBe(OWNER_CREDS.email);
    });

    it('should return 401 without token', async () => {
      const res = await request(app).get('/api/v1/auth/me');
      expect(res.status).toBe(401);
    });
  });

  describe('POST /api/v1/auth/logout', () => {
    it('should logout and invalidate refresh token', async () => {
      const loginRes = await request(app).post('/api/v1/auth/login').send(CASHIER_CREDS);
      const rt = loginRes.body.data.tokens.refreshToken;

      const logoutRes = await request(app)
        .post('/api/v1/auth/logout')
        .send({ refreshToken: rt });

      expect(logoutRes.status).toBe(200);

      // Refresh token should no longer work
      const refreshRes = await request(app)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: rt });

      expect(refreshRes.status).toBe(401);
    });
  });

  describe('RBAC', () => {
    it('cashier should be denied access to users endpoint', async () => {
      const loginRes = await request(app).post('/api/v1/auth/login').send(CASHIER_CREDS);
      const token = loginRes.body.data.tokens.accessToken;

      const res = await request(app)
        .get('/api/v1/users')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
    });
  });
});
