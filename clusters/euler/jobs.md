# Euler — SLURM Job Management

This document covers submitting, monitoring, and managing SLURM jobs on Euler.
Read [connection.md](connection.md) first to ensure you have an active session.

Official SLURM docs: https://docs.hpc.ethz.ch/batchsystem/slurm/
SLURM web GUI: https://slurm-jobs-webgui.euler.hpc.ethz.ch/

---

## Euler-Specific SLURM Rules

> **These differ from generic SLURM clusters. Read before submitting anything.**

### Rule 1 — Do NOT specify `--partition`

Euler manages partition assignments internally. Specifying a partition adds a
constraint that can only make your job wait longer — it provides no benefit.

```bash
# WRONG on Euler — do not do this:
#SBATCH --partition=gpu

# CORRECT — omit it entirely and let Euler schedule optimally
```

### Rule 2 — Do NOT constrain GPU/CPU type unless strictly necessary

Only request a specific GPU model (e.g. `--gpus=a100:1`) if your code has a hard
dependency on that exact hardware (e.g. requires 80 GB VRAM, or needs CUDA compute
capability ≥ 8.0). Constraining narrows the eligible node pool and increases wait time.

```bash
# Prefer — accepts any available GPU
#SBATCH --gpus=1

# Only use when your code truly requires it
#SBATCH --gpus=a100_80gb:1
```

### Rule 3 — Jobs run non-exclusively

Multiple users' jobs can share the same compute node simultaneously.
Request only the resources you actually need — do not over-request to "claim" a node.

### Rule 4 — Jobs inherit your shell environment

Euler jobs inherit all environment variables from the shell that submitted the job.
Always use `module purge` at the top of your script before loading modules to avoid
inheriting a polluted environment.

### Rule 5 — Internet access requires `eth_proxy`

Compute nodes do not have direct internet access. Load the proxy module before any
network call (downloading packages, pulling containers, etc.):

```bash
module load eth_proxy
```

---

## Submitting Batch Jobs

### Minimal example

```bash
#!/bin/bash
#SBATCH --job-name=my_job
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=4G
#SBATCH --time=02:00:00
#SBATCH --output=logs/%j.out
#SBATCH --error=logs/%j.err

module purge
module load stack/2024-06

python my_script.py
```

Submit with:

```bash
(remote) $ mkdir -p logs
(remote) $ sbatch my_job.sh
# → Submitted batch job 1234567
```

### GPU job example

```bash
#!/bin/bash
#SBATCH --job-name=gpu_train
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=8G
#SBATCH --gpus=1              # request 1 GPU — do NOT specify type unless required
#SBATCH --time=12:00:00
#SBATCH --output=logs/%j.out
#SBATCH --error=logs/%j.err

module purge
module load stack/2024-06

# Verify GPU visibility
nvidia-smi

python train.py --config config.yaml
```

---

## Common `sbatch` / `srun` Options

| Option | Description | Example |
|--------|-------------|---------|
| `-t`, `--time` | Wall-clock limit (default: 1 hour) | `--time=12:00:00` |
| `-n`, `--ntasks` | Number of tasks (default: 1) | `--ntasks=4` |
| `-c`, `--cpus-per-task` | CPU cores per task | `--cpus-per-task=8` |
| `--mem-per-cpu` | Memory per CPU core (preferred over `--mem`) | `--mem-per-cpu=4G` |
| `--gpus` | Number (and optionally type) of GPUs | `--gpus=1` or `--gpus=a100:2` |
| `--gpus-per-task` | GPUs per task | `--gpus-per-task=1` |
| `-N`, `--nodes` | Minimum number of nodes | `--nodes=2` |
| `--tmp` | Node-local scratch space (`$TMPDIR`) | `--tmp=100G` |
| `-o`, `--output` | stdout log file (`%j` = job ID) | `--output=logs/%j.out` |
| `-e`, `--error` | stderr log file | `--error=logs/%j.err` |
| `-A`, `--account` | Shareholder group to charge | `--account=es_mygroup` |
| `-d`, `--dependency` | Start after another job | `--dependency=afterok:1234567` |
| `--wrap` | Inline command (no script file needed) | `--wrap="python foo.py"` |
| `--array` | Submit a job array | `--array=0-9` |

> **Omit `--partition` entirely.** See Rule 1 above.

---

## Interactive Sessions

> ⚠️ **Never run compute-heavy work on a login node.** After SSH-ing in you are on a login
> node. Any task that is CPU, GPU, or memory intensive — including debugging runs, environment
> setup scripts, and exploratory data work — must be dispatched to a **compute node** via
> `srun` (interactive) or `sbatch` (batch). Running such work on the login node degrades the
> cluster for all users and may get your process killed by ETH HPC support.

Use `srun` to open an interactive shell directly on a compute node:

```bash
# Basic interactive shell (1 CPU, 4 GB RAM, 1 hour)
(remote) $ srun --ntasks=1 --cpus-per-task=1 --mem-per-cpu=4G --time=01:00:00 --pty bash

# Interactive session with 1 GPU
(remote) $ srun --ntasks=1 --cpus-per-task=4 --mem-per-cpu=8G --gpus=1 --time=02:00:00 --pty bash
```

Once the session starts, `hostname` will show a compute node name (e.g. `eu-g3-022`) rather
than a login node name (e.g. `eu-login-05`). Type `exit` to release the allocation.

> **NOTE:** Interactive sessions block resources for others while idle. Release them
> as soon as you are done. For longer or reproducible workloads, prefer `sbatch`.

---

## Monitoring Jobs

### `myjobs` — Euler's human-friendly job view (preferred over `squeue`)

```bash
# List all your current jobs
(remote) $ myjobs

# Detailed info for a specific job
(remote) $ myjobs -j <JOBID>
```

Example output for a running job:

```
Job information
 Job ID                : 6038307
 Status                : RUNNING
 Running on node       : eu-g3-022
 User                  : myusername
 Shareholder group     : es_mygroup
 Command               : train.sh
 Working directory     : /cluster/home/myusername
Requested resources
 Requested runtime     : 08:00:00
 Requested cores       : 8
 Requested memory      : 64000 MiB
 Requested GPUs        : 1
Resource usage
 Wall-clock            : 01:23:45
 CPU utilization       : 87%
 Memory utilization    : 62%
 GPU utilization       : 94%
```

### Standard `squeue`

```bash
# Your jobs only
(remote) $ squeue --me

# With more detail
(remote) $ squeue --me --format="%.18i %.30j %.8T %.10M %.6D %R"
```

### `sacct` — Finished jobs

```bash
# Info on a specific finished job
(remote) $ sacct -j <JOBID> --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS

# All your jobs since a date
(remote) $ sacct -u $USER --starttime=2024-01-01 --format=JobID,JobName,State,ExitCode,Elapsed
```

### Web GUI

Monitor all your jobs visually at:
https://slurm-jobs-webgui.euler.hpc.ethz.ch/

---

## Cancelling and Modifying Jobs

```bash
# Cancel a single job
(remote) $ scancel <JOBID>

# Cancel all your pending and running jobs
(remote) $ scancel -u $USER

# Cancel only pending jobs
(remote) $ scancel --state=PENDING -u $USER

# Cancel a specific array task
(remote) $ scancel <JOBID>_<ARRAY_TASK_ID>

# Hold a job (prevent it from starting)
(remote) $ scontrol hold <JOBID>

# Release a held job
(remote) $ scontrol release <JOBID>

# Modify time limit of a pending job
(remote) $ scontrol update JobId=<JOBID> TimeLimit=<HH:MM:SS>
```

---

## Job Arrays

Job arrays submit the same script multiple times with different `$SLURM_ARRAY_TASK_ID` values.
Useful for hyperparameter sweeps, dataset shards, or replicated experiments.

```bash
# Submit 10 tasks (IDs 0–9)
(remote) $ sbatch --array=0-9 sweep.sh

# Submit with a maximum of 4 running at once
(remote) $ sbatch --array=0-31%4 sweep.sh
```

Inside the script, use `$SLURM_ARRAY_TASK_ID` to differentiate tasks:

```bash
#!/bin/bash
#SBATCH --job-name=sweep
#SBATCH --array=0-9
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=8G
#SBATCH --gpus=1
#SBATCH --time=04:00:00
#SBATCH --output=logs/%A_%a.out    # %A = array job ID, %a = task ID
#SBATCH --error=logs/%A_%a.err

LEARNING_RATES=(1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2 1e-1 3e-1)
LR="${LEARNING_RATES[$SLURM_ARRAY_TASK_ID]}"

module purge
module load stack/2024-06

OUTPUT_DIR="$SCRATCH/sweep/task_${SLURM_ARRAY_TASK_ID}"
mkdir -p "$OUTPUT_DIR"

python train.py --lr "$LR" --output-dir "$OUTPUT_DIR"
```

---

## GPU Jobs

GPU nodes are only accessible to **shareholders**. During the AMD MI300A evaluation period,
those APUs are open to all ETH users.

### Requesting GPUs

```bash
# Any available GPU (fastest scheduling — use this by default)
#SBATCH --gpus=1

# Specific type (only if your code requires it)
#SBATCH --gpus=a100:1
#SBATCH --gpus=a100_80gb:1
#SBATCH --gpus=rtx_4090:2
```

### GPU Slurm identifiers

| GPU Model | SLURM Identifier | VRAM |
|---|---|---|
| NVIDIA Tesla A100 (40 GB) | `a100` | 40 GB |
| NVIDIA Tesla A100 (80 GB) | `a100_80gb` | 80 GB |
| NVIDIA RTX 4090 | `rtx_4090` | 24 GB |
| NVIDIA RTX 3090 | `rtx_3090` | 24 GB |
| NVIDIA TITAN RTX | `nvidia_titan_rtx` | 24 GB |
| NVIDIA Quadro RTX 6000 | `rtx_6000` | 24 GB |
| NVIDIA RTX 2080 Ti | `rtx_2080` | 11 GB |
| NVIDIA RTX PRO 6000 | `pro_6000` | 96 GB (CUDA 13+ only) |
| AMD MI300A APU | `mi300a` | 128 GB (shared HBM3) |

> **RTX PRO 6000 / Blackwell note:** CUDA 12 programs will NOT run on these GPUs.
> Only request `pro_6000` if your code is compiled with CUDA 13+.

### Verify GPU inside the job

```bash
nvidia-smi
echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
```

### Multi-GPU jobs (single node)

```bash
#SBATCH --gpus=4
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem-per-cpu=8G
```

---

## Shareholder Groups and Accounts

If you belong to multiple shareholder groups, specify which to charge with `-A`:

```bash
#SBATCH --account=es_mygroup
```

To set a default account persistently, create `~/.slurm/defaults`:

```bash
mkdir -p ~/.slurm
echo "account=es_mygroup" > ~/.slurm/defaults
```

Check your groups:

```bash
(remote) $ my_share_info
```

The public (free) share available to all ETH members is named `public`.

---

## Euler Custom Commands

| Command | Purpose |
|---------|---------|
| `myjobs` | Human-friendly view of your current jobs |
| `myjobs -j <JOBID>` | Detailed job info including resource utilization |
| `my_share_info` | List your shareholder groups |
| `get_inefficient_jobs` | Find jobs where CPU/GPU/RAM is under-utilized |
| `lquota` | Check storage quotas for Home and Scratch |
| `get-access` | Request access to Apptainer/Singularity containers |

### Finding inefficient jobs

```bash
(remote) $ get_inefficient_jobs
```

This command reports jobs that requested significantly more resources than they used.
Adjust your future resource requests based on this feedback — smaller footprint = faster start.

---

## Output and Logs

By default, SLURM writes stdout to `slurm-<JOBID>.out` in the submission directory.

### Recommended log path pattern

```bash
#SBATCH --output=logs/%x_%j.out   # %x = job name, %j = job ID
#SBATCH --error=logs/%x_%j.err
```

Always create the `logs/` directory before submitting:

```bash
(remote) $ mkdir -p logs
```

### Tailing a running job's output

```bash
(remote) $ tail -f logs/<JOBNAME>_<JOBID>.out
```

---

## Job Dependencies

Chain jobs so that the next starts only after the previous succeeds:

```bash
# Submit first job
(remote) $ JOB1=$(sbatch --parsable preprocess.sh)

# Submit second job, starts only if JOB1 succeeds
(remote) $ sbatch --dependency=afterok:$JOB1 train.sh

# Start regardless of whether JOB1 succeeded or failed
(remote) $ sbatch --dependency=afterany:$JOB1 cleanup.sh
```

---

## Job States Reference

| State | Code | Meaning |
|-------|------|---------|
| `PENDING` | PD | Queued, waiting for resources |
| `RUNNING` | R | Executing on a compute node |
| `COMPLETING` | CG | Finishing, cleaning up processes |
| `COMPLETED` | CD | Finished with exit code 0 |
| `FAILED` | F | Finished with non-zero exit code |
| `CANCELLED` | CA | Cancelled via `scancel` or by user |
| `TIMEOUT` | TO | Exceeded wall-clock time limit |
| `OUT_OF_MEMORY` | OOM | Killed for exceeding memory limit |
| `NODE_FAIL` | NF | Compute node failed during the job |

### Common pending reasons

| Reason | Meaning |
|--------|---------|
| `Resources` | Waiting for CPUs/GPUs/memory |
| `Priority` | Lower priority than other queued jobs |
| `QOSMaxJobsPerUserLimit` | Hit your per-user job limit |
| `Dependency` | Waiting for a dependency job |
| `ReqNodeNotAvail` | **Usually harmless** — Euler issue (see Known Issues) |

---

## Diagnosing a Failed Job

```bash
# 1. Check state and exit code
(remote) $ sacct -j <JOBID> --format=JobID,State,ExitCode,Elapsed

# 2. Read the log
(remote) $ cat logs/<JOBNAME>_<JOBID>.out
(remote) $ cat logs/<JOBNAME>_<JOBID>.err

# 3. Detailed job record
(remote) $ myjobs -j <JOBID>
```

Exit code format in `sacct`: `<script_exit_code>:<signal_number>`
- `1:0` — script exited with code 1 (application error)
- `0:9` — killed with SIGKILL (likely OOM or time limit)
- `0:15` — killed with SIGTERM (time limit warning, then killed)

---

## Known Issues

### `ReqNodeNotAvail` while pending

```
JOBID PARTITION  NAME    USER   ST   TIME  NODES NODELIST(REASON)
12345 normal.12  my_job  myname PD   0:00      1 (ReqNodeNotAvail, UnavailableNodes:eu-a2p-[001,103])
```

If you did **not** request those specific nodes, this message is **misleading**. Your job is
simply waiting in the queue. No action is required.

### Job cancelled at startup (>120 s startup)

Jobs that take more than 120 seconds to start (e.g. because `.bashrc` loads many modules)
will be cancelled automatically. Keep your `.bashrc` light — load heavy environments inside
job scripts instead.

### CPU time reported as 0 in `myjobs`

A known Slurm 25.05 bug affects jobs with an `srun` call in the script. CPU utilization
may show as 0 % in `myjobs` and `get_inefficient_jobs`. This is a display bug, not an
actual problem with your job.