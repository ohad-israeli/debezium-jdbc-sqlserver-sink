# debezium-jdbc-sqlserver-sink

**Stop running your cloud on yesterday's data.** A runnable example of continuous,
exact replication from SQL Server to a cloud SQL Server, using Debezium CDC and
**Confluent Cloud** — including `IDENTITY` primary keys, with no custom connector.

📝 Write-up: **https://ohad-israeli.github.io/projects/debezium-jdbc-sqlserver-sink**

## What this demonstrates

- **Live replication via CDC.** Debezium captures changes through SQL Server's built-in
  Change Data Capture instead of polling tables, streams them through Confluent Cloud
  (Kafka + Schema Registry), and the Debezium JDBC sink writes them to the target.
- **Exact copies, identity keys included.** The source is seeded with non-contiguous keys
  (`1, 11, 21, 31, 41`); they arrive in the target unchanged.
- **Configuration only.** Two connectors, no pipeline code.

```
SQL Server (CDC) ──► Kafka Connect ──► Confluent Cloud ──► Kafka Connect ──► SQL Server
                     Debezium source   Kafka + Schema      Debezium JDBC    (Amazon RDS
                                       Registry            sink              in production)
```

Kafka and Schema Registry run in Confluent Cloud. Locally, `docker compose` runs the Kafka
Connect worker and two SQL Server containers that stand in for the source and target, so
the whole pipeline runs from a laptop. Pointing it at real databases is a matter of
connection strings.

## Quick start

You need Docker with ~6 GB RAM free, and a Confluent Cloud Kafka cluster with Schema
Registry enabled (bootstrap server, plus separate Kafka and Schema Registry API keys).

```bash
git clone https://github.com/ohad-israeli/debezium-jdbc-sqlserver-sink
cd debezium-jdbc-sqlserver-sink
cp .env.example .env      # add your Confluent Cloud bootstrap + API keys
./scripts/up.sh
```

`up.sh` checks connectivity, starts everything, seeds the source, registers both
connectors, and prints source vs. target rows. To watch a live change flow through, insert
a row on the source and run `./scripts/verify.sh`. Tear down with `docker compose down -v`.

## The key idea

Two settings in the sink make identity keys replicate exactly:

- **`dialect.sqlserver.identity.insert=true`** wraps each write batch in
  `SET IDENTITY_INSERT <table> ON/OFF`, so source values are inserted verbatim. Requires
  Debezium JDBC connector **v3.0.7+**.
- **`;replication=true`** on the sink's JDBC URL. The key is declared
  `IDENTITY(1,10) NOT FOR REPLICATION`, and SQL Server only honors an explicit identity
  value for such a column on a connection flagged as a replication connection. Without it,
  SQL Server silently re-generates the value and the keys drift apart.

`schema.evolution` is `none`, so the target table must already match the source shape.

## What's where

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Kafka Connect (→ Confluent Cloud) and the two SQL Servers |
| `connectors/source-sqlserver.json` | Debezium SQL Server CDC source |
| `connectors/sink-jdbc-sqlserver.json` | Debezium JDBC sink (identity insert on) |
| `sql/` | Source (CDC + seed) and target table definitions |
| `scripts/` | `up.sh` (bring-up), `verify.sh` (compare rows), `preflight.sh`, `prepare-plugins.sh`, `create-topics.sh` |

Credentials live in a gitignored `.env`; connector configs reference them as
`${env:...}` rather than embedding secrets.

## Troubleshooting

- **Topic creation errors** — your API key may lack topic permissions, or auto-create is
  off. Use a key with create/produce/consume rights, or run `scripts/create-topics.sh`.
- **`401` from Schema Registry** — it uses its own API key; check the `CC_SR_*` values.
- **Sink plugin not found** — re-run `scripts/prepare-plugins.sh` to download the Debezium
  JDBC sink (it isn't on Confluent Hub).
- **Identity values changed in the target** — confirm the sink URL still ends in
  `;replication=true`.

## License

MIT — see [LICENSE](LICENSE).
