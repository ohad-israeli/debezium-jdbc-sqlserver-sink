#!/usr/bin/env bash
# Validate .env and Confluent Cloud connectivity BEFORE bringing the stack up,
# so failures are obvious and fast.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$ROOT/.env" ]; then
  echo "ERROR: $ROOT/.env not found. Copy .env.example to .env and fill it in."
  exit 1
fi
set -a; . "$ROOT/.env"; set +a

missing=0
for v in CC_BOOTSTRAP CC_API_KEY CC_API_SECRET CC_SR_URL CC_SR_API_KEY CC_SR_API_SECRET; do
  if [ -z "${!v:-}" ]; then echo "ERROR: $v is not set in .env"; missing=1; fi
done
[ "$missing" = 1 ] && exit 1

echo ">> Schema Registry auth check ($CC_SR_URL)..."
code="$(curl -s -o /dev/null -w '%{http_code}' -u "$CC_SR_API_KEY:$CC_SR_API_SECRET" "$CC_SR_URL/subjects" || true)"
if [ "$code" = "200" ]; then
  echo "   OK (HTTP 200)"
else
  echo "   ERROR: Schema Registry returned HTTP $code — check CC_SR_URL / CC_SR_API_KEY / CC_SR_API_SECRET"
  exit 1
fi

echo ">> Kafka bootstrap reachability ($CC_BOOTSTRAP)..."
host="${CC_BOOTSTRAP%%:*}"; port="${CC_BOOTSTRAP##*:}"
if nc -z -w 8 "$host" "$port" 2>/dev/null; then
  echo "   OK (TCP $host:$port reachable)"
else
  echo "   WARNING: could not open TCP to $host:$port (network/firewall?). Continuing."
fi

echo "Preflight passed."
