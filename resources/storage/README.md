# Storage Resources

This directory contains skills for accessing and working with storage systems available across the infrastructure — shared filesystems, object storage, and data transfer utilities.

---

## Index

> Add a row to this table each time a new storage resource is documented.

| File / Directory | Type | Description |
|-----------------|------|-------------|
| _(none yet)_ | | |

---

## Storage Types

### Shared Filesystems

Network-attached filesystems that are mounted on login and compute nodes. Used for home directories, project data, and scratch space.

Common technologies: **NFS**, **Lustre**, **GPFS / Spectrum Scale**, **BeeGFS**

Key properties to document per filesystem:
- Mount path (e.g. `/home`, `/scratch/<username>`, `/project/<name>`)
- Quota (capacity and inode limits)
- Backup policy (backed up vs. scratch/no backup)
- Performance characteristics (metadata-heavy vs. large sequential I/O)
- Accessible from which clusters / nodes

### Object Storage

S3-compatible or proprietary blob storage for large datasets, model checkpoints, and pipeline artifacts.

Common technologies: **AWS S3**, **MinIO**, **Ceph RGW**, **Azure Blob Storage**, **GCS**

Key properties to document per bucket / endpoint:
- Endpoint URL
- Bucket name(s) and layout conventions
- Authentication method (IAM role, access key, instance profile)
- Region / data locality
- Retention and lifecycle policies

### Local / Node-Local Storage

Ephemeral storage on compute nodes (e.g. `/tmp`, `/local`, NVMe scratch). Fast but not shared — data is lost when the job ends.

---

## General Conventions

- **Scratch is not backed up.** Always copy important results to persistent storage before your job ends or your allocation expires.
- **Check quotas before large transfers** to avoid failed jobs mid-run.
- **Prefer `rsync` over `cp` for large transfers** — it is resumable and checksums data.
- Use the `$TMPDIR` environment variable (set by SLURM) for node-local temporary storage inside jobs.

---

## Useful Commands

```bash
# Check your disk usage and quota on a POSIX filesystem
quota -s
df -h <MOUNT_PATH>

# Check usage for a directory
du -sh <PATH>

# List object storage buckets (AWS CLI / s3cmd)
aws s3 ls
s3cmd ls

# Copy a file to S3-compatible storage
aws s3 cp <LOCAL_FILE> s3://<BUCKET>/<KEY>

# Sync a directory to S3
aws s3 sync <LOCAL_DIR>/ s3://<BUCKET>/<PREFIX>/

# Sync from cluster to local via rsync
rsync -avh <CLUSTER_ALIAS>:<REMOTE_PATH>/ <LOCAL_PATH>/
```

---

## Adding a New Storage Resource

1. Create a new markdown file in this directory named after the resource (e.g. `lustre-scratch.md`, `s3-datasets.md`).
2. Include the following sections in the file:
   - **Overview** — type, location, and intended use
   - **Access** — mount path or endpoint URL
   - **Authentication** — how credentials are obtained and configured
   - **Quotas and Limits** — capacity, inode, and bandwidth limits
   - **Common Operations** — read, write, sync examples
   - **Gotchas** — known issues, performance tips, retention policies
3. Register the new file in the index table at the top of this document.