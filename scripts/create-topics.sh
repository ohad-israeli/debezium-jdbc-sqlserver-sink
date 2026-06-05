#!/usr/bin/env bash
# OPTIONAL. Pre-create the topics in Confluent Cloud, in case auto-creation is
# restricted on your cluster (Confluent Cloud sets replication factor itself).
# Requires the Confluent CLI (https://docs.confluent.io/confluent-cli) and
# `confluent login` + a selected environment/cluster.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v confluent >/dev/null 2>&1; then
  echo "Confluent CLI not found. Either install it, or create these topics in the"
  echo "Confluent Cloud Console (Topics → Add topic), 1 partition each:"
  echo "  - schema-changes.sourcedb"
  echo "  - sqlserver_source.SourceDB.dbo.TBL_AG_TEST4"
  exit 0
fi

for t in "schema-changes.sourcedb" "sqlserver_source.SourceDB.dbo.TBL_AG_TEST4"; do
  echo ">> creating topic: $t"
  confluent kafka topic create "$t" --partitions 1 || echo "   (already exists or skipped)"
done
