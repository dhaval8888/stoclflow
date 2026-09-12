-- 001b: roles table (must exist before seed)
CREATE TABLE IF NOT EXISTS roles (
  id   SMALLINT PRIMARY KEY,
  name VARCHAR(20) UNIQUE NOT NULL
);
