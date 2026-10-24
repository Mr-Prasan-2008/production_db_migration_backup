# GitHub Setup

1. Extract `production_db_migration_backup.zip`.
2. Open PowerShell in the `production_db_migration_backup` folder containing `README.md`.
3. Create an empty GitHub repository, for example `production-db-migrations-backup-capstone`.
4. Run:

   ```powershell
   git init
   git add .
   git status
   git commit -m "Add production database migration and backup capstone"
   git branch -M main
   git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPOSITORY.git
   git push -u origin main
   ```

5. Replace the example URL with the URL of your own empty repository.
6. Confirm backups, passwords, database dumps, and logs do not appear in `git status` before committing. The `.gitignore` excludes backup artifacts by default.

Keep the README concise on the repository landing page; use `docs/` for the architecture, migration policy, and disaster-recovery plan.
