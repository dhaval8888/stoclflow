-- 013: Business & Inventory Data Consistency Constraints
-- Guarantees cross-tenant isolation and data integrity at database level

-- 1. Ensure products table has composite unique constraint for foreign key references
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uq_products_id_business'
  ) THEN
    ALTER TABLE products ADD CONSTRAINT uq_products_id_business UNIQUE (id, business_id);
  END IF;
END $$;

-- 2. Non-negative checks on products
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_products_cost_price') THEN
    ALTER TABLE products ADD CONSTRAINT chk_products_cost_price CHECK (cost_price >= 0);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_products_selling_price') THEN
    ALTER TABLE products ADD CONSTRAINT chk_products_selling_price CHECK (selling_price >= 0);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_products_threshold') THEN
    ALTER TABLE products ADD CONSTRAINT chk_products_threshold CHECK (low_stock_threshold >= 0);
  END IF;
END $$;

-- 3. Enforce inventory composite business ownership & non-negative quantity
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_inventory_product_business') THEN
    ALTER TABLE inventory
      ADD CONSTRAINT fk_inventory_product_business
      FOREIGN KEY (product_id, business_id)
      REFERENCES products(id, business_id)
      ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_inventory_quantity_non_negative') THEN
    ALTER TABLE inventory ADD CONSTRAINT chk_inventory_quantity_non_negative CHECK (quantity >= 0);
  END IF;
END $$;

-- 4. Enforce inventory_transactions composite business ownership
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_inv_tx_product_business') THEN
    ALTER TABLE inventory_transactions
      ADD CONSTRAINT fk_inv_tx_product_business
      FOREIGN KEY (product_id, business_id)
      REFERENCES products(id, business_id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- 5. Sales amounts non-negative checks
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_sales_amounts_positive') THEN
    ALTER TABLE sales ADD CONSTRAINT chk_sales_amounts_positive
      CHECK (subtotal >= 0 AND discount_amount >= 0 AND tax_amount >= 0 AND total_amount >= 0);
  END IF;
END $$;

-- 6. Sale items positive quantity and non-negative amounts
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_sale_items_quantity_positive') THEN
    ALTER TABLE sale_items ADD CONSTRAINT chk_sale_items_quantity_positive CHECK (quantity > 0);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_sale_items_unit_price') THEN
    ALTER TABLE sale_items ADD CONSTRAINT chk_sale_items_unit_price CHECK (unit_price >= 0);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_sale_items_discount') THEN
    ALTER TABLE sale_items ADD CONSTRAINT chk_sale_items_discount CHECK (discount >= 0);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_sale_items_line_total') THEN
    ALTER TABLE sale_items ADD CONSTRAINT chk_sale_items_line_total CHECK (line_total >= 0);
  END IF;
END $$;
