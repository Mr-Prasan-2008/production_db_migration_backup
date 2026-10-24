\set ON_ERROR_STOP on
\echo 'Rolling back migration 001: this removes the entire app schema and its data.'
DROP SCHEMA IF EXISTS app CASCADE;
