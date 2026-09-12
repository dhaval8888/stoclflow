const AppError = require('../utils/AppError');

/**
 * Role-based authorization middleware factory.
 *
 * Usage:
 *   router.post('/users', authenticate, authorize('OWNER'), createUser);
 *   router.get('/reports', authenticate, authorize('OWNER', 'MANAGER'), getReports);
 *
 * @param {...string} allowedRoles - One or more role names: 'OWNER', 'MANAGER', 'CASHIER'
 */
const authorize = (...allowedRoles) => (req, res, next) => {
  if (!req.user) {
    return next(new AppError('Authentication required.', 401));
  }

  if (!allowedRoles.includes(req.user.roleName)) {
    return next(
      new AppError(
        `Access denied. Required role: ${allowedRoles.join(' or ')}.`,
        403
      )
    );
  }

  next();
};

/**
 * Role constants — use these instead of magic strings.
 */
const ROLES = Object.freeze({
  OWNER:   'OWNER',
  MANAGER: 'MANAGER',
  CASHIER: 'CASHIER',
});

module.exports = { authorize, ROLES };
