-- 008: inventory_transactions (audit trail — every stock movement)
DO $$ BEGIN
  CREATE TYPE inv_tx_type AS ENUM (
    'STOCK_IN',
    'STOCK_OUT',
    'SALE',
    'ADJUSTMENT',
    'RETURN'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS inventory_transactions (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     UUID          NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  product_id      UUID          NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  user_id         UUID          NOT NULL REFERENCES users(id),
  type            inv_tx_type   NOT NULL,
  quantity        NUMERIC(12,3) NOT NULL,    -- positive = IN, negative = OUT
  quantity_before NUMERIC(12,3) NOT NULL,
  quantity_after  NUMERIC(12,3) NOT NULL,
  reference_id    UUID,                       -- sale_id when type = SALE or RETURN
  note            TEXT,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_inv_tx_product_business FOREIGN KEY (product_id, business_id) REFERENCES products(id, business_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_inv_tx_product  ON inventory_transactions(product_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inv_tx_business ON inventory_transactions(business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inv_tx_ref      ON inventory_transactions(reference_id);
