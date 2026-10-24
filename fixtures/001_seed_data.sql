\set ON_ERROR_STOP on
-- Synthetic demo data only. Inserts are safe to re-run on the same demo database.
INSERT INTO app.customers (full_name, email) VALUES
    ('Jordan Smith', 'jordan.smith@example.test'),
    ('Maria Garcia', 'maria.garcia@example.test'),
    ('Aarav Patel', 'aarav.patel@example.test'),
    ('Noah Chen', 'noah.chen@example.test')
ON CONFLICT DO NOTHING;

INSERT INTO app.products (sku, product_name, unit_price) VALUES
    ('SKU-KEY-100', 'Mechanical Keyboard', 79.99),
    ('SKU-MOU-100', 'Wireless Mouse', 29.99),
    ('SKU-MON-100', '27-inch Monitor', 249.00),
    ('SKU-DSK-100', 'Standing Desk', 399.00),
    ('SKU-CHR-100', 'Ergonomic Chair', 279.00)
ON CONFLICT (sku) DO NOTHING;

-- The on-hand figures are the final balance after the historical fulfilled orders below.
INSERT INTO app.inventory (product_id, quantity_on_hand)
SELECT p.product_id, v.quantity_on_hand
FROM (VALUES
    ('SKU-KEY-100', 25),
    ('SKU-MOU-100', 40),
    ('SKU-MON-100', 9),
    ('SKU-DSK-100', 7),
    ('SKU-CHR-100', 12)
) AS v(sku, quantity_on_hand)
JOIN app.products p ON p.sku = v.sku
ON CONFLICT (product_id) DO NOTHING;

INSERT INTO app.orders (order_reference, customer_id, status, ordered_at, fulfilled_at) VALUES
    ('SO-1001', (SELECT customer_id FROM app.customers WHERE email='jordan.smith@example.test'), 'fulfilled', '2026-09-05 10:00:00+00', '2026-09-05 10:30:00+00'),
    ('SO-1002', (SELECT customer_id FROM app.customers WHERE email='maria.garcia@example.test'), 'fulfilled', '2026-09-16 13:15:00+00', '2026-09-16 14:00:00+00'),
    ('SO-1003', (SELECT customer_id FROM app.customers WHERE email='aarav.patel@example.test'), 'pending',   '2026-10-02 09:10:00+00', NULL),
    ('SO-1004', (SELECT customer_id FROM app.customers WHERE email='jordan.smith@example.test'), 'cancelled', '2026-10-03 11:45:00+00', NULL),
    ('SO-1005', (SELECT customer_id FROM app.customers WHERE email='maria.garcia@example.test'), 'pending',   '2026-10-10 15:20:00+00', NULL)
ON CONFLICT (order_reference) DO NOTHING;

INSERT INTO app.order_items (order_id, product_id, quantity, unit_price)
SELECT o.order_id, p.product_id, v.quantity, p.unit_price
FROM (VALUES
    ('SO-1001', 'SKU-KEY-100', 2),
    ('SO-1001', 'SKU-MOU-100', 1),
    ('SO-1002', 'SKU-KEY-100', 1),
    ('SO-1002', 'SKU-MON-100', 1),
    ('SO-1003', 'SKU-DSK-100', 1),
    ('SO-1003', 'SKU-MOU-100', 2),
    ('SO-1004', 'SKU-CHR-100', 1),
    ('SO-1005', 'SKU-CHR-100', 1),
    ('SO-1005', 'SKU-MON-100', 1)
) AS v(order_reference, sku, quantity)
JOIN app.orders o ON o.order_reference = v.order_reference
JOIN app.products p ON p.sku = v.sku
ON CONFLICT (order_id, product_id) DO NOTHING;

-- Inventory ledger starts from opening balances and records historical fulfilled sales.
-- The resulting net of movement deltas matches the current on-hand quantity per product.
INSERT INTO app.inventory_movements (product_id, delta_quantity, reason, reference_key, created_at)
SELECT p.product_id, v.opening_qty, 'Seed opening balance', 'seed:opening:' || v.sku, '2026-09-01 00:00:00+00'
FROM (VALUES
    ('SKU-KEY-100', 28),
    ('SKU-MOU-100', 41),
    ('SKU-MON-100', 10),
    ('SKU-DSK-100', 7),
    ('SKU-CHR-100', 12)
) AS v(sku, opening_qty)
JOIN app.products p ON p.sku = v.sku
ON CONFLICT (reference_key) DO NOTHING;

INSERT INTO app.inventory_movements (product_id, delta_quantity, reason, reference_key, created_at)
SELECT p.product_id, -v.quantity, 'Historical fulfilled order ' || v.order_reference,
       'seed:sale:' || v.order_reference || ':' || v.sku,
       CASE v.order_reference WHEN 'SO-1001' THEN '2026-09-05 10:30:00+00'::timestamptz ELSE '2026-09-16 14:00:00+00'::timestamptz END
FROM (VALUES
    ('SO-1001', 'SKU-KEY-100', 2),
    ('SO-1001', 'SKU-MOU-100', 1),
    ('SO-1002', 'SKU-KEY-100', 1),
    ('SO-1002', 'SKU-MON-100', 1)
) AS v(order_reference, sku, quantity)
JOIN app.products p ON p.sku = v.sku
ON CONFLICT (reference_key) DO NOTHING;

-- Refresh analytics after fixture records are present.
REFRESH MATERIALIZED VIEW app.mv_monthly_product_sales;
