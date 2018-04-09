#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-'EOSQL'
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'project';
    DROP DATABASE IF EXISTS project;
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'project') THEN
            CREATE USER project WITH LOGIN PASSWORD 'project' CREATEDB;
        END IF;
    END
    $$;
    CREATE DATABASE project OWNER project;
    GRANT ALL PRIVILEGES ON DATABASE project TO project;
    \c project;
    CREATE EXTENSION "uuid-ossp";
    \q
EOSQL