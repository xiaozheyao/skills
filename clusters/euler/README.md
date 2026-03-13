# Euler Cluster

Euler is ETH Zürich's central HPC cluster, managed by Scientific IT Services. It is a shared resource available to all ETH members and affiliated external users.

- **Official docs:** https://docs.hpc.ethz.ch/
- **SLURM web GUI:** https://slurm-jobs-webgui.euler.hpc.ethz.ch/
- **Status page:** https://docs.hpc.ethz.ch/ (top banner)
- **Support / tickets:** https://smartdesk.ethz.ch

---

## Cluster Facts

| Property | Value |
|---|---|
| Login hostname | `euler.ethz.ch` (load-balanced across 50 login nodes) |
| OS | Ubuntu (64-bit) |
| Scheduler | SLURM 25.05 |
| Container runtime | **Apptainer 1.4** (formerly Singularity) — requires `get-access` |
| Module system | Lmod (Lua-based), hierarchical |
| Home directory | `/cluster/home/<username>` (`$HOME`) |
| Scratch directory | `/cluster/scratch/<username>` (`$SCRATCH`) |
| Network access | ETH network or ETH VPN required |

---

## ⚠️ Login Nodes Are Not for Computation

> **Never run compute-heavy work on a login node. Always use a compute node.**

When you SSH into Euler you land on one of 50 shared login nodes. These nodes have limited CPU and RAM and are shared by all users simultaneously. They exist only for file management, editing, and job submission.

**Do not run on a login node:**
- Training runs or model inference
- Data preprocessing or transformation scripts
- Large compilations
- Any script expected to run for more than a few seconds or consume significant CPU/memory

**Always dispatch work to a compute node:**

```bash
# Batch job (preferred for all production workloads)
(remote) $ sbatch my_job.sh

# Interactive compute session (for debugging/exploration)
(remote) $ srun --ntasks=1 --cpus-per-task=1 --mem-per-cpu=4G --time=01:00:00 --pty bash
```

Violating this rule degrades the cluster for all users and may result in your process being killed or your account being flagged by ETH HPC support.

---

## Contents

| File | What it covers |
|------|----------------|
| [connection.md](connection.md) | SSH access, VPN, SSH keys, first-time login, file transfer |
| [jobs.md](jobs.md) | Submitting, monitoring, and managing SLURM jobs on Euler |
| [storage.md](storage.md) | All storage types: Home, Scratch, Project, Work, Tmp |
| [containers.md](containers.md) | **Apptainer/Singularity — primary way to run custom software** |
| [software.md](software.md) | Module system, software stacks, `eth_proxy`, Python/Conda |
| [examples/](examples/) | Ready-to-use job scripts |

---

## Quick Reference

### Connecting

```bash
$ ssh <ETH_USERNAME>@euler.ethz.ch
```

Must be on ETH network or connected to ETH VPN first.

### Submitting jobs

```bash
(remote) $ sbatch my_job.sh          # submit batch job
(remote) $ srun --pty bash           # interactive session
(remote) $ myjobs                    # human-friendly job list (Euler custom)
(remote) $ squeue --me               # standard SLURM queue view
(remote) $ scancel <JOBID>           # cancel a job
```

### Storage paths

```bash
$HOME     = /cluster/home/<username>       # 50 GB, backed up
$SCRATCH  = /cluster/scratch/<username>    # 2.5 TB, deleted after 15 days
$TMPDIR   = /tmp                           # node-local, gone when job ends
lquota                                     # check your quota
```

### Containers (Apptainer / Singularity)

```bash
# One-time setup: enable container access
(remote) $ get-access

# Run a command inside a container
(remote) $ apptainer exec --bind $SCRATCH:/scratch my_image.sif python train.py

# GPU container
(remote) $ apptainer exec --nv --bind $SCRATCH:/scratch my_image.sif python train.py
```

> See [containers.md](containers.md) — this is the **recommended way** to run custom or complex software on Euler.

---

## Critical Euler-Specific Rules

> **Read these before submitting any job. They differ significantly from generic SLURM clusters.**

### 1. Do NOT specify `--partition`

Euler manages partitions internally. Specifying a partition **slows down job scheduling** and offers no benefit to users. Leave it out entirely.

```bash
# WRONG on Euler:
#SBATCH --partition=gpu

# CORRECT on Euler: omit the partition line entirely
```

### 2. Do NOT specify GPU/CPU types unless strictly required

Only request specific GPU types (e.g. `--gpus=a100:1`) if your code genuinely requires that exact hardware. Unnecessarily constraining GPU type reduces the pool of eligible nodes and increases wait time.

### 3. Login nodes are not for computation

> **See the [⚠️ Login Nodes Are Not for Computation](#️-login-nodes-are-not-for-computation) section above — this is a hard rule.**

50 login nodes share CPU and RAM across all connected users simultaneously. Do not run experiments, training, data processing, or any compute-heavy work on login nodes. Use `sbatch` for batch jobs or `srun --pty bash` for interactive compute sessions instead.

### 4. Scratch is deleted after 15 days — automatically, without warning

Files in `$SCRATCH` older than 15 days are purged. Copy important outputs to `$HOME` or group storage before the deadline. Do not try to `touch` files to reset the timer — this is a policy violation.

### 5. No `sudo`, no root

You cannot install system packages. Use:
- **Apptainer/Singularity** containers (recommended for complex environments)
- **Conda / virtualenv** in your home or scratch
- The **module system** for pre-installed software

### 6. Build containers locally, not on Euler

Container image creation requires root privileges. Build your `.sif` files on your local machine, then `rsync` them to Euler. See [containers.md](containers.md).

### 7. GPU nodes require shareholder membership

GPU nodes (except the AMD MI300A APUs, which are open to all during evaluation) are only accessible to members of shareholder groups. Contact your PI or group admin.

### 8. Internet access from compute nodes requires `eth_proxy`

Compute nodes do not have direct internet access by default.

```bash
module load eth_proxy
```

Load this module in your job script whenever you need to download packages, pull containers from Docker Hub, etc.

### 9. Jobs inherit your current environment

Unlike some clusters, Euler jobs inherit the environment of the shell that submitted the job. Load modules and set variables explicitly in the script with `module purge` first to ensure reproducibility.

---

## Euler-Specific SLURM Commands

| Command | Purpose |
|---|---|
| `myjobs` | Human-friendly view of your jobs (better than `squeue`) |
| `myjobs -j <JOBID>` | Detailed info for a specific job |
| `my_share_info` | List your shareholder groups |
| `get_inefficient_jobs` | Find jobs wasting CPU/GPU/RAM |
| `lquota` | Check storage quotas |
| `get-access` | Request access to Apptainer/Singularity |

---

## Hardware at a Glance

### GPU Nodes (shareholder-only, except MI300A)

| GPU | GPUs/Node | VRAM | SLURM identifier |
|---|---|---|---|
| NVIDIA RTX 4090 | 8 | 24 GB | `rtx_4090` |
| NVIDIA RTX 3090 | 8 | 24 GB | `rtx_3090` |
| NVIDIA Tesla A100 | 8–10 | 40 or 80 GB | `a100` / `a100_80gb` |
| NVIDIA TITAN RTX | 8 | 24 GB | `nvidia_titan_rtx` |
| NVIDIA Quadro RTX 6000 | 8 | 24 GB | `rtx_6000` |
| NVIDIA RTX 2080 Ti | 8 | 11 GB | `rtx_2080` |
| NVIDIA RTX PRO 6000 | 8 | 96 GB | `pro_6000` (CUDA 13+ only) |
| AMD MI300A APU | 4 | 128 GB (shared HBM3) | `mi300a` |

### Storage

| Name | Path | Size | Deleted after | Backed up |
|---|---|---|---|---|
| Home | `$HOME` | 50 GB | Never (until ETH account deleted) | Yes (nightly) |
| Scratch | `$SCRATCH` | 2.5 TB | **15 days** | No |
| Project | `/cluster/project/<group>` | Shareholder | Never | Yes |
| Work | `/cluster/work/<group>` | Shareholder | Never | Yes |
| Tmp | `$TMPDIR` | Node-local | Job end | No |