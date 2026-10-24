# Backup / Restore Validation Checklist

Use this checklist after running the SQL demo in a local disposable database.

- [ ] Create the demo database and run `tests/run_all.sql`; confirm `psql` exits with code `0`.
- [ ] Run `scripts/backup.ps1`; confirm the `.dump`, `.dump.sha256`, and `.dump.log` files exist.
- [ ] Run `scripts/verify_backup.ps1`; capture the checksum and archive-list success messages.
- [ ] Create a separate empty restore database.
- [ ] Restore the archive with `scripts/restore.ps1` into that database.
- [ ] Verify `app.schema_migrations`, order status counts, inventory totals, `app.v_order_summary`, and the materialized view.
- [ ] Run one harmless read query and one controlled transaction that is rolled back.
- [ ] Record start/end timestamps, archive name, checksum, and any errors in your internship evidence.
- [ ] Confirm a backup from another failure domain can be accessed (only if your environment supports off-site replication).

Do not write expected timing or recovery measurements into evidence until you have run those steps on your own system.
