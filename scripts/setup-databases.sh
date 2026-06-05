#!/usr/bin/env bash
# Create the source/target databases, tables, CDC, and seed data by running the
# SQL files inside each SQL Server container.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SA_PASS="YourPassword123!"
SQLCMD=(/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASS" -C -b)

run_sql() { # <container> <sql-file>
  echo ">> $1: applying $(basename "$2")"
  docker cp "$2" "$1:/tmp/script.sql"
  docker exec "$1" "${SQLCMD[@]}" -i /tmp/script.sql
}

echo "== Source DB =="
run_sql sqlserver-source "$ROOT/sql/01-source-setup.sql"
echo "== Target DB =="
run_sql sqlserver-target "$ROOT/sql/02-target-setup.sql"
echo "Databases ready."
