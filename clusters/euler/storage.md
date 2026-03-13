# Euler — Storage

Euler provides five distinct storage tiers. Choosing the right one for each use case
is critical: using the wrong tier wastes quota, causes data loss, or degrades cluster
performance for everyone.

Official docs: https://docs.hpc.ethz.ch/hardware/storage/

---

## Quick-Reference Table

| Name    | Path                             | Env var    | Quota        | Files limit | Backed up | Auto-deleted   | Best for |
|---------|----------------------------------|------------|--------------|-------------|-----------|----------------|----------|
| Home    | `/cluster/home/<username>`       | `$HOME`    | 50 GB / user | 500 000     | Nightly   | On account deletion | Long-term personal files, code, configs |
| Scratch | `/cluster/scratch/<username>`    | `$SCRATCH` | 2.5 TB / user | 1 000 000  | **Never** | **After 15 days** | Job input/output data, checkpoints |
| Project | `/cluster/project/<groupname>`   | —          | Shareholder  | Shareholder | Multiple/week | Never     | Long-term group data, critical datasets |
| Work    | `/cluster/work/<groupname>`      | —          | Shareholder  | Shareholder | Multiple/week | Never     | High-I/O group data, large files |
| Tmp     | `/tmp`                           | `$TMPDIR`  | Node-local   | —           | **Never** | **Job end**       | Node-local scratch during a job |

> **Project and Work** are only accessible to members of a shareholder group.

---

## Checking Your Quota

```bash
# Show quota for Home and Scratch
lquota

# Show quota for a Project or Work share (must pass the path)
lquota /cluster/project/<groupname>
lquota /cluster/work/<groupname>

# Show disk usage of a directory
du -sh /cluster/scratch/$USER
```

Quotas are enforced with a **soft quota** (grace period of 1 week after breach) and a
**hard quota** (10 % above soft — writes are blocked immediately). Do not let jobs start
if your scratch is near the hard quota; they will fail mid-run.

---

## Tier Details

### Home — `/cluster/home/<username>` (`$HOME`)

- **Filesystem:** NFS v3, SSD (NVMe)
- **Quota:** 50 GB, 500 000 files/directories per user
- **Snapshots:** Hourly and daily (accessible via `.snapshot/`)
- **Backups:** Nightly tape backup
- **Deleted:** Only when your ETH account is closed

Use home for:
- Source code and scripts
- Configuration files (`.bashrc`, SSH keys, conda environments — but mind the 500 K file limit)
- Small reference datasets
- Final, important results that need to persist long-term

**Do NOT** use home for large job outputs or anything that should be written at high
throughput — it is an NFS mount and not suited for parallel I/O.

---

### Scratch — `/cluster/scratch/<username>` (`$SCRATCH`)

- **Filesystem:** Lustre, SSD (NVMe) — optimised for large parallel I/O
- **Quota:** 2.5 TB, 1 000 000 files/directories per user
- **Snapshots:** None
- **Backups:** **None**
- **Auto-deletion:** **Any file not accessed in 15 days is permanently deleted without warning**

```bash
# Always use the environment variable — it expands to the right path
echo $SCRATCH
# → /cluster/scratch/<your_username>

# Scratch is not listed in the parent directory; access it directly
ls $SCRATCH
```

#### Scratch usage rules (mandatory)

1. **Clean up promptly.** Delete files you no longer need. Scratch is a shared resource.
2. **15-day purge is strict.** Files (including directories) not accessed in 15 days are
   deleted automatically and silently. There is no warning.
3. **Do NOT manipulate timestamps** (e.g. `touch`) to circumvent the purge. Doing so can
   result in account suspension.
4. **Large files only.** Scratch (Lustre) is optimised for large sequential I/O. For
   workloads that generate many small files (e.g. Conda environments, Python caches),
   prefer Home or use a container / archive.
5. **Copy important results out.** After a job, copy results to Home or Project immediately.

Use scratch for:
- Job working directories
- Downloaded datasets
- Model checkpoints during training (copy the final one to Home/Project)
- Apptainer cache (`$SCRATCH/.apptainer`)

---

### Project — `/cluster/project/<groupname>`

- **Filesystem:** NFS v3, HDD with NVMe and SAS SSD caching
- **Quota:** Depends on shareholder purchase
- **Snapshots:** Hourly and daily
- **Backups:** Multiple times per week (90-day retention)
- **Auto-deletion:** Never
- **Access:** Shared by group members; requires shareholder membership

Use project for:
- Critical, long-term group datasets
- Reference data that jobs read from frequently
- Processed results that must be preserved

---

### Work — `/cluster/work/<groupname>`

- **Filesystem:** Lustre, HDD — optimised for large parallel I/O
- **Quota:** Depends on shareholder purchase
- **Snapshots:** None
- **Backups:** Multiple times per week
- **Auto-deletion:** Never
- **Access:** Shared by group members; requires shareholder membership

Use work for:
- Large files with high I/O requirements shared across jobs
- Intermediate datasets that are regeneratable but expensive to recompute

> **NOTE:** Lustre (Work/Scratch) is **not well-suited for Conda environments or any
> workload generating many small files.** This can cause severe metadata performance
> degradation. Use containers (Apptainer `.sif` files) instead.

---

### Tmp — `/tmp` (`$TMPDIR`)

- **Filesystem:** XFS, NVMe SSD — node-local, fastest available
- **Quota:** Depends on the compute node
- **Snapshots/Backups:** None
- **Auto-deletion:** When the Slurm job terminates

`$TMPDIR` is automatically created by Slurm and is private to your job — no conflicts
with other users on the same node. Request it in your job script with `--tmp=<size>`.

```bash
#!/bin/bash
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=4G
#SBATCH --time=02:00:00
#SBATCH --tmp=50G          # ← request 50 GB of node-local storage

# Stage input data to fast local storage
rsync -aq $SCRATCH/my_dataset/ $TMPDIR/dataset/

# Run the job from the local disk
cd $TMPDIR
python my_script.py --data dataset/

# Copy outputs back before job ends — TMPDIR is wiped after this
rsync -auq $TMPDIR/outputs/ $SCRATCH/results/
```

Use tmp for:
- I/O-intensive jobs that read/write many files (e.g. deep learning data loaders)
- Unpacking compressed archives for processing
- Any workload where inter-node communication latency matters

---

## Snapshots

Home and Project support filesystem snapshots. They are accessible from **any
subdirectory** — they are not listed, but can be entered directly:

```bash
cd ~/.snapshot          # or cd /cluster/project/<group>/.snapshot
ls                      # lists available snapshot timestamps
cp ./<timestamp>/my_lost_file.txt ~/recovered_file.txt
```

---

## Excluding Directories from Backup

To prevent large, regeneratable files from inflating backups, name the directory
`nobackup` anywhere in the path. Everything inside it (recursively) is excluded:

```bash
mkdir -p /cluster/work/<group>/experiments/nobackup
# Files inside nobackup/ are not backed up
```

---

## Recommended Patterns

### Pattern 1 — Standard job using Scratch

```bash
# In your job script:
WORKDIR=$SCRATCH/runs/$SLURM_JOB_ID
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ... do work, write outputs to $WORKDIR ...

# After job: copy final artefacts to Home
cp -r "$WORKDIR/checkpoints/best.pt" "$HOME/models/"
```

### Pattern 2 — I/O-intensive job using Tmp

```bash
# In your job script:
#SBATCH --tmp=100G

rsync -aq $SCRATCH/dataset/ $TMPDIR/dataset/
python train.py --data-dir $TMPDIR/dataset --output-dir $TMPDIR/out
rsync -auq $TMPDIR/out/ $SCRATCH/results/$SLURM_JOB_ID/
```

### Pattern 3 — Apptainer cache placement

Add to your `~/.bashrc` so the Apptainer image cache never fills your Home quota:

```bash
export APPTAINER_CACHEDIR="$SCRATCH/.apptainer"
export APPTAINER_TMPDIR="${TMPDIR:-/tmp}"
```

> **WARNING:** The Apptainer cache lives in Scratch and is subject to the 15-day purge.
> If a cached image is deleted, Apptainer will re-pull it on next use. Store your primary
> `.sif` files in Home or Project, not in the cache directory.

---

## Data Transfer

### rsync (recommended for large transfers)

```bash
# Local → Scratch (dry-run first)
rsync -avhn local/data/ euler.ethz.ch:/cluster/scratch/$USER/data/

# Run for real
rsync -avh local/data/ euler.ethz.ch:/cluster/scratch/$USER/data/

# Scratch → local
rsync -avh euler.ethz.ch:/cluster/scratch/$USER/results/ ./results/
```

### scp

```bash
scp local_file.tar.gz <username>@euler.ethz.ch:/cluster/scratch/$USER/
scp <username>@euler.ethz.ch:/cluster/scratch/$USER/result.tar.gz .
```

### Globus

For transfers in the terabyte range, use Globus (ETH has a Globus endpoint).
Contact cluster support for assistance with very large transfers.

---

## Common Pitfalls

| Pitfall | Consequence | Prevention |
|---------|-------------|------------|
| Writing job outputs to `$HOME` | Home fills up (50 GB); jobs fail | Always use `$SCRATCH` for job I/O |
| Leaving large files in Scratch | Fills 2.5 TB quota; blocks new jobs | Clean up promptly; copy keepers to Home |
| Not copying results before 15 days | Results permanently deleted | Copy to Home/Project immediately after job |
| Conda env in Work/Scratch (Lustre) | Thousands of small files → metadata slowdown | Use Apptainer containers instead |
| Storing `.sif` container images in cache dir | Image purged after 15 days | Store `.sif` files in `$HOME` or Project |
| Not requesting `--tmp` | `$TMPDIR` may be very small | Always `#SBATCH --tmp=<N>G` if using tmp |