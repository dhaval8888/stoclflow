-- 010: sale_items
CREATE TABLE IF NOT EXISTS sale_items (
  id           UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id      UUID          NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id   UUID          NOT NULL REFERENCES products(id),
  product_name VARCHAR(255)  NOT NULL,     -- snapshot: name at time of sale
  unit_price   NUMERIC(12,2) NOT NULL,     -- snapshot: price at time of sale
  quantity     NUMERIC(12,3) NOT NULL,
  discount     NUMERIC(12,2) NOT NULL DEFAULT 0,
  line_total   NUMERIC(12,2) NOT NULL,
  CONSTRAINT chk_sale_items_quantity_positive CHECK (quantity > 0),
  CONSTRAINT chk_sale_items_unit_price CHECK (unit_price >= 0),
  CONSTRAINT chk_sale_items_discount CHECK (discount >= 0),
  CONSTRAINT chk_sale_items_line_total CHECK (line_total >= 0)
);

CREATE INDEX IF NOT EXISTS idx_sale_items_sale    ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id);
