\set ON_ERROR_STOP on
SELECT EXISTS (SELECT 1 FROM app.schema_migrations WHERE version = '003') AS migration_applied \gset
\if :migration_applied
BEGIN;
DROP PROCEDURE IF EXISTS app.fulfill_order(bigint);
DROP PROCEDURE IF EXISTS app.adjust_inventory(bigint, integer, text);
DROP TRIGGER IF EXISTS trg_customers_updated_at ON app.customers;
DROP TRIGGER IF EXISTS trg_products_updated_at ON app.products;
DROP TRIGGER IF EXISTS trg_inventory_updated_at ON app.inventory;
DROP TRIGGER IF EXISTS trg_orders_updated_at ON app.orders;
DROP FUNCTION IF EXISTS app.set_updated_at();
DELETE FROM app.schema_migrations WHERE version = '003';
COMMIT;
\else
\echo 'Migration 003 is not recorded; nothing to roll back.'
\endif
