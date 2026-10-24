# Backup and Disaster Recovery Guide

## Goals and assumptions

This capstone demonstrates logical backups with PostgreSQL's custom archive format. Choose service-specific targets for recovery point objective (RPO) and recovery time objective (RTO) before production use. A nightly `pg_dump` protects against some logical failures but does **not** provide point-in-time recovery (PITR) between dumps.

## Backup procedure (Windows)

From PowerShell at the repository root:

```powershell
.\scripts\backup.ps1 -DatabaseName production_capstone -BackupDirectory .\backups -RetentionDays 14
```

The script calls `pg_dump --format=custom`, writes a timestamped `.dump`, records a `.log` and SHA-256 sidecar, and removes local dumps older than the configured retention window after a successful new backup. Do not commit backup files to Git.

## Integrity verification

```powershell
.\scripts\verify_backup.ps1 -BackupFile .\backups\production_capstone_YYYYMMDD_HHMMSS.dump
```

Replace the sample name with the real backup file. This verifies the SHA-256 sidecar (if present) and asks `pg_restore --list` to read the archive. This does not prove that a full restore or application smoke test will succeed; only a restore rehearsal does that.

## Restore rehearsal / recovery

1. Confirm the file's origin, date, checksum, and access controls.
2. Create a separate empty target database. Do not practice on the source production database.

   ```powershell
   createdb -U postgres -h localhost -p 5432 production_capstone_restore
   .\scripts\restore.ps1 -DatabaseName production_capstone_restore -BackupFile .\backups\production_capstone_YYYYMMDD_HHMMSS.dump
   ```

3. Check migration history, table counts, important views, procedures, constraints, and a representative read/write transaction against the restored target.

   ```powershell
   psql -U postgres -h localhost -p 5432 -d production_capstone_restore -c "SELECT * FROM app.schema_migrations ORDER BY version;"
   psql -U postgres -h localhost -p 5432 -d production_capstone_restore -c "SELECT status, count(*) FROM app.orders GROUP BY status ORDER BY status;"
   ```

4. Record backup age, restore start/end times, errors, and validation outcome. Compare elapsed time against the target RTO.
5. Keep the original backup until the recovered environment is verified and the incident owner approves recovery.

For an intentional in-place restore, `scripts/restore.ps1 -CleanExistingObjects` prompts for confirmation and passes `pg_restore --clean --if-exists`. It can drop objects represented in the archive; prefer a fresh database for rehearsals.

## Operational controls

- Run a scheduled backup at a frequency justified by the RPO, and alert when a task fails, the dump is missing, checksums fail, or free disk space is low.
- Keep copies in a different account/region/failure domain, encrypt in transit and at rest, and test that emergency responders can retrieve them.
- Use Windows Task Scheduler under a dedicated least-privilege account. Configure `PGPASSFILE` or a secret manager for non-interactive jobs; do not hardcode passwords in scripts or commit `.pgpass`.
- Restrict access to backups: the dump can contain all application data and audit snapshots. Retention/deletion should follow legal and security requirements.
- `pg_dump` backs up one database, not cluster-wide roles/tablespaces. Separately document and securely back up global objects if required. Restore with compatible PostgreSQL tooling, and test version compatibility before major upgrades.
- For lower RPOs, evaluate base backups plus WAL archiving and PostgreSQL point-in-time recovery; this capstone does not configure PITR.
- Perform routine restore drills and capture evidence; a successful backup command alone is not proof of recoverability.
