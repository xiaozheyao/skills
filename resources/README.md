# Resources

This directory contains skills for accessing shared infrastructure resources — storage systems, databases, and internal services — that are available across clusters or independently.

---

## Index

| Directory | Type | Description |
|-----------|------|-------------|
| [`storage/`](storage/README.md) | Filesystems & Object Storage | NFS mounts, Lustre, S3-compatible storage, and data transfer patterns |
| [`databases/`](databases/README.md) | Databases | Connection details, credentials, and common query patterns |
| [`services/`](services/README.md) | Internal APIs & Services | HTTP APIs, microservices, and other networked services |

---

## How to Use

1. Identify the resource category you need from the table above.
2. Open that directory's `README.md` for an index of specific resources.
3. Each individual resource has its own document covering:
   - **Access** — how to connect or mount
   - **Authentication** — credentials, tokens, SSH keys, or IAM roles
   - **Common operations** — read, write, query patterns
   - **Gotchas** — known limitations, quotas, or caveats

---

## Adding a New Resource

1. Place the new skill file in the appropriate subdirectory (`storage/`, `databases/`, or `services/`).
   - If none of the existing categories fit, create a new subdirectory here.
2. Name the file descriptively, e.g. `postgres-prod.md` or `s3-datasets.md`.
3. Update the subdirectory's `README.md` to include the new entry.
4. Update the table in this file if a new subdirectory is added.