# Migration Strategy

## Versioning convention

Migrations are numbered and immutable after shared deployment:

1. `001_core_schema`: tables, keys, checks, and supporting indexes.
2. `002_audit_logging`: append-oriented audit ledger, event function, and row triggers.
3. `003_business_procedures`: updated-at triggers and inventory/order procedures.
4. `004_reporting_views`: order summary and monthly sales materialized view.

Each version has an `.up.sql` and `.down.sql`. Up scripts register a version in `app.schema_migrations` after successful DDL. The `scripts/run_all_up.sql` runner applies them in ascending order and skips migration versions that are already recorded. Down scripts are run in reverse order; the final `001` down script drops the whole `app` schema.

## Safe change workflow

1. Create a new numbered migration; do not rewrite an applied migration.
2. Test the migration and its down script on a disposable copy before review.
3. Back up the target database, review locks and table rewrites, then deploy during an approved window.
4. Apply with `psql -v ON_ERROR_STOP=1 -f ...`; retain timestamped output in a deployment record.
5. Verify `app.schema_migrations`, constraints, key views, application smoke tests, and logs.
6. Use a down migration only when the rollback is safe for current data. Many production changes need a forward-fix migration rather than a destructive rollback.

The runner depends on `psql` features such as `\\ir`, `\\if`, and `\\gset`; execute it with psql. For a team production system, migration orchestration and locking should be integrated into the delivery pipeline so two deployments cannot migrate the same database simultaneously.
