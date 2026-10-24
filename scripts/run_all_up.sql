\set ON_ERROR_STOP on
\echo 'Applying migration 001: core schema'
\ir ../migrations/001_core_schema.up.sql
\echo 'Applying migration 002: audit logging'
\ir ../migrations/002_audit_logging.up.sql
\echo 'Applying migration 003: stored procedures and updated_at triggers'
\ir ../migrations/003_business_procedures.up.sql
\echo 'Applying migration 004: reporting views'
\ir ../migrations/004_reporting_views.up.sql
\echo 'All registered migrations are applied.'
