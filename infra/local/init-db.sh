#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    SELECT 'CREATE DATABASE platform_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'platform_db')\gexec
    SELECT 'CREATE DATABASE user_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'user_db')\gexec
    SELECT 'CREATE DATABASE docbridge_db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'docbridge_db')\gexec
EOSQL