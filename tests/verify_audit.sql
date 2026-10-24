\set ON_ERROR_STOP on
-- Use a transaction so the audit row created by this test is rolled back afterward.
BEGIN;
DO $test$
DECLARE
    v_product_id bigint;
    v_before bigint;
    v_after bigint;
BEGIN
    SELECT product_id INTO v_product_id FROM app.products WHERE sku = 'SKU-KEY-100';
    SELECT count(*) INTO v_before FROM app.audit_log
     WHERE table_name = 'app.products' AND record_pk = v_product_id::text AND operation = 'UPDATE';

    UPDATE app.products SET product_name = product_name || ' audit-check'
     WHERE product_id = v_product_id;

    SELECT count(*) INTO v_after FROM app.audit_log
     WHERE table_name = 'app.products' AND record_pk = v_product_id::text AND operation = 'UPDATE';
    IF v_after <= v_before THEN RAISE EXCEPTION 'Expected audit trigger to insert a product UPDATE event'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM app.audit_log
         WHERE table_name = 'app.products'
           AND record_pk = v_product_id::text
           AND operation = 'UPDATE'
           AND old_data IS NOT NULL AND new_data IS NOT NULL
    ) THEN RAISE EXCEPTION 'Audit event is missing old/new row snapshots'; END IF;
    RAISE NOTICE 'PASS: audit trigger captured UPDATE with old/new JSON snapshots';
END;
$test$;
ROLLBACK;
