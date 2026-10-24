\set ON_ERROR_STOP on
-- Successful inventory adjustment is verified and rolled back so the fixture stays unchanged.
BEGIN;
DO $test$
DECLARE
    v_product_id bigint;
    v_before integer;
    v_after integer;
BEGIN
    SELECT product_id INTO v_product_id FROM app.products WHERE sku = 'SKU-KEY-100';
    SELECT quantity_on_hand INTO v_before FROM app.inventory WHERE product_id = v_product_id;
    CALL app.adjust_inventory(v_product_id, 3, 'verification-only adjustment');
    SELECT quantity_on_hand INTO v_after FROM app.inventory WHERE product_id = v_product_id;
    IF v_after <> v_before + 3 THEN RAISE EXCEPTION 'Inventory adjustment result mismatch'; END IF;
    IF NOT EXISTS (SELECT 1 FROM app.inventory_movements WHERE product_id = v_product_id AND reason = 'verification-only adjustment') THEN
        RAISE EXCEPTION 'Inventory movement ledger was not written';
    END IF;
    RAISE NOTICE 'PASS: adjust_inventory locks, updates, and writes a movement record';
END;
$test$;
ROLLBACK;

-- Negative adjustment beyond available stock must be rejected. The entire test is rollback-only.
BEGIN;
DO $test$
DECLARE
    v_product_id bigint;
    v_rejected boolean := false;
BEGIN
    SELECT product_id INTO v_product_id FROM app.products WHERE sku = 'SKU-KEY-100';
    BEGIN
        CALL app.adjust_inventory(v_product_id, -999999, 'verification negative stock');
    EXCEPTION WHEN check_violation THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'Expected excessive stock reduction to raise check_violation'; END IF;
    RAISE NOTICE 'PASS: adjust_inventory rejects changes that would make stock negative';
END;
$test$;
ROLLBACK;

-- Successful fulfillment exercises ordered row locking, stock deduction, ledger writes, and status update.
BEGIN;
DO $test$
DECLARE
    v_order_id bigint;
    v_chair_id bigint;
    v_before integer;
    v_after integer;
    v_status text;
BEGIN
    SELECT order_id INTO v_order_id FROM app.orders WHERE order_reference = 'SO-1005';
    SELECT product_id INTO v_chair_id FROM app.products WHERE sku = 'SKU-CHR-100';
    SELECT quantity_on_hand INTO v_before FROM app.inventory WHERE product_id = v_chair_id;
    CALL app.fulfill_order(v_order_id);
    SELECT quantity_on_hand INTO v_after FROM app.inventory WHERE product_id = v_chair_id;
    SELECT status INTO v_status FROM app.orders WHERE order_id = v_order_id;
    IF v_status <> 'fulfilled' THEN RAISE EXCEPTION 'Expected SO-1005 to be fulfilled in test transaction'; END IF;
    IF v_after <> v_before - 1 THEN RAISE EXCEPTION 'Expected chair inventory to decrease by one'; END IF;
    RAISE NOTICE 'PASS: fulfill_order atomically updates order status and decrements inventory';
END;
$test$;
ROLLBACK;

-- A fulfilled order cannot be fulfilled again.
BEGIN;
DO $test$
DECLARE
    v_order_id bigint;
    v_rejected boolean := false;
BEGIN
    SELECT order_id INTO v_order_id FROM app.orders WHERE order_reference = 'SO-1001';
    BEGIN
        CALL app.fulfill_order(v_order_id);
    EXCEPTION WHEN check_violation THEN
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'Expected already-fulfilled order to be rejected'; END IF;
    RAISE NOTICE 'PASS: fulfill_order rejects orders that are not pending';
END;
$test$;
ROLLBACK;
