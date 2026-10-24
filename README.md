# Production Database Migration & Backup Strategy Capstone

A PostgreSQL 16-compatible capstone demonstrating versioned schema migrations, audit logging, stored procedures, reporting views, automated logical backups, restore verification, and disaster-recovery planning.

> **Scope note:** This is a production-minded learning project, not a claim that one SQL repository is sufficient for every production environment. Validate capacity, RPO/RTO, secrets management, monitoring, encryption, and restore procedures against your organisation's standards before using it with real data.

## Features

- Four ordered migrations with matching **up** and **down** scripts and an `app.schema_migrations` history table.
- `app.capture_audit_event()` trigger function that records row-level INSERT/UPDATE/DELETE snapshots in `app.audit_log`.
- Stored procedures `app.adjust_inventory(...)` and `app.fulfill_order(...)`, using row locks and server-side checks to protect stock balances.
- An ordinary order-summary view and a monthly product sales materialized view with a unique index for concurrent refresh.
- Repeatable synthetic seed fixtures and SQL verification scripts.
- PowerShell backup, archive verification, and restore scripts for Windows/PostgreSQL 16.
- Disaster recovery guide covering backup retention, recovery steps, verification, and limitations.

## Requirements

- PostgreSQL 14+ (developed for PostgreSQL 16.x).
- PostgreSQL command-line tools available in `PATH`: `psql`, `createdb`, `pg_dump`, and `pg_restore`.
- PowerShell 5.1+ on Windows for the backup/restore scripts. SQL migrations use `psql` meta-commands such as `\ir` and `\if`; run them with `psql`, not by pasting them into pgAdmin's query window.

## Quick start on Windows PowerShell

Run these commands from the extracted project folder (the folder containing this README):

```powershell
createdb -U postgres -h localhost -p 5432 production_capstone
psql -U postgres -h localhost -p 5432 -d production_capstone -v ON_ERROR_STOP=1 -f ".\tests\run_all.sql"
$LASTEXITCODE
```

A zero exit code indicates the `psql` process succeeded. The test scripts print `NOTICE: PASS` messages and stop on unexpected results. If the database already exists, do not run `createdb` again; run the `psql` command directly. The migration runner skips versions already recorded in `app.schema_migrations`, fixtures use conflict-safe inserts, and the analytics materialized view is refreshed by the test runner.

To inspect migration history and counts:

```powershell
psql -U postgres -h localhost -p 5432 -d production_capstone -c "SELECT * FROM app.schema_migrations ORDER BY version;"
psql -U postgres -h localhost -p 5432 -d production_capstone -c "SELECT 'customers' AS table_name, count(*) FROM app.customers UNION ALL SELECT 'products', count(*) FROM app.products UNION ALL SELECT 'orders', count(*) FROM app.orders UNION ALL SELECT 'order_items', count(*) FROM app.order_items UNION ALL SELECT 'inventory_movements', count(*) FROM app.inventory_movements;"
```

## Migrations

- `migrations/001_core_schema.up.sql` / `.down.sql`: base entities, foreign keys, checks, and indexes.
- `migrations/002_audit_logging.up.sql` / `.down.sql`: audit log, trigger function, and table triggers.
- `migrations/003_business_procedures.up.sql` / `.down.sql`: timestamp trigger and stock/order procedures.
- `migrations/004_reporting_views.up.sql` / `.down.sql`: reporting view and materialized analytics view.
- `scripts/run_all_up.sql`: applies migrations in order.
- `scripts/run_all_down.sql`: rolls them back in reverse dependency order. **This is destructive** and removes the `app` schema at the end; use only against a disposable database or after an approved change plan.

For an individual migration, run its `.up.sql` or `.down.sql` file with `psql -f`. The migration scripts are intentionally versioned and should be reviewed and tested before production deployment. Do not edit a migration after it has been applied in a shared environment; add a new migration instead.

## Backup and restore

Create a compressed custom-format logical backup and keep 14 days of local dumps:

```powershell
.\scripts\backup.ps1 -DatabaseName production_capstone -BackupDirectory .\backups -RetentionDays 14
```

Verify an archive and its SHA-256 sidecar:

```powershell
.\scripts\verify_backup.ps1 -BackupFile .\backups\production_capstone_YYYYMMDD_HHMMSS.dump
```

Restore into a **new, empty database** (recommended for a recovery test):

```powershell
createdb -U postgres -h localhost -p 5432 production_capstone_restore
.\scripts\restore.ps1 -DatabaseName production_capstone_restore -BackupFile .\backups\production_capstone_YYYYMMDD_HHMMSS.dump
psql -U postgres -h localhost -p 5432 -d production_capstone_restore -c "SELECT * FROM app.schema_migrations ORDER BY version;"
```

Replace the example dump filename with the actual file created by `backup.ps1`. The restore script requires the target database to exist. By default it restores into an empty target; `-CleanExistingObjects` can drop objects contained in the archive and should be used only when that is intended.

### Authentication and scheduling

The scripts do not store passwords. For interactive use, let libpq prompt for a password. For unattended jobs, configure a restricted PostgreSQL password file (`%APPDATA%\postgresql\pgpass.conf` on Windows) or another organisation-approved secret provider. Restrict ACLs on password files, backups, hash files, and logs. Configure Windows Task Scheduler to run `scripts/backup.ps1` daily and monitor task history, output files, disk space, and failures. A local backup alone is not disaster recovery: replicate encrypted backups to a separate failure domain.

## Test and evidence notes

`tests/run_all.sql` applies migrations, loads sample rows, refreshes the materialized view, then checks schema objects, seed data, audit behavior, inventory adjustment, rejected negative stock, and order fulfillment inside rollback-only test transactions. Those procedure tests roll back their changes, so the fixture stock and order states remain stable.

This repository is provided as source code. Execute it on your PostgreSQL installation and retain the actual output in your submission; no live server execution is claimed by this package alone.

## Suggested GitHub repository name

`production-db-migrations-backup-capstone`
