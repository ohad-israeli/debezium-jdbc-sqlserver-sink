# debezium-jdbc-sqlserver-sink

A self-contained, runnable example of **SQL Server → SQL Server replication** using
[Debezium](https://debezium.io/): a Debezium **SQL Server CDC source** captures
changes, and the Debezium **JDBC sink** writes them to a second SQL Server —
including the table's **IDENTITY primary key**, handled natively by the sink's
`dialect.sqlserver.identity.insert` option (no custom connector required).

📝 Write-up: **https://ohad-israeli.github.io/projects/debezium-jdbc-sqlserver-sink**

## Architecture

```
SourceDB (SQL Server, CDC on)
   │  Debezium SQL Server source connector
   ▼
Kafka topic  sqlserver_source.SourceDB.dbo.TBL_AG_TEST4   (Avro + Schema Registry)
   │  Debezium JDBC sink connector  (insert.mode=upsert, identity insert ON)
   ▼
TargetDB (SQL Server)  →  dbo.TBL_AG_TEST4   (same rows, same identity values)
```

Everything is wired by `docker-compose.yml`. Kafka Connect installs **only** the
two Debezium connectors (`debezium-connector-sqlserver` and
`debezium-connector-jdbc`), the Avro converter, and the Microsoft SQL Server JDBC
driver.

## Requirements

- Docker + Docker Compose.
- ~8 GB of RAM free — this runs **two** SQL Server containers plus Kafka, Connect,
  Schema Registry, and a UI.
- The Debezium JDBC connector must be **v3.0.7+** for native SQL Server identity
  insert (the compose pulls `:latest`).

## Run it

```bash
./scripts/up.sh
```

That brings up the stack, creates the databases (CDC + seed data on the source),
registers both connectors, and prints the source vs. target rows. First run is slow
because Connect downloads the connector plugins.

Then watch a live change replicate:

```bash
docker exec sqlserver-source /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa \
  -P 'YourPassword123!' -C -d SourceDB \
  -Q "INSERT INTO dbo.TBL_AG_TEST4 (col2,col3,col4,col6,APP_OR_DEB) VALUES (999,GETDATE(),'Live','Type9',1);"

./scripts/verify.sh
```

Tear down (including volumes):

```bash
docker compose down -v
```

## What's where

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | Kafka (KRaft), Schema Registry, Kafka Connect, two SQL Servers, Kafka UI |
| `connectors/source-sqlserver.json` | Debezium SQL Server CDC source |
| `connectors/sink-jdbc-sqlserver.json` | Debezium JDBC sink (`dialect.sqlserver.identity.insert=true`) |
| `sql/01-source-setup.sql` | SourceDB + `TBL_AG_TEST4` (IDENTITY PK) + CDC + seed rows |
| `sql/02-target-setup.sql` | TargetDB + matching empty table |
| `scripts/up.sh` | One-shot: up → setup DBs → register connectors → verify |
| `scripts/verify.sh` | Print source vs. target rows |

## The key idea

The source table's primary key is an `IDENTITY` column. SQL Server normally rejects
inserts into identity columns, which is what makes "replicate a table including its
identity PK" awkward. The Debezium JDBC sink solves it natively: with
`"dialect.sqlserver.identity.insert": "true"` it wraps each write batch in
`SET IDENTITY_INSERT <table> ON/OFF`, so the exact source identity values land in
the target. Earlier this required a custom connector — it no longer does.

## Endpoints

- Kafka UI — http://localhost:8080
- Connect REST — http://localhost:8083/connectors
- Schema Registry — http://localhost:8081/subjects

## Notes

- Credentials are demo defaults (`sa` / `YourPassword123!`) — for local use only.
- `schema.evolution` is `none`: the target table must already match the source
  shape (it does here). Set it to `basic` to let the sink add missing columns.

## License

MIT — see [LICENSE](LICENSE).
