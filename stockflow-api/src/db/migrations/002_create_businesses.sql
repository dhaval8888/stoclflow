-- 002: businesses
CREATE TABLE IF NOT EXISTS businesses (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name       VARCHAR(255) NOT NULL,
  address    TEXT,
  phone      VARCHAR(50),
  email      VARCHAR(255),
  currency   VARCHAR(10)  NOT NULL DEFAULT 'INR',
  timezone   VARCHAR(100) NOT NULL DEFAULT 'Asia/Kolkata',
  logo_url   TEXT,
  created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
