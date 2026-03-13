# SLURM Cluster Skills

This directory contains skills for working with SLURM (Simple Linux Utility for Resource Management) based HPC clusters.

---

## ⚠️ Universal Rule — Never Run Compute on Login Nodes

> **This rule applies to every SLURM cluster, without exception.**

When you SSH into a cluster you land on a **login node**. Login nodes are shared gateways with limited CPU and RAM, used simultaneously by all connected users. They exist only for light tasks such as editing files, staging data, and submitting jobs.

**Never run any of the following on a login node:**
- Training runs, model inference, or any ML workload
- Data preprocessing or transformation scripts
- Compilation of large codebases
- Any script or command expected to run for more than a few seconds or consume significant CPU/memory

**Always dispatch work to a compute node:**

```bash
# Preferred — submit a batch job
(remote) $ sbatch my_job.sh

# For interactive debugging — open a shell on a compute node
(remote) $ srun --ntasks=1 --cpus-per-task=1 --mem-per-cpu=4G --time=01:00:00 --pty bash
```

Running heavy workloads on login nodes degrades the experience for every user and may result in your process being killed or your account being suspended by admins.

---

## Quick Reference

| Task | Command |
|------|---------|
| Submit a job | `sbatch <script.sh>` |
| List your running jobs | `squeue -u $USER` |
| Cancel a job | `scancel <job-id>` |
| Check job details | `scontrol show job <job-id>` |
| Show available partitions | `sinfo` |
| Show your account/quota | `sacctmgr show user $USER` |
| Interactive session | `srun --pty bash` |
| Check job history | `sacct -u $USER --format=JobID,JobName,State,Elapsed` |

---

## Contents

| File | What it covers |
|------|----------------|
| [connection.md](connection.md) | SSH config, VPN requirements, jump hosts, and first-time setup |
| [jobs.md](jobs.md) | Submitting, monitoring, and cancelling jobs; job arrays; resource flags |
| [resources.md](resources.md) | Available partitions, GPU types, memory limits, and QoS policies |
| [examples/](examples/) | Ready-to-use job script templates |

---

## Cluster Overview

> **Fill in this section with your specific cluster details.**

| Property | Value |
|----------|-------|
| Login node hostname | `<LOGIN_NODE_HOSTNAME>` |
| Jump host (if any) | `<JUMP_HOST>` |
| Scheduler version | SLURM `<VERSION>` |
| Default shell | `bash` |
| Module system | `module` / `lmod` |
| Home directory | `<HOME_DIR_PATH>` |
| Shared scratch | `<SCRATCH_PATH>` |

---

## Environment Modules

SLURM clusters typically use a module system to manage software environments.

```bash
# List all available modules
module avail

# Load a module
module load <module-name>/<version>

# Show currently loaded modules
module list

# Unload a module
module unload <module-name>

# Purge all loaded modules
module purge
```

> **NOTE:** Always load required modules inside your job scripts, not just interactively — the job scheduler runs in a clean environment.

---

## Typical Workflow

1. **Connect** to the login node — see [connection.md](connection.md).
2. **Stage your data** to scratch storage — see [`resources/storage/`](../../resources/storage/README.md).
3. **Write a job script** using one of the templates in [examples/](examples/).
4. **Submit** with `sbatch` and note the returned `<job-id>`.
5. **Monitor** with `squeue -u $USER` or `scontrol show job <job-id>`.
6. **Retrieve outputs** from the paths specified in your script's `--output` / `--error` directives.

---

## Common Gotchas

- **Login nodes are not for compute.** Do not run experiments, compilations, or data processing directly on the login node — see the rule at the top of this file. Use `sbatch` or `srun` instead.
- **Scratch is not backed up.** Copy important results to persistent storage promptly.
- **Job time limits.** Jobs that exceed their `--time` limit are killed without warning. Add a buffer and checkpoint frequently for long runs.
- **Environment isolation.** Jobs run in a clean shell — always `module load` or activate your virtual environment inside the script.
- **File descriptor limits.** Some workloads (e.g. PyTorch DataLoader with many workers) require raising `ulimit -n`. Do this inside the job script.