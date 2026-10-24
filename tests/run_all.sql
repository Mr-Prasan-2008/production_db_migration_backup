\set ON_ERROR_STOP on
\echo '=== Production database migration and backup capstone: demo verification ==='
\ir ../scripts/run_all_up.sql
\ir ../fixtures/001_seed_data.sql
\ir verify_database.sql
\ir verify_audit.sql
\ir verify_procedures.sql
\echo '=== Demo schema, fixture, audit, procedure, and view checks finished ==='
