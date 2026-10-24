# Database Architecture

## Logical model

- `app.customers`: customer identity and contact email.
- `app.products`: product catalog and current list price.
- `app.inventory`: one current stock balance per product (`product_id` is both PK and FK).
- `app.orders`: customer order header and lifecycle status.
- `app.order_items`: order line items; `line_total` is generated from quantity and the price captured on the line.
- `app.inventory_movements`: immutable-style signed stock ledger events with optional idempotency key.
- `app.audit_log`: JSON snapshots of row-level insert/update/delete events.
- `app.schema_migrations`: which versioned schema changes have been applied.

`app.v_order_summary` supports operational queries. `app.mv_monthly_product_sales` pre-aggregates monthly revenue and units for fulfilled orders; refresh it after data changes according to your freshness target.

## Integrity and operational behavior

- Primary/foreign keys protect entity relationships. Order-item rows cascade when an order is deleted; product/customer references are restricted to avoid silently deleting commercial history. Product primary-key updates cascade through dependent tables.
- `CHECK` constraints reject invalid prices, quantities, statuses, and stock balances.
- `app.adjust_inventory` locks the inventory row and records a movement as part of the same transaction.
- `app.fulfill_order` locks the order and sorted inventory rows, verifies availability, updates stock and movement ledger, then marks the order fulfilled. An exception aborts the call's transaction and does not leave a partial fulfillment when called normally.
- Row-level audit triggers run inside the caller's transaction; audit rows roll back if the data change rolls back. This is transactional audit history, not tamper-proof external compliance logging. Restrict write access to audit objects in a real deployment.

## Production hardening to consider

Use least-privilege roles rather than connecting apps as the database owner; grant only required `EXECUTE` privileges on procedures. Add TLS, secret management, monitoring, alerting, encrypted off-site backup replication, tested retention policy, PITR/WAL archiving where required, and a defined RPO/RTO. Consider partitioning the audit ledger if growth warrants it, protect sensitive row snapshots, and define an audit retention policy before using real personal data.
