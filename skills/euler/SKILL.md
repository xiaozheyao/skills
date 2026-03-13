---
name: euler
description: Documentation and skills for the Euler HPC cluster at ETH Zürich (SLURM + Apptainer/Singularity). Use automatically when the user needs to connect to Euler, submit SLURM jobs, use containers, manage storage, or do anything on Euler infrastructure.
---

# Euler HPC Cluster — Skill

The full Euler documentation lives at: `${CLAUDE_PLUGIN_ROOT}/clusters/euler/`

Before performing **any** Euler task, read the relevant file(s) below first.
Do not guess at commands, flags, or paths — they are all documented there.

---

## Critical rules (read before anything else)

These rules are Euler-specific and differ from generic SLURM clusters:

1. **NEVER use `--partition`** — omit it entirely. Specifying a partition on Euler
   slows scheduling and provides no benefit.
2. **Do NOT constrain GPU type** unless your code strictly requires it.
   Use `--gpus=1` (no type). Only use `--gpus=a100:1` etc. when absolutely necessary.
3. **`$SCRATCH` is auto-deleted after 15 days** without warning. Always copy
   important results to `$HOME` or group storage after a job completes.
4. **Compute nodes have no internet** by default. Add `module load eth_proxy`
   to any job script that downloads packages or pulls containers.
5. **No `sudo`, no root.** Use Apptainer containers for custom software.
6. **Build containers locally**, transfer the `.sif` file to Euler — you cannot
   build images on the cluster.
7. **Run `get-access` once** before using Apptainer. Verify with:
   `id | grep ID-HPC-SINGULARITY`
8. **Never run compute-heavy work on login nodes.** After SSH-ing in you are on a
   login node. Use `sbatch` for batch jobs or `srun --pty bash` for interactive
   compute sessions. See jobs.md for details.

---

## What to read for each task

### Connecting for the first time
Read: `${CLAUDE_PLUGIN_ROOT}/clusters/euler/connection.md`
- SSH hostname: `euler.ethz.ch`
- Requires ETH network or ETH VPN
- First login requires email verification code

### Submitting or managing SLURM jobs
Read: `${CLAUDE_PLUGIN_ROOT}/clusters/euler/jobs.md`
- Euler custom commands: `myjobs`, `my_share_info`, `get_inefficient_jobs`
- GPU SLURM identifiers (a100, rtx_4090, etc.)
- Job arrays, dependencies, interactive sessions

### Using containers (Apptainer / Singularity)
Read: `${CLAUDE_PLUGIN_ROOT}/clusters/euler/containers.md`

> **This is the PRIMARY way to run custom or complex software on Euler.**
> Default to containers over Conda whenever possible.

Key points from that file:
- `apptainer exec --nv --bind $SCRATCH:/scratch <image>.sif <cmd>`
- Always bind `$SCRATCH` and `$TMPDIR` or paths will be invisible inside the container
- `--nv` is mandatory for GPU access inside the container
- Set in `~/.bashrc`:
  ```
  export APPTAINER_CACHEDIR="$SCRATCH/.apptainer"
  export APPTAINER_TMPDIR="${TMPDIR:-/tmp}"
  ```
- Store `.sif` files in `$HOME/containers/` — NOT in the Apptainer cache dir

### Managing storage
Read: `${CLAUDE_PLUGIN_ROOT}/clusters/euler/storage.md`

| Path | Quota | Purged | Use for |
|------|-------|--------|---------|
| `$HOME` | 50 GB | Never | Code, configs, final results |
| `$SCRATCH` | 2.5 TB | **After 15 days** | Job I/O, datasets, checkpoints |
| `$TMPDIR` | Node-local | Job end | High-throughput node-local I/O |
| `/cluster/project/<group>` | Shareholder | Never | Long-term group data |
| `/cluster/work/<group>` | Shareholder | Never | Large group I/O |

Check quotas with: `lquota`

### Loading software / modules
Read: `${CLAUDE_PLUGIN_ROOT}/clusters/euler/software.md`
- No stack loaded at login — always run `module load stack/2025-06` first
- `module load eth_proxy` for internet access on compute nodes
- Prefer containers over Conda (Lustre + many small files = bad)

---

## Job script templates

Ready-to-use job scripts are in `${CLAUDE_PLUGIN_ROOT}/clusters/euler/examples/`:

| File | Purpose |
|------|---------|
| `apptainer-gpu-job.sh` | GPU training job inside an Apptainer container |
| `apptainer-array-job.sh` | Job array / hyperparameter sweep inside a container |

When writing a new job script for Euler, start from one of these templates.

---

## Quick reference

```bash
# Connect
ssh <ETH_USERNAME>@euler.ethz.ch

# Check quotas
lquota

# Submit a job
sbatch my_job.sh

# Monitor jobs (Euler-native, preferred over squeue)
myjobs
myjobs -j <JOBID>

# Check shareholder groups
my_share_info

# Enable Apptainer (one-time)
get-access

# Run a command inside a container (with GPU)
apptainer exec --nv \
    --bind $SCRATCH:/scratch \
    --bind $TMPDIR:/tmp \
    ~/containers/my_image.sif \
    python3 train.py
```
