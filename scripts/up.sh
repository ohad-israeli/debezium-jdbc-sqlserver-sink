#!/usr/bin/env bash
# One-shot: validate Confluent Cloud creds, bring up Connect + the two SQL Servers,
# set up databases, register connectors, verify.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Preflight (.env + Confluent Cloud connectivity)"
"$ROOT/scripts/preflight.sh"

echo "==> Preparing connector plugins (host-side download of the Debezium JDBC sink)..."
"$ROOT/scripts/prepare-plugins.sh"

echo "==> Starting containers (Kafka Connect + 2 SQL Servers)..."
docker compose up -d

echo "==> Waiting for SQL Servers + Kafka Connect to become healthy..."
for svc in sqlserver-source sqlserver-target kafka-connect; do
  printf "    %s " "$svc"
  for i in $(seq 1 80); do
    status="$(docker inspect -f '{{.State.Health.Status}}' "$svc" 2>/dev/null || echo starting)"
    if [ "$status" = "healthy" ]; then echo "healthy"; break; fi
    printf "."; sleep 5
    [ "$i" = 80 ] && { echo " timed out"; echo "   check: docker compose logs $svc"; exit 1; }
  done
done

echo "==> Setting up databases..."
"$ROOT/scripts/setup-databases.sh"

echo "==> Registering connectors..."
"$ROOT/scripts/register-connectors.sh"

echo "==> Waiting for the sink to drain the snapshot..."
sleep 25

echo "==> Verifying replication..."
"$ROOT/scripts/verify.sh"

cat <<'EOF'

Done. Kafka, Schema Registry, and the UI are in Confluent Cloud:
  Console      https://confluent.cloud  (Cluster → Topics / Connect → your topics)
  Connect REST http://localhost:8083/connectors   (the self-managed worker)

Try a live change, then re-run scripts/verify.sh:
  docker exec sqlserver-source /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa \
    -P 'YourPassword123!' -C -d SourceDB \
    -Q "INSERT INTO dbo.TBL_AG_TEST4 (col2,col3,col4,col6,APP_OR_DEB) VALUES (999,GETDATE(),'Live','Type9',1);"

Tear down with:  docker compose down -v
EOF
