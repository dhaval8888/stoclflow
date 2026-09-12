const AppError = require('../utils/AppError');

/**
 * Central Express error handler.
 * Must be last middleware registered in app.js.
 */
// eslint-disable-next-line no-unused-vars
const errorHandler = (err, req, res, next) => {
  // Default to 500
  let statusCode = err.statusCode || 500;
  let message = err.message || 'Internal Server Error';
  let errors = err.errors || undefined;

  // ─── Zod Validation Errors ────────────────────────────────────────────────
  if (err.name === 'ZodError') {
    statusCode = 422;
    message = 'Validation failed';
    errors = err.errors.map((e) => ({
      field: e.path.join('.'),
      message: e.message,
    }));
  }

  // ─── JWT Errors ───────────────────────────────────────────────────────────
  if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    message = 'Invalid token';
  }

  if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    message = 'Token expired';
  }

  // ─── PostgreSQL Errors ────────────────────────────────────────────────────
  if (err.code === '23505') {
    // Unique constraint violation
    statusCode = 409;
    message = 'A record with this value already exists';
    // Extract field name from constraint detail
    const match = err.detail?.match(/Key \((.+?)\)=/);
    if (match) message = `${match[1]} already exists`;
  }

  if (err.code === '23503') {
    // Foreign key violation
    statusCode = 400;
    message = 'Referenced record does not exist';
  }

  if (err.code === '23502') {
    // Not null violation
    statusCode = 400;
    message = `Field '${err.column}' is required`;
  }

  // ─── Non-operational errors: don't leak internals ─────────────────────────
  if (!err.isOperational && statusCode === 500) {
    console.error('❌  Unhandled error:', err);
    if (process.env.NODE_ENV === 'production') {
      message = 'Something went wrong. Please try again.';
    }
  }

  res.status(statusCode).json({
    success: false,
    message,
    ...(errors && { errors }),
    ...(process.env.NODE_ENV === 'development' && statusCode === 500 && {
      stack: err.stack,
    }),
  });
};

module.exports = errorHandler;
