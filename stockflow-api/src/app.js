const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const errorHandler = require('./middleware/errorHandler');
const authRoutes = require('./modules/auth/auth.routes');
const businessRoutes = require('./modules/business/business.routes');
const usersRoutes = require('./modules/users/users.routes');
const categoriesRoutes = require('./modules/categories/categories.routes');
const productsRoutes = require('./modules/products/products.routes');
const inventoryRoutes = require('./modules/inventory/inventory.routes');
const salesRoutes = require('./modules/sales/sales.routes');
const analyticsRoutes = require('./modules/analytics/analytics.routes');
const notificationsRoutes = require('./modules/notifications/notifications.routes');

const app = express();

// ─── Security ────────────────────────────────────────────────────────────────
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ─── Rate Limiting ────────────────────────────────────────────────────────────
const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 min
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many requests, please try again later.' },
});

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many auth attempts, please try again later.' },
});

app.use('/api', globalLimiter);

// ─── Body Parsing ─────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ─── Logging ─────────────────────────────────────────────────────────────────
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

// ─── API Documentation (Swagger / OpenAPI 3.0) ────────────────────────────────
const swaggerUi = require('swagger-ui-express');
const openApiDoc = require('./docs/openapi.json');
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(openApiDoc));

// ─── Health Check ─────────────────────────────────────────────────────────────
const { pool } = require('./config/db');

const healthHandler = async (req, res) => {
  let dbStatus = 'disconnected';
  try {
    if (pool && !pool.ending) {
      await pool.query('SELECT 1');
      dbStatus = 'connected';
    }
  } catch {
    dbStatus = 'unreachable';
  }

  const isHealthy = dbStatus === 'connected' || process.env.NODE_ENV === 'test';
  res.status(isHealthy ? 200 : 503).json({
    status: isHealthy ? 'healthy' : 'degraded',
    message: 'StockFlow API is running',
    version: '1.0.0',
    database: dbStatus,
    timestamp: new Date().toISOString(),
  });
};

app.get('/health', healthHandler);
app.get('/api/health', healthHandler);

// ─── API Routes ───────────────────────────────────────────────────────────────
app.use('/api/v1/auth',          authLimiter, authRoutes);
app.use('/api/v1/business',      businessRoutes);
app.use('/api/v1/users',         usersRoutes);
app.use('/api/v1/categories',    categoriesRoutes);
app.use('/api/v1/products',      productsRoutes);
app.use('/api/v1/inventory',     inventoryRoutes);
app.use('/api/v1/sales',         salesRoutes);
app.use('/api/v1/analytics',     analyticsRoutes);
app.use('/api/v1/notifications', notificationsRoutes);

// ─── 404 ──────────────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Cannot ${req.method} ${req.originalUrl}`,
  });
});

// ─── Central Error Handler ────────────────────────────────────────────────────
app.use(errorHandler);

module.exports = app;
