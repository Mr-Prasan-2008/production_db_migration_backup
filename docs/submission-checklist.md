# Submission Checklist

- [ ] `README.md` explains what the project does and how to run it.
- [ ] Four migrations have matching up/down scripts and migration tracking.
- [ ] Audit trigger function and audit table are documented.
- [ ] Stored procedures validate stock and lock affected rows.
- [ ] Ordinary and materialized views exist; refresh behavior is documented.
- [ ] Synthetic fixtures are repeatable.
- [ ] Local SQL verification completes with exit code 0 and PASS notices.
- [ ] Backup archive and checksum verification have been run locally.
- [ ] Restore rehearsal was performed against a separate database and checked.
- [ ] Actual terminal output and recovery measurements are recorded honestly.
- [ ] GitHub repository excludes secrets and dump files.
- [ ] Any production-specific RPO/RTO, off-site replication, encryption, and PITR requirements have been reviewed with the responsible team.
