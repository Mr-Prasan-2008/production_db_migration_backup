\set ON_ERROR_STOP on
-- Refresh in a normal transaction. Concurrent refresh requires a populated view
-- and a unique index covering all rows; this project creates that index in migration 004.
REFRESH MATERIALIZED VIEW app.mv_monthly_product_sales;
-- For minimal blocking during business hours, use this as a standalone statement instead:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY app.mv_monthly_product_sales;
