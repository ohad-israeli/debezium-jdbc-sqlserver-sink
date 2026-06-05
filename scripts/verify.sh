#!/usr/bin/env bash
# Show source vs. target rows so you can confirm the IDENTITY values replicated.
set -euo pipefail
SA_PASS="YourPassword123!"
q() { # <container> <db> <query>
  docker exec "$1" /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$SA_PASS" -C -d "$2" -Q "$3"
}

echo "== SOURCE (SourceDB.dbo.TBL_AG_TEST4) =="
q sqlserver-source SourceDB "SELECT col1, col2, col4 FROM dbo.TBL_AG_TEST4 ORDER BY col1;"

echo
echo "== TARGET (TargetDB.dbo.TBL_AG_TEST4) =="
q sqlserver-target TargetDB "SELECT col1, col2, col4 FROM dbo.TBL_AG_TEST4 ORDER BY col1;"

echo
echo "If the target shows the same col1 values (1, 11, 21, 31, 41), the identity"
echo "primary key replicated correctly via the JDBC sink."
