#!/usr/bin/env bash
# One-shot: bring up the stack, set up databases, register connectors, verify.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Starting containers..."
docker compose up -d

echo "==> Waiting for SQL Server + Kafka Connect to become healthy..."
# Wait for the two SQL Servers and Connect to report healthy.
for svc in sqlserver-source sqlserver-target kafka-connect; do
  printf "    %s " "$svc"
  for i in $(seq 1 60); do
    status="$(docker inspect -f '{{.State.Health.Status}}' "$svc" 2>/dev/null || echo starting)"
    if [ "$status" = "healthy" ]; then echo "healthy"; break; fi
    printf "."; sleep 5
    [ "$i" = 60 ] && { echo " timed out"; exit 1; }
  done
done

echo "==> Setting up databases..."
"$ROOT/scripts/setup-databases.sh"

echo "==> Registering connectors..."
"$ROOT/scripts/register-connectors.sh"

echo "==> Waiting for the sink to drain the snapshot..."
sleep 20

echo "==> Verifying replication..."
"$ROOT/scripts/verify.sh"

cat <<'EOF'

Done. Useful endpoints:
  Kafka UI         http://localhost:8080
  Connect REST     http://localhost:8083/connectors
  Schema Registry  http://localhost:8081/subjects

Try a live change, then re-run scripts/verify.sh:
  docker exec sqlserver-source /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa \
    -P 'YourPassword123!' -C -d SourceDB \
    -Q "INSERT INTO dbo.TBL_AG_TEST4 (col2,col3,col4,col6,APP_OR_DEB) VALUES (999,GETDATE(),'Live','Type9',1);"

Tear everything down with:  docker compose down -v
EOF
