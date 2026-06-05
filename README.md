# debezium-jdbc-sqlserver-sink

A runnable example of **SQL Server → SQL Server replication on Confluent Cloud**: a
Debezium **SQL Server CDC source** captures changes, streams them through **Confluent
Cloud** (Kafka + Schema Registry), and the Debezium **JDBC sink** writes them to a
second SQL Server — including the table's **IDENTITY primary key**, handled natively
by the sink's `dialect.sqlserver.identity.insert` option (no custom connector).

📝 Write-up: **https://ohad-israeli.github.io/projects/debezium-jdbc-sqlserver-sink**

## Architecture

```
On-prem SQL Server (CDC)                Confluent Cloud                 Amazon RDS
        │                          ┌──────────────────────┐            for SQL Server
        ▼                          │  Kafka  +  Schema     │                 ▲
  Kafka Connect (self-managed) ───►│  Registry (Avro)      │──► Kafka Connect ┘
  Debezium SQL Server source       │  + Cloud Console UI   │    Debezium JDBC sink
                                    └──────────────────────┘    (identity insert)
```

Kafka, Schema Registry, and the UI all live in **Confluent Cloud**. Only the
self-managed **Kafka Connect** worker (hosting the two Debezium connectors) and the
**two SQL Servers** run locally via Docker — the SQL Servers stand in for an
on-premises source and an Amazon RDS target so you can run the whole thing on a
laptop. Pointing at a real on-prem source and RDS endpoint is just connection strings.

## Prerequisites

- Docker + Docker Compose, ~6 GB RAM free (two SQL Server containers + Connect).
- A **Confluent Cloud** account with:
  - a Kafka cluster (Basic is fine) → its **bootstrap server** + a **Kafka API key/secret**;
  - **Schema Registry** enabled (Stream Governance) → its **endpoint URL** + a **Schema Registry API key/secret**.

## Secrets (never committed)

All Confluent Cloud credentials live in a local **`.env`** file, which is
`.gitignore`d. Copy the template and fill it in:

```bash
cp .env.example .env
# edit .env with your CC bootstrap, Kafka API key/secret, SR URL, SR API key/secret
```

- `docker-compose.yml` reads `.env` to configure the Connect worker (SASL_SSL to CC).
- The connector configs in `connectors/*.json` reference secrets as
  `${env:CC_SR_API_KEY}` etc. via Kafka Connect's **env config provider** — so the
  committed JSON contains *references*, never the secret values, and the secrets are
  not written into Connect's stored config in plaintext.

## Run it

```bash
./scripts/up.sh
```

`up.sh` runs a **preflight** (validates `.env` and checks Schema Registry auth +
broker reachability), brings up Connect and the two SQL Servers, creates the
databases (CDC + seed data on the source), registers both connectors, and prints the
source vs. target rows. The source is seeded with non-contiguous identity values
(`1, 11, 21, 31, 41`) so it's obvious the exact keys replicate.

Watch a live change flow through:

```bash
docker exec sqlserver-source /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa \
  -P 'YourPassword123!' -C -d SourceDB \
  -Q "INSERT INTO dbo.TBL_AG_TEST4 (col2,col3,col4,col6,APP_OR_DEB) VALUES (999,GETDATE(),'Live','Type9',1);"
./scripts/verify.sh
```

Inspect topics, schemas, and connector activity in the **Confluent Cloud Console**.
Tear down with `docker compose down -v`.

## The key idea

The source table's primary key is an `IDENTITY` column, which SQL Server normally
won't let you insert into. The Debezium JDBC sink handles it natively: with
`"dialect.sqlserver.identity.insert": "true"` it wraps each write batch in
`SET IDENTITY_INSERT <table> ON/OFF`, so the exact source identity values land in the
target. Needs Debezium JDBC connector **v3.0.7+**.

## What's where

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Self-managed Kafka Connect (→ Confluent Cloud) + two SQL Servers |
| `.env.example` | Template for Confluent Cloud credentials (copy to `.env`) |
| `connectors/source-sqlserver.json` | Debezium SQL Server CDC source (Avro → CC Schema Registry) |
| `connectors/sink-jdbc-sqlserver.json` | Debezium JDBC sink (`dialect.sqlserver.identity.insert=true`) |
| `sql/01-source-setup.sql` / `02-target-setup.sql` | Source (CDC + seed) and target tables |
| `scripts/preflight.sh` | Validate `.env` + Confluent Cloud connectivity |
| `scripts/up.sh` | One-shot bring-up + verify |
| `scripts/create-topics.sh` | Optional: pre-create CC topics if auto-create is restricted |
| `scripts/verify.sh` | Print source vs. target rows |

## Troubleshooting

- **Connector fails creating internal/data topics** — your API key may lack topic
  permissions, or auto-create is off. Run `scripts/create-topics.sh` (or create the
  topics in the Console), and use an API key with topic create/produce/consume rights.
- **`401`/auth errors to Schema Registry** — the SR API key is separate from the
  Kafka API key; check `CC_SR_*` in `.env` (preflight will catch this).
- **`no suitable driver`** — the compose adds the MS SQL JDBC driver to the sink
  plugin; confirm that download step in `docker compose logs kafka-connect`.

## License

MIT — see [LICENSE](LICENSE).
