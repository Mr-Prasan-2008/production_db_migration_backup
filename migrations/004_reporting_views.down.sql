\set ON_ERROR_STOP on
SELECT EXISTS (SELECT 1 FROM app.schema_migrations WHERE version = '004') AS migration_applied \gset
\if :migration_applied
BEGIN;
DROP MATERIALIZED VIEW IF EXISTS app.mv_monthly_product_sales;
DROP VIEW IF EXISTS app.v_order_summary;
DELETE FROM app.schema_migrations WHERE version = '004';
COMMIT;
\else
\echo 'Migration 004 is not recorded; nothing to roll back.'
\endif
