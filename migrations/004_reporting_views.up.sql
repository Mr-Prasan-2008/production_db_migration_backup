\set ON_ERROR_STOP on
SELECT EXISTS (SELECT 1 FROM app.schema_migrations WHERE version = '004') AS migration_applied \gset
\if :migration_applied
    \echo 'Migration 004 already applied; skipping reporting views.'
\else
BEGIN;
CREATE OR REPLACE VIEW app.v_order_summary AS
SELECT
    o.order_id,
    o.order_reference,
    c.customer_id,
    c.full_name AS customer_name,
    o.status,
    o.ordered_at,
    o.fulfilled_at,
    count(oi.order_item_id)::bigint AS item_count,
    COALESCE(sum(oi.quantity), 0)::bigint AS total_units,
    COALESCE(sum(oi.line_total), 0)::numeric(14,2) AS order_value
FROM app.orders o
JOIN app.customers c ON c.customer_id = o.customer_id
LEFT JOIN app.order_items oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.order_reference, c.customer_id, c.full_name, o.status, o.ordered_at, o.fulfilled_at;

CREATE MATERIALIZED VIEW app.mv_monthly_product_sales AS
SELECT
    date_trunc('month', o.ordered_at)::date AS sales_month,
    p.product_id,
    p.sku,
    p.product_name,
    count(DISTINCT o.order_id)::bigint AS order_count,
    sum(oi.quantity)::bigint AS units_sold,
    sum(oi.line_total)::numeric(14,2) AS sales_revenue
FROM app.orders o
JOIN app.order_items oi ON oi.order_id = o.order_id
JOIN app.products p ON p.product_id = oi.product_id
WHERE o.status = 'fulfilled'
GROUP BY date_trunc('month', o.ordered_at)::date, p.product_id, p.sku, p.product_name;
CREATE UNIQUE INDEX ux_mv_monthly_product_sales_month_product
    ON app.mv_monthly_product_sales (sales_month, product_id);

INSERT INTO app.schema_migrations (version, description)
VALUES ('004', 'Order summary view and monthly sales materialized view')
ON CONFLICT (version) DO NOTHING;
COMMIT;
\endif
