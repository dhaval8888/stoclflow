/**
 * Database migration runner.
 * Reads SQL files from migrations/ in alphabetical order and executes them.
 *
 * Usage: node src/db/migrate.js
 */
require('dotenv').config();
const fs   = require('fs');
const path = require('path');
const { pool } = require('../config/db');

const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

async function migrate() {
  console.log('🔄  Running migrations...\n');

  // Ensure schema_migrations table exists
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      filename   TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  // Get already-applied migrations
  const { rows: applied } = await pool.query('SELECT filename FROM schema_migrations');
  const appliedSet = new Set(applied.map((r) => r.filename));

  // Read migration files sorted by filename
  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  let count = 0;
  for (const file of files) {
    if (appliedSet.has(file)) {
      console.log(`  ⏭  Skipping  ${file}`);
      continue;
    }

    const filePath = path.join(MIGRATIONS_DIR, file);
    const sql = fs.readFileSync(filePath, 'utf8');

    try {
      await pool.query(sql);
      await pool.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [file]);
      console.log(`  ✅  Applied   ${file}`);
      count++;
    } catch (err) {
      console.error(`\n  ❌  Failed on ${file}:`, err.message);
      process.exit(1);
    }
  }

  if (count === 0) {
    console.log('\n  ✨  All migrations already applied. Database is up to date.');
  } else {
    console.log(`\n  ✨  Applied ${count} migration(s).`);
  }

  await pool.end();
}

migrate().catch((err) => {
  console.error('Migration error:', err);
  process.exit(1);
});
