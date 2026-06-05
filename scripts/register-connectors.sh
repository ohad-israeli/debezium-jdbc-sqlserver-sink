#!/usr/bin/env bash
# Wait for Kafka Connect to load its plugins, then register the source and sink.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONNECT="http://localhost:8083"

echo ">> Waiting for the Debezium plugins to be installed (this can take a few minutes on first run)..."
for i in $(seq 1 60); do
  plugins="$(curl -s "$CONNECT/connector-plugins" || true)"
  if echo "$plugins" | grep -q "io.debezium.connector.jdbc.JdbcSinkConnector" \
     && echo "$plugins" | grep -q "io.debezium.connector.sqlserver.SqlServerConnector"; then
    echo "   plugins ready."
    break
  fi
  sleep 5
  [ "$i" = 60 ] && { echo "Timed out waiting for plugins."; exit 1; }
done

register() { # <json-file>
  local name; name="$(basename "$1")"
  echo ">> registering $name"
  curl -sS -X POST -H "Content-Type: application/json" \
    --data @"$1" "$CONNECT/connectors" | grep -o '"name":"[^"]*"' || true
}

register "$ROOT/connectors/source-sqlserver.json"
echo "   giving the source a moment to snapshot..."
sleep 15
register "$ROOT/connectors/sink-jdbc-sqlserver.json"

echo ">> connector status:"
sleep 5
for c in sqlserver-source sqlserver-jdbc-sink; do
  state="$(curl -s "$CONNECT/connectors/$c/status" | grep -o '"state":"[^"]*"' | head -1)"
  echo "   $c: ${state:-unknown}"
done
