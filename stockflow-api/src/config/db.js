const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on('connect', () => {
  if (process.env.NODE_ENV !== 'test') {
    console.log('✅  PostgreSQL connected');
  }
});

pool.on('error', (err) => {
  console.error('❌  PostgreSQL pool error:', err);
  process.exit(1);
});

/**
 * Execute a single query with optional parameters.
 * @param {string} text
 * @param {Array} params
 */
const query = (text, params) => pool.query(text, params);

/**
 * Get a client from the pool for manual transactions.
 * Always call client.release() in finally block.
 */
const getClient = () => pool.connect();

module.exports = { pool, query, getClient };
