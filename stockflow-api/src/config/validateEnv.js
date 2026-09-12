/**
 * Validates critical environment variables at startup.
 * Prevents the application from running with missing secrets or database configuration.
 * Does NOT log or leak sensitive values.
 */
function validateEnv() {
  if (process.env.NODE_ENV === 'test') {
    process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'test_jwt_access_secret_1234567890';
    process.env.JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'test_jwt_refresh_secret_1234567890';
    return true;
  }

  const required = [
    { key: 'DATABASE_URL', description: 'PostgreSQL connection string' },
    { key: 'JWT_ACCESS_SECRET', description: 'Secret key for signing access tokens' },
    { key: 'JWT_REFRESH_SECRET', description: 'Secret key for signing refresh tokens' },
  ];

  const missing = required.filter(({ key }) => !process.env[key] || process.env[key].trim() === '');

  if (missing.length > 0) {
    const errorList = missing.map(({ key, description }) => `  - ${key}: ${description}`).join('\n');
    console.error(`\n❌  STARTUP ERROR: Missing required environment variables:\n${errorList}\n`);
    console.error('Please configure your .env file or environment variables before starting StockFlow API.\n');
    throw new Error(`Missing required environment variables: ${missing.map((m) => m.key).join(', ')}`);
  }

  return true;
}

module.exports = validateEnv;
