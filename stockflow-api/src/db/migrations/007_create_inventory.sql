-- 007: inventory (current stock — one row per product)
CREATE TABLE IF NOT EXISTS inventory (
  id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id   UUID          UNIQUE NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  business_id  UUID          NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  quantity     NUMERIC(12,3) NOT NULL DEFAULT 0,
  last_updated TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_inventory_quantity_non_negative CHECK (quantity >= 0),
  CONSTRAINT fk_inventory_product_business FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_inventory_business ON inventory(business_id);
CREATE INDEX IF NOT EXISTS idx_inventory_product  ON inventory(product_id);
