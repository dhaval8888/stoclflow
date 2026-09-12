/**
 * Analytics Repository
 * All reporting and analytics SQL queries.
 */
const { pool } = require('../../config/db');

const getSummary = async (businessId, db = pool) => {
  const [salesRes, productRes, alertsRes, recentRes] = await Promise.all([
    db.query(
      `SELECT
         COUNT(*) FILTER (WHERE s.created_at >= CURRENT_DATE AND s.status = 'COMPLETED')::int           AS today_sales,
         COALESCE(SUM(s.total_amount) FILTER (WHERE s.created_at >= CURRENT_DATE AND s.status = 'COMPLETED'), 0)::FLOAT AS today_revenue,
         COALESCE((
           SELECT SUM(si.line_total - (si.quantity * COALESCE(p.cost_price, 0)))
           FROM sale_items si
           JOIN sales s2 ON s2.id = si.sale_id
           LEFT JOIN products p ON p.id = si.product_id
           WHERE s2.business_id = $1 AND s2.status = 'COMPLETED' AND s2.created_at >= CURRENT_DATE
         ), 0)::FLOAT AS today_profit,

         COUNT(*) FILTER (WHERE s.created_at >= DATE_TRUNC('week',NOW()) AND s.status='COMPLETED')::int AS week_sales,
         COALESCE(SUM(s.total_amount) FILTER (WHERE s.created_at >= DATE_TRUNC('week',NOW()) AND s.status='COMPLETED'), 0)::FLOAT AS week_revenue,
         COALESCE((
           SELECT SUM(si.line_total - (si.quantity * COALESCE(p.cost_price, 0)))
           FROM sale_items si
           JOIN sales s2 ON s2.id = si.sale_id
           LEFT JOIN products p ON p.id = si.product_id
           WHERE s2.business_id = $1 AND s2.status = 'COMPLETED' AND s2.created_at >= DATE_TRUNC('week',NOW())
         ), 0)::FLOAT AS week_profit,

         COUNT(*) FILTER (WHERE s.created_at >= DATE_TRUNC('month',NOW()) AND s.status='COMPLETED')::int AS month_sales,
         COALESCE(SUM(s.total_amount) FILTER (WHERE s.created_at >= DATE_TRUNC('month',NOW()) AND s.status='COMPLETED'), 0)::FLOAT AS month_revenue,
         COALESCE((
           SELECT SUM(si.line_total - (si.quantity * COALESCE(p.cost_price, 0)))
           FROM sale_items si
           JOIN sales s2 ON s2.id = si.sale_id
           LEFT JOIN products p ON p.id = si.product_id
           WHERE s2.business_id = $1 AND s2.status = 'COMPLETED' AND s2.created_at >= DATE_TRUNC('month',NOW())
         ), 0)::FLOAT AS month_profit,

         COUNT(*) FILTER (WHERE s.status = 'COMPLETED')::int AS total_sales,
         COALESCE(SUM(s.total_amount) FILTER (WHERE s.status = 'COMPLETED'), 0)::FLOAT AS total_revenue,
         COALESCE((
           SELECT SUM(si.line_total - (si.quantity * COALESCE(p.cost_price, 0)))
           FROM sale_items si
           JOIN sales s2 ON s2.id = si.sale_id
           LEFT JOIN products p ON p.id = si.product_id
           WHERE s2.business_id = $1 AND s2.status = 'COMPLETED'
         ), 0)::FLOAT AS total_profit
       FROM sales s WHERE s.business_id = $1`,
      [businessId]
    ),
    db.query(
      `SELECT COUNT(*)::int AS total_products,
              COUNT(*) FILTER (WHERE is_active = TRUE)::int AS active_products
       FROM products WHERE business_id = $1`,
      [businessId]
    ),
    db.query(
      `SELECT
         COUNT(*) FILTER (WHERE COALESCE(inv.quantity,0) <= p.low_stock_threshold AND COALESCE(inv.quantity,0) > 0)::int AS low_stock_count,
         COUNT(*) FILTER (WHERE COALESCE(inv.quantity,0) = 0)::int AS out_of_stock_count
       FROM products p
       LEFT JOIN inventory inv ON inv.product_id = p.id
       WHERE p.business_id = $1 AND p.is_active = TRUE`,
      [businessId]
    ),
    db.query(
      `SELECT s.id, s.total_amount, s.payment_method, s.status, s.created_at,
              COUNT(si.id)::int AS item_count, u.full_name AS cashier_name
       FROM sales s
       JOIN users u ON u.id = s.cashier_id
       LEFT JOIN sale_items si ON si.sale_id = s.id
       WHERE s.business_id = $1 AND s.status = 'COMPLETED'
       GROUP BY s.id, u.full_name
       ORDER BY s.created_at DESC LIMIT 10`,
      [businessId]
    ),
  ]);

  return {
    sales:       salesRes.rows[0],
    products:    productRes.rows[0],
    alerts:      alertsRes.rows[0],
    recentSales: recentRes.rows,
  };
};

const getSalesTrend = async (businessId, days, db = pool) => {
  const { rows } = await db.query(
    `SELECT DATE(s.created_at) AS date,
            COUNT(*)::int    AS sales_count,
            COALESCE(SUM(s.total_amount), 0)::FLOAT        AS revenue,
            COALESCE(SUM(s.discount_amount), 0)::FLOAT     AS total_discounts,
            COALESCE(SUM((
              SELECT COALESCE(SUM(si.line_total - (si.quantity * COALESCE(p.cost_price, 0))), 0)
              FROM sale_items si
              LEFT JOIN products p ON p.id = si.product_id
              WHERE si.sale_id = s.id
            )), 0)::FLOAT AS profit
     FROM sales s
     WHERE s.business_id = $1
       AND s.status = 'COMPLETED'
       AND s.created_at >= NOW() - ($2 || ' days')::INTERVAL
     GROUP BY DATE(s.created_at)
     ORDER BY date ASC`,
    [businessId, days]
  );
  return rows;
};

const getTopProducts = async (businessId, days, limit, db = pool) => {
  const { rows } = await db.query(
    `SELECT si.product_id, si.product_name,
            SUM(si.quantity)::numeric   AS total_quantity,
            SUM(si.line_total)::numeric AS total_revenue,
            COUNT(DISTINCT s.id)::int   AS sale_count
     FROM sale_items si
     JOIN sales s ON s.id = si.sale_id
     WHERE s.business_id = $1
       AND s.status = 'COMPLETED'
       AND s.created_at >= NOW() - ($2 || ' days')::INTERVAL
     GROUP BY si.product_id, si.product_name
     ORDER BY total_quantity DESC
     LIMIT $3`,
    [businessId, days, limit]
  );
  return rows;
};

/**
 * Slow-moving: active products with no completed sales in the last N days.
 */
const getSlowProducts = async (businessId, days, db = pool) => {
  const { rows } = await db.query(
    `SELECT p.id, p.name, p.sku, p.unit,
            c.name AS category_name,
            COALESCE(inv.quantity, 0) AS current_stock,
            COALESCE(recent.total_sold, 0) AS units_sold_in_period,
            p.low_stock_threshold
     FROM products p
     LEFT JOIN categories c ON c.id = p.category_id
     LEFT JOIN inventory inv ON inv.product_id = p.id
     LEFT JOIN (
       SELECT si.product_id, SUM(si.quantity) AS total_sold
       FROM sale_items si
       JOIN sales s ON s.id = si.sale_id
       WHERE s.business_id = $1 AND s.status = 'COMPLETED'
         AND s.created_at >= NOW() - ($2 || ' days')::INTERVAL
       GROUP BY si.product_id
     ) recent ON recent.product_id = p.id
     WHERE p.business_id = $1 AND p.is_active = TRUE
       AND COALESCE(recent.total_sold, 0) = 0
     ORDER BY COALESCE(inv.quantity, 0) DESC`,
    [businessId, days]
  );
  return rows;
};

const getInventoryValue = async (businessId, db = pool) => {
  const { rows } = await db.query(
    `SELECT COUNT(p.id)::int AS product_count,
            COALESCE(SUM(COALESCE(inv.quantity,0) * p.cost_price), 0)    AS total_cost_value,
            COALESCE(SUM(COALESCE(inv.quantity,0) * p.selling_price), 0) AS total_retail_value,
            COALESCE(SUM(COALESCE(inv.quantity,0)), 0)                    AS total_units
     FROM products p
     LEFT JOIN inventory inv ON inv.product_id = p.id
     WHERE p.business_id = $1 AND p.is_active = TRUE`,
    [businessId]
  );
  return rows[0];
};

const getProfitReport = async (businessId, days, db = pool) => {
  const { rows } = await db.query(
    `SELECT
       COALESCE(SUM(si.line_total), 0) AS total_revenue,
       COALESCE(SUM(si.quantity * p.cost_price), 0) AS total_cost,
       COALESCE(SUM(si.line_total) - SUM(si.quantity * p.cost_price), 0) AS estimated_gross_profit,
       COALESCE(SUM(s.discount_amount), 0) AS total_discounts,
       COUNT(DISTINCT s.id)::int AS total_sales,
       SUM(si.quantity)::numeric AS total_units_sold
     FROM sale_items si
     JOIN sales s ON s.id = si.sale_id
     LEFT JOIN products p ON p.id = si.product_id
     WHERE s.business_id = $1
       AND s.status = 'COMPLETED'
       AND s.created_at >= NOW() - ($2 || ' days')::INTERVAL`,
    [businessId, days]
  );
  return rows[0];
};

const getReportByPeriod = async (businessId, period, db = pool) => {
  const truncMap = { daily: 'day', weekly: 'week', monthly: 'month' };
  const trunc = truncMap[period] || 'day';
  const lookback = period === 'daily' ? 30 : period === 'weekly' ? 12 : 12;
  const intervalUnit = period === 'monthly' ? 'months' : period === 'weekly' ? 'weeks' : 'days';

  const { rows } = await db.query(
    `SELECT
       DATE_TRUNC($3, created_at) AS period_start,
       COUNT(*)::int              AS sales_count,
       COALESCE(SUM(total_amount), 0) AS revenue,
       COALESCE(SUM(discount_amount), 0) AS discounts
     FROM sales
     WHERE business_id = $1
       AND status = 'COMPLETED'
       AND created_at >= NOW() - ($2 || ' ' || $4)::INTERVAL
     GROUP BY DATE_TRUNC($3, created_at)
     ORDER BY period_start ASC`,
    [businessId, lookback, trunc, intervalUnit]
  );
  return rows;
};

module.exports = {
  getSummary, getSalesTrend, getTopProducts, getSlowProducts,
  getInventoryValue, getProfitReport, getReportByPeriod,
};
