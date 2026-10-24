\set ON_ERROR_STOP on
SELECT EXISTS (SELECT 1 FROM app.schema_migrations WHERE version = '002') AS migration_applied \gset
\if :migration_applied
BEGIN;
DROP TRIGGER IF EXISTS trg_audit_customers ON app.customers;
DROP TRIGGER IF EXISTS trg_audit_products ON app.products;
DROP TRIGGER IF EXISTS trg_audit_inventory ON app.inventory;
DROP TRIGGER IF EXISTS trg_audit_orders ON app.orders;
DROP TRIGGER IF EXISTS trg_audit_order_items ON app.order_items;
DROP TRIGGER IF EXISTS trg_audit_inventory_movements ON app.inventory_movements;
DROP FUNCTION IF EXISTS app.capture_audit_event();
DROP TABLE IF EXISTS app.audit_log;
DELETE FROM app.schema_migrations WHERE version = '002';
COMMIT;
\else
\echo 'Migration 002 is not recorded; nothing to roll back.'
\endif
