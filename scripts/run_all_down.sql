\set ON_ERROR_STOP on
\echo 'WARNING: rolling back all migrations removes all application data.'
\ir ../migrations/004_reporting_views.down.sql
\ir ../migrations/003_business_procedures.down.sql
\ir ../migrations/002_audit_logging.down.sql
\ir ../migrations/001_core_schema.down.sql
\echo 'All migrations rolled back; schema app no longer exists.'
