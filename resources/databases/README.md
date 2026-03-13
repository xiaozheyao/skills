# Databases

This directory contains skills for connecting to and querying databases available across the infrastructure.

---

## Index

> Add a row here each time a new database is documented.

| File | Database | Type | Environment |
|------|----------|------|-------------|
| _(none yet)_ | | | |

---

## How to Use

1. Find the database you need in the table above.
2. Open the corresponding skill file for connection details, credentials, and common query patterns.
3. Never hardcode credentials — use the documented environment variables or secrets manager.

---

## What Each Skill File Covers

Each database skill document should include:

| Section | Content |
|---------|---------|
| **Overview** | What this database stores and who uses it |
| **Access** | Hostname, port, and network requirements (VPN, SSH tunnel, etc.) |
| **Authentication** | How credentials are stored and how to load them |
| **Connection examples** | CLI and programmatic connection snippets |
| **Common queries** | Frequently used queries / data access patterns |
| **Schema notes** | Key tables, fields, or collections to know about |
| **Gotchas** | Read replicas, connection limits, timeouts, etc. |

---

## Supported Database Types

Skills in this directory may cover any of the following:

- **Relational** — PostgreSQL, MySQL, SQLite
- **Document** — MongoDB, CouchDB
- **Key-value / Cache** — Redis, Memcached
- **Column-store** — Cassandra, ClickHouse
- **Time-series** — InfluxDB, TimescaleDB
- **Search** — Elasticsearch, OpenSearch
- **Data warehouses** — BigQuery, Redshift, Snowflake

---

## Adding a New Database

1. Create a new file in this directory named `<database-name>.md` (e.g. `postgres-prod.md`, `redis-cache.md`).
2. Use the section structure described in the table above.
3. Use `<ANGLE_BRACKETS>` for any value that varies per user or environment (hostnames, ports, usernames).
4. Store credentials via environment variables — document the variable names, never the values.
5. Update the index table at the top of this file.