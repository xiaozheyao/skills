# SLURM — Job Management

This document covers submitting, monitoring, and cancelling jobs on a SLURM cluster.
Read `connection.md` first to ensure you have an active session on the cluster.

---

## Table of Contents

1. [Submitting Jobs](#1-submitting-jobs)
2. [Monitoring Jobs](#2-monitoring-jobs)
3. [Cancelling and Modifying Jobs](#3-cancelling-and-modifying-jobs)
4. [Retrieving Output and Logs](#4-retrieving-output-and-logs)
5. [Job Arrays](#5-job-arrays)
6. [Interactive Jobs](#6-interactive-jobs)
7. [Common Flags Reference](#7-common-flags-reference)
8. [Exit Codes and Job States](#8-exit-codes-and-job-states)

---

## 1. Submitting Jobs

### Batch submission (most common)

```bash
(remote) $ sbatch <SCRIPT>.sh
```

On success, SLURM prints the assigned job ID:
```
Submitted batch job 1234567
```

Save this ID — it is used for all subsequent monitoring and cancellation commands.

### Submitting with inline overrides

Flags passed on the command line **override** the `#SBATCH` directives inside the script:

```bash
(remote) $ sbatch --partition=<PARTITION> --gres=gpu:<N_GPUS> --time=<HH:MM:SS> <SCRIPT>.sh
```

### Passing arguments to the script

Arguments after the script name are passed as positional parameters (`$1`, `$2`, …):

```bash
(remote) $ sbatch train.sh --config configs/exp1.yaml --seed 42
```

Inside `train.sh`, access them with `"$@"`:
```bash
python train.py "$@"
```

---

## 2. Monitoring Jobs

### View your queued and running jobs

```bash
(remote) $ squeue --me
```

Useful extended format showing reason a job is pending:

```bash
(remote) $ squeue --me --format="%.18i %.12P %.30j %.8T %.10M %.6D %R"
```

| Column | Meaning |
|--------|---------|
| `JOBID` | Numeric job identifier |
| `PARTITION` | Queue / partition the job is in |
| `NAME` | Job name (from `--job-name`) |
| `ST` | State (see [§8](#8-exit-codes-and-job-states)) |
| `TIME` | Elapsed wall-clock time |
| `NODES` | Number of nodes allocated |
| `NODELIST(REASON)` | Nodes assigned, or reason if pending |

### Watch the queue (refresh every 5 s)

```bash
(remote) $ watch -n 5 squeue --me
```

Press `Ctrl+C` to exit.

### Detailed info for a specific job

```bash
(remote) $ scontrol show job <JOBID>
```

Key fields to look for:
- `JobState` — current state
- `StartTime` / `EndTime` — scheduled or actual run times
- `NodeList` — assigned compute nodes
- `Reason` — why a pending job is not starting yet
- `WorkDir` — working directory the job runs in

### Check accounting info (finished jobs)

```bash
(remote) $ sacct -j <JOBID> --format=JobID,JobName,Partition,State,ExitCode,Elapsed,MaxRSS
```

Add `-u <USERNAME>` to query another user's jobs (if permitted).

To query all your jobs since a date:

```bash
(remote) $ sacct -u $USER --starttime=<YYYY-MM-DD> --format=JobID,JobName,State,ExitCode,Elapsed
```

---

## 3. Cancelling and Modifying Jobs

### Cancel a single job

```bash
(remote) $ scancel <JOBID>
```

### Cancel all your pending and running jobs

```bash
(remote) $ scancel -u $USER
```

### Cancel only pending jobs (leave running jobs alone)

```bash
(remote) $ scancel --state=PENDING -u $USER
```

### Cancel a specific job array task

```bash
(remote) $ scancel <JOBID>_<ARRAY_TASK_ID>
```

### Modify a pending job (before it starts)

```bash
# Change the time limit
(remote) $ scontrol update JobId=<JOBID> TimeLimit=<HH:MM:SS>

# Change the partition
(remote) $ scontrol update JobId=<JOBID> Partition=<PARTITION>

# Hold a job (prevent it from starting)
(remote) $ scontrol hold <JOBID>

# Release a held job
(remote) $ scontrol release <JOBID>
```

# NOTE: `scontrol update` only works while the job is still in PENDING state.

---

## 4. Retrieving Output and Logs

By default SLURM writes stdout and stderr to `slurm-<JOBID>.out` in the **working directory from which `sbatch` was called**.

Tail the output of a running job in real time:

```bash
(remote) $ tail -f slurm-<JOBID>.out
```

If the script set custom output paths with `#SBATCH --output` / `#SBATCH --error`, look there instead.

Check the last N lines once a job completes:

```bash
(remote) $ tail -n 50 slurm-<JOBID>.out
```

---

## 5. Job Arrays

Job arrays run the same script multiple times with different `SLURM_ARRAY_TASK_ID` values. Use them for hyperparameter sweeps, cross-validation folds, or dataset shards.

### Submitting an array

```bash
# Run task IDs 0 through 9 (10 tasks total)
(remote) $ sbatch --array=0-9 sweep.sh

# Run specific task IDs
(remote) $ sbatch --array=1,3,5,7 sweep.sh

# Limit concurrency to at most 4 running simultaneously
(remote) $ sbatch --array=0-19%4 sweep.sh
```

### Accessing the task ID inside the script

```bash
#!/bin/bash
echo "Running task $SLURM_ARRAY_TASK_ID"
python run.py --fold "$SLURM_ARRAY_TASK_ID"
```

### Monitoring array jobs

```bash
(remote) $ squeue --me --array
```

Output files are named `slurm-<JOBID>_<TASK_ID>.out` by default.

---

## 6. Interactive Jobs

> ⚠️ **Never run compute-heavy work directly on the login node.** If you need an interactive shell for debugging, testing, or exploration, start an interactive job on a **compute node** using `srun` as shown below. Even short scripts that are CPU or memory intensive must go through the scheduler.

Use interactive jobs to debug, test environments, or run short exploratory work directly on a compute node.

```bash
(remote) $ srun --partition=<PARTITION> --gres=gpu:<N_GPUS> --cpus-per-task=<N_CPUS> \
               --mem=<MEM>G --time=<HH:MM:SS> --pty bash
```

You are now in a shell on the compute node. Type `exit` to release the allocation.

# NOTE: Interactive jobs count against the same quota as batch jobs. Do not leave
# idle interactive sessions open — they block resources for others.
# NOTE: If you find yourself tempted to run something "quickly" on the login node,
# use `srun` instead. It is just as fast to start a short interactive allocation.

For GPU debugging with a specific environment:

```bash
(remote) $ srun --partition=<PARTITION> --gres=gpu:1 --time=01:00:00 --pty \
               --export=ALL bash --login
```

---

## 7. Common Flags Reference

| Flag | Example | Description |
|------|---------|-------------|
| `--job-name` | `--job-name=train_resnet` | Human-readable label (appears in `squeue`) |
| `--partition` | `--partition=gpu` | Target queue / partition |
| `--nodes` | `--nodes=1` | Number of nodes |
| `--ntasks` | `--ntasks=4` | Total number of tasks (MPI ranks) |
| `--ntasks-per-node` | `--ntasks-per-node=4` | Tasks per node |
| `--cpus-per-task` | `--cpus-per-task=8` | CPU cores per task (use for threading) |
| `--mem` | `--mem=64G` | Memory per node |
| `--mem-per-cpu` | `--mem-per-cpu=4G` | Memory per CPU (alternative to `--mem`) |
| `--gres` | `--gres=gpu:2` | Generic resources (GPUs) |
| `--time` | `--time=12:00:00` | Wall-clock time limit (`D-HH:MM:SS` also valid) |
| `--output` | `--output=logs/%j.out` | Stdout path (`%j` = job ID, `%a` = array task ID) |
| `--error` | `--error=logs/%j.err` | Stderr path |
| `--mail-type` | `--mail-type=END,FAIL` | Email trigger events |
| `--mail-user` | `--mail-user=<EMAIL>` | Email address for notifications |
| `--dependency` | `--dependency=afterok:<JOBID>` | Start only after another job succeeds |
| `--account` | `--account=<PROJECT>` | Charge to a specific account / project |
| `--qos` | `--qos=high` | Quality of service tier |
| `--requeue` | `--requeue` | Automatically requeue on node failure |
| `--export` | `--export=ALL` | Pass current environment variables to the job |

---

## 8. Exit Codes and Job States

### Job states (`ST` column in `squeue`)

| State | Code | Meaning |
|-------|------|---------|
| `PENDING` | PD | Queued, waiting for resources |
| `RUNNING` | R | Currently executing |
| `COMPLETING` | CG | Finishing up, cleaning processes |
| `COMPLETED` | CD | Finished successfully (exit code 0) |
| `FAILED` | F | Finished with non-zero exit code |
| `CANCELLED` | CA | Explicitly cancelled via `scancel` |
| `TIMEOUT` | TO | Exceeded wall-clock time limit |
| `OUT_OF_MEMORY` | OOM | Job was killed for exceeding memory limit |
| `NODE_FAIL` | NF | Compute node failed during the job |

### Pending reasons (shown in `NODELIST(REASON)`)

| Reason | Meaning |
|--------|---------|
| `Resources` | Waiting for CPUs/GPUs/memory to free up |
| `Priority` | Lower priority than other jobs in the queue |
| `QOSMaxJobsPerUserLimit` | You have hit the per-user job limit for this QoS |
| `Dependency` | Waiting for a dependency job to complete |
| `ReqNodeNotAvail` | Requested node(s) unavailable (may be down) |
| `AssocMaxWallDurationPerJobLimit` | Requested time exceeds your account's maximum |

### Diagnosing a FAILED job

```bash
# 1. Check exit code and state
(remote) $ sacct -j <JOBID> --format=JobID,State,ExitCode

# 2. Read the output log
(remote) $ cat slurm-<JOBID>.out

# 3. Look at the detailed job record for node/resource info
(remote) $ scontrol show job <JOBID>
```

Exit code format in `sacct` is `<script_exit_code>:<signal_number>`. A value of `1:0` means the script exited with code 1 (application error). A value of `0:9` means the job was killed with signal 9 (SIGKILL, typically OOM or timeout).