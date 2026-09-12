require('dotenv').config();
const validateEnv = require('./src/config/validateEnv');
validateEnv();

const app = require('./src/app');
const { pool } = require('./src/config/db');

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`\n🚀  StockFlow API`);
  console.log(`    Port     : ${PORT}`);
  console.log(`    Env      : ${process.env.NODE_ENV || 'development'}`);
  console.log(`    Version  : v1\n`);
});

// Graceful shutdown on SIGTERM (e.g. Railway/Render deploys)
process.on('SIGTERM', () => {
  console.log('⏳  SIGTERM received — shutting down gracefully...');
  server.close(async () => {
    await pool.end();
    console.log('✅  Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('\n⏳  SIGINT received — shutting down gracefully...');
  server.close(async () => {
    await pool.end();
    console.log('✅  Server closed');
    process.exit(0);
  });
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌  Unhandled Rejection at:', promise, 'reason:', reason);
  server.close(() => process.exit(1));
});

process.on('uncaughtException', (err) => {
  console.error('❌  Uncaught Exception:', err);
  process.exit(1);
});
