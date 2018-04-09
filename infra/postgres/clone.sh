#!/bin/bash
set -e

COMMAND=${1:-clone}
CLONE_NO=${2:-1}

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'project${CLONE_NO}';
    DROP DATABASE IF EXISTS project${CLONE_NO};
EOSQL

if [ "$COMMAND" = "clone" ]
then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE DATABASE project${CLONE_NO} WITH TEMPLATE project OWNER project;
        /*
        \c project${CLONE_NO}
        UPDATE config SET text_value='http://project${CLONE_NO}.local' WHERE name IN ('url', 'secure_url', 'application_url');
        \q
        */
EOSQL
fi