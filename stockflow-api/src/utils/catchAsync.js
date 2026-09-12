/**
 * Wraps async route handlers to automatically catch rejected promises
 * and forward them to Express's next(err) error handler.
 *
 * Usage:
 *   router.get('/path', catchAsync(async (req, res) => { ... }));
 */
const catchAsync = (fn) => (req, res, next) => {
  Promise.resolve(fn(req, res, next)).catch(next);
};

module.exports = catchAsync;
