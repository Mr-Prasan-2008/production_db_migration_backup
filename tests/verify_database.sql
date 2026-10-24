\set ON_ERROR_STOP on
DO $test$
DECLARE
    v_count bigint;
BEGIN
    SELECT count(*) INTO v_count FROM app.schema_migrations;
    IF v_count <> 4 THEN RAISE EXCEPTION 'Expected 4 recorded migrations, found %', v_count; END IF;
    RAISE NOTICE 'PASS: all four versioned migrations are recorded';

    SELECT count(*) INTO v_count FROM app.customers;
    IF v_count < 4 THEN RAISE EXCEPTION 'Expected at least 4 customers, found %', v_count; END IF;
    SELECT count(*) INTO v_count FROM app.products;
    IF v_count < 5 THEN RAISE EXCEPTION 'Expected at least 5 products, found %', v_count; END IF;
    SELECT count(*) INTO v_count FROM app.orders;
    IF v_count < 5 THEN RAISE EXCEPTION 'Expected at least 5 orders, found %', v_count; END IF;
    SELECT count(*) INTO v_count FROM app.order_items;
    IF v_count < 9 THEN RAISE EXCEPTION 'Expected at least 9 order items, found %', v_count; END IF;
    RAISE NOTICE 'PASS: repeatable fixtures populated customers, products, orders, and order items';

    IF to_regclass('app.v_order_summary') IS NULL THEN RAISE EXCEPTION 'Order summary view missing'; END IF;
    IF to_regclass('app.mv_monthly_product_sales') IS NULL THEN RAISE EXCEPTION 'Sales materialized view missing'; END IF;
    SELECT count(*) INTO v_count FROM app.mv_monthly_product_sales;
    IF v_count < 1 THEN RAISE EXCEPTION 'Monthly sales materialized view is empty'; END IF;
    RAISE NOTICE 'PASS: ordinary and materialized reporting views exist and contain data';

    IF NOT EXISTS (SELECT 1 FROM app.inventory WHERE quantity_on_hand >= 0) THEN
        RAISE EXCEPTION 'Inventory rows missing or invalid';
    END IF;
    IF EXISTS (
        SELECT 1 FROM app.inventory i
        JOIN app.products p USING (product_id)
        WHERE i.quantity_on_hand < 0
    ) THEN RAISE EXCEPTION 'Negative inventory row found'; END IF;
    RAISE NOTICE 'PASS: inventory data respects non-negative stock checks';
END;
$test$;

SELECT 'customers' AS table_name, count(*) AS row_count FROM app.customers
UNION ALL SELECT 'products', count(*) FROM app.products
UNION ALL SELECT 'inventory', count(*) FROM app.inventory
UNION ALL SELECT 'orders', count(*) FROM app.orders
UNION ALL SELECT 'order_items', count(*) FROM app.order_items
UNION ALL SELECT 'inventory_movements', count(*) FROM app.inventory_movements
UNION ALL SELECT 'audit_log', count(*) FROM app.audit_log
ORDER BY table_name;
