/**
 * Custom operational error class.
 * Distinguishes known business/validation errors from unexpected crashes.
 */
class AppError extends Error {
  /**
   * @param {string} message - Human-readable message sent to the client
   * @param {number} statusCode - HTTP status code (400, 401, 403, 404, 409, etc.)
   */
  constructor(message, statusCode = 500) {
    super(message);
    this.statusCode = statusCode;
    this.status = statusCode >= 400 && statusCode < 500 ? 'fail' : 'error';
    this.isOperational = true; // Flag: known error, safe to expose to client

    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = AppError;
