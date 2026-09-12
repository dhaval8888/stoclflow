-- 009: sales
DO $$ BEGIN
  CREATE TYPE sale_status AS ENUM ('COMPLETED', 'REFUNDED', 'VOIDED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE payment_method AS ENUM ('CASH', 'CARD', 'UPI', 'OTHER');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS sales (
  id              UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id     UUID           NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  cashier_id      UUID           NOT NULL REFERENCES users(id),
  status          sale_status    NOT NULL DEFAULT 'COMPLETED',
  payment_method  payment_method NOT NULL DEFAULT 'CASH',
  subtotal        NUMERIC(12,2)  NOT NULL,
  discount_amount NUMERIC(12,2)  NOT NULL DEFAULT 0,
  tax_amount      NUMERIC(12,2)  NOT NULL DEFAULT 0,
  total_amount    NUMERIC(12,2)  NOT NULL,
  note            TEXT,
  created_at      TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_sales_amounts_positive CHECK (subtotal >= 0 AND discount_amount >= 0 AND tax_amount >= 0 AND total_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_sales_business   ON sales(business_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sales_cashier    ON sales(cashier_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sales_status     ON sales(business_id, status);
