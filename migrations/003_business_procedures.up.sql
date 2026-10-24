\set ON_ERROR_STOP on
SELECT EXISTS (SELECT 1 FROM app.schema_migrations WHERE version = '003') AS migration_applied \gset
\if :migration_applied
    \echo 'Migration 003 already applied; skipping procedures.'
\else
BEGIN;
CREATE OR REPLACE FUNCTION app.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at := clock_timestamp();
    RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON app.customers
FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON app.products
FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();
CREATE TRIGGER trg_inventory_updated_at BEFORE UPDATE ON app.inventory
FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();
CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON app.orders
FOR EACH ROW EXECUTE FUNCTION app.set_updated_at();

CREATE OR REPLACE PROCEDURE app.adjust_inventory(
    IN p_product_id bigint,
    IN p_delta integer,
    IN p_reason text
)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_current_quantity integer;
BEGIN
    IF p_delta IS NULL OR p_delta = 0 THEN
        RAISE EXCEPTION 'Inventory adjustment delta must be a non-zero integer.' USING ERRCODE = '22023';
    END IF;
    IF p_reason IS NULL OR length(btrim(p_reason)) = 0 THEN
        RAISE EXCEPTION 'A non-empty inventory adjustment reason is required.' USING ERRCODE = '22023';
    END IF;

    SELECT quantity_on_hand
      INTO v_current_quantity
      FROM app.inventory
     WHERE product_id = p_product_id
     FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No inventory row exists for product_id %.', p_product_id USING ERRCODE = '23503';
    END IF;
    IF v_current_quantity + p_delta < 0 THEN
        RAISE EXCEPTION 'Inventory cannot become negative (product_id %, current %, delta %).',
            p_product_id, v_current_quantity, p_delta USING ERRCODE = '23514';
    END IF;

    UPDATE app.inventory
       SET quantity_on_hand = quantity_on_hand + p_delta
     WHERE product_id = p_product_id;
    INSERT INTO app.inventory_movements (product_id, delta_quantity, reason)
    VALUES (p_product_id, p_delta, p_reason);
END;
$procedure$;

CREATE OR REPLACE PROCEDURE app.fulfill_order(IN p_order_id bigint)
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_status text;
    v_reference text;
    v_item record;
    v_item_count bigint;
BEGIN
    SELECT status, order_reference
      INTO v_status, v_reference
      FROM app.orders
     WHERE order_id = p_order_id
     FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % does not exist.', p_order_id USING ERRCODE = '23503';
    END IF;
    IF v_status <> 'pending' THEN
        RAISE EXCEPTION 'Only pending orders can be fulfilled (order %, status %).', p_order_id, v_status
            USING ERRCODE = '23514';
    END IF;
    SELECT count(*) INTO v_item_count FROM app.order_items WHERE order_id = p_order_id;
    IF v_item_count = 0 THEN
        RAISE EXCEPTION 'Order % has no line items.', p_order_id USING ERRCODE = '23514';
    END IF;
    IF EXISTS (
        SELECT 1
          FROM app.order_items oi
          LEFT JOIN app.inventory i ON i.product_id = oi.product_id
         WHERE oi.order_id = p_order_id AND i.product_id IS NULL
    ) THEN
        RAISE EXCEPTION 'At least one order item has no inventory row (order %).', p_order_id USING ERRCODE = '23503';
    END IF;

    -- Lock inventory rows in product_id order to reduce deadlock risk for concurrent fulfillments.
    FOR v_item IN
        SELECT oi.product_id, oi.quantity, i.quantity_on_hand
          FROM app.order_items oi
          JOIN app.inventory i ON i.product_id = oi.product_id
         WHERE oi.order_id = p_order_id
         ORDER BY oi.product_id
         FOR UPDATE OF i
    LOOP
        IF v_item.quantity_on_hand < v_item.quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product_id % (available %, requested %).',
                v_item.product_id, v_item.quantity_on_hand, v_item.quantity USING ERRCODE = '23514';
        END IF;
        UPDATE app.inventory
           SET quantity_on_hand = quantity_on_hand - v_item.quantity
         WHERE product_id = v_item.product_id;
        INSERT INTO app.inventory_movements (product_id, delta_quantity, reason)
        VALUES (v_item.product_id, -v_item.quantity, format('Fulfilled order %s', v_reference));
    END LOOP;

    UPDATE app.orders
       SET status = 'fulfilled', fulfilled_at = clock_timestamp()
     WHERE order_id = p_order_id;
END;
$procedure$;

INSERT INTO app.schema_migrations (version, description)
VALUES ('003', 'Updated-at triggers and transactional inventory/order procedures')
ON CONFLICT (version) DO NOTHING;
COMMIT;
\endif
