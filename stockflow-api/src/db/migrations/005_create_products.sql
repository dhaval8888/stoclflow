-- 005: products
CREATE TABLE IF NOT EXISTS products (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id         UUID         NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  category_id         UUID         REFERENCES categories(id) ON DELETE SET NULL,
  name                VARCHAR(255) NOT NULL,
  description         TEXT,
  sku                 VARCHAR(100),
  barcode             VARCHAR(100),
  unit                VARCHAR(50)  NOT NULL DEFAULT 'pcs',
  cost_price          NUMERIC(12,2) NOT NULL DEFAULT 0,
  selling_price       NUMERIC(12,2) NOT NULL DEFAULT 0,
  low_stock_threshold INT          NOT NULL DEFAULT 10 CHECK (low_stock_threshold >= 0),
  is_active           BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  UNIQUE (id, business_id),
  UNIQUE (business_id, sku),
  UNIQUE (business_id, barcode),
  CONSTRAINT chk_products_cost_price CHECK (cost_price >= 0),
  CONSTRAINT chk_products_selling_price CHECK (selling_price >= 0)
);

CREATE INDEX IF NOT EXISTS idx_products_business    ON products(business_id);
CREATE INDEX IF NOT EXISTS idx_products_category    ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode     ON products(business_id, barcode);
CREATE INDEX IF NOT EXISTS idx_products_sku         ON products(business_id, sku);
CREATE INDEX IF NOT EXISTS idx_products_active      ON products(business_id, is_active);
