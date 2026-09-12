const { verifyToken } = require('../utils/tokens');
const AppError = require('../utils/AppError');
const catchAsync = require('../utils/catchAsync');

/**
 * Authenticate middleware.
 * Verifies the Bearer token in Authorization header.
 * Attaches req.user = { id, businessId, roleId, roleName }
 */
const authenticate = catchAsync(async (req, res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new AppError('Authentication required. Please log in.', 401));
  }

  const token = authHeader.slice(7); // Remove 'Bearer '

  let decoded;
  try {
    decoded = verifyToken(token);
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return next(new AppError('Your session has expired. Please log in again.', 401));
    }
    return next(new AppError('Invalid authentication token.', 401));
  }

  req.user = {
    id:         decoded.id,
    businessId: decoded.businessId,
    roleId:     decoded.roleId,
    roleName:   decoded.roleName,
  };

  next();
});

module.exports = authenticate;
