#!/usr/bin/env bash
# Download the Debezium JDBC sink connector into ./connect-plugins/ on the HOST.
# It's distributed on Maven Central (not Confluent Hub), and the slim
# cp-kafka-connect image has no `tar`, so we extract here (the host has tar) and
# mount the folder into Connect's plugin path via docker-compose. The plugin
# archive already bundles the Microsoft SQL Server JDBC driver.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VER="3.2.6.Final"
DEST="$ROOT/connect-plugins/debezium-connector-jdbc"

if [ -f "$DEST/.installed-$VER" ]; then
  echo "Debezium JDBC connector $VER already present."
  exit 0
fi
echo ">> downloading Debezium JDBC connector $VER from Maven Central..."
mkdir -p "$ROOT/connect-plugins"
rm -rf "$DEST"
curl -fsSL "https://repo1.maven.org/maven2/io/debezium/debezium-connector-jdbc/$VER/debezium-connector-jdbc-$VER-plugin.tar.gz" \
  | tar -xz -C "$ROOT/connect-plugins/"
touch "$DEST/.installed-$VER"
echo "   installed into connect-plugins/debezium-connector-jdbc"
