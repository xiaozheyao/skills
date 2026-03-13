# SLURM Resources

This document describes the available compute resources on the SLURM cluster(s): partitions, GPU types, memory limits, CPU allocations, and Quality of Service (QoS) policies.

> **NOTE:** Fill in the tables below with your actual cluster values. Remove any rows that do not apply.

---

## Clusters

| Cluster Name | Hostname / Login Node | Purpose |
|---|---|---|
| `<cluster-name>` | `<login-node.example.com>` | General HPC workloads |

---

## Partitions

Partitions are logical groupings of nodes with shared resource limits and scheduling policies. Choose the partition that best matches your job's requirements.

```bash
# List all partitions and their current state
sinfo -s

# Show detailed partition info including limits
scontrol show partition
```

| Partition | Node Count | CPUs/Node | RAM/Node | GPUs/Node | GPU Type | Max Walltime | Notes |
|---|---|---|---|---|---|---|---|
| `<partition-name>` | `<N>` | `<N>` | `<N>GB` | `<N>` | `<type>` | `<HH:MM:SS>` | |

> Add a row per partition. Common partition names: `gpu`, `cpu`, `highmem`, `debug`, `interactive`, `preempt`.

---

## GPU Resources

### Available GPU Types

| GPU Model | VRAM | Partition(s) | SLURM GRES name | Notes |
|---|---|---|---|---|
| `<e.g. NVIDIA A100>` | `<80GB>` | `<gpu>` | `gpu:a100` | |
| `<e.g. NVIDIA V100>` | `<32GB>` | `<gpu>` | `gpu:v100` | |

### Requesting GPUs

```bash
# Request 1 GPU (any type)
#SBATCH --gres=gpu:1

# Request a specific GPU type
#SBATCH --gres=gpu:<type>:<count>
# e.g.: #SBATCH --gres=gpu:a100:2

# Verify GPU visibility inside your job
nvidia-smi
echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
```

### GPU-Specific Notes

- `<NOTE: e.g. A100 nodes require the gpu-a100 partition — the generic gpu partition does not schedule them.>`
- `<NOTE: e.g. Maximum 4 GPUs per job on the v100 partition.>`

---

## Memory

### Per-Node Memory Limits

| Partition | Default mem/CPU | Max mem/node | Flags to set |
|---|---|---|---|
| `<partition>` | `<e.g. 4GB>` | `<e.g. 512GB>` | `--mem=<N>G` or `--mem-per-cpu=<N>G` |

### Requesting Memory

```bash
# Request total memory for the job
#SBATCH --mem=64G

# Request memory per CPU core (use one or the other, not both)
#SBATCH --mem-per-cpu=8G
```

> **NOTE:** If you do not specify `--mem`, the scheduler assigns the partition default. Jobs exceeding their memory limit are killed with OOM.

---

## CPUs / Cores

```bash
# Request a specific number of CPUs per task
#SBATCH --cpus-per-task=<N>

# Request multiple tasks (e.g. for MPI)
#SBATCH --ntasks=<N>

# Request multiple nodes
#SBATCH --nodes=<N>
```

| Partition | Default CPUs/job | Max CPUs/job | Hyperthreading |
|---|---|---|---|
| `<partition>` | `1` | `<N>` | `<enabled/disabled>` |

---

## Quality of Service (QoS)

QoS policies enforce additional limits (priority, max jobs, max walltime) on top of partition limits. A QoS is specified with `--qos=<name>`.

```bash
# List available QoS policies
sacctmgr show qos format=Name,Priority,MaxWall,MaxJobsPerUser,MaxTRESPerUser
```

| QoS Name | Priority | Max Walltime | Max Jobs/User | Max GPUs/User | Intended Use |
|---|---|---|---|---|---|
| `normal` | medium | `<e.g. 48:00:00>` | `<N>` | `<N>` | Default workloads |
| `high` | high | `<e.g. 24:00:00>` | `<N>` | `<N>` | Urgent / high-priority runs |
| `preempt` | low | `<e.g. 72:00:00>` | `<N>` | `<N>` | Long jobs, may be preempted |
| `debug` | highest | `<e.g. 00:30:00>` | `1` | `1` | Quick testing only |

```bash
# Example: submit with a specific QoS
#SBATCH --partition=gpu
#SBATCH --qos=high
```

---

## Accounts & Fairshare

Jobs must be charged to a valid account. Your account determines your fairshare priority.

```bash
# View your accounts and current fairshare
sacctmgr show user $USER withas

# Specify an account explicitly
#SBATCH --account=<account-name>
```

| Account | Project / Team | Default Partition | Contact |
|---|---|---|---|
| `<account>` | `<team or project>` | `<partition>` | `<email>` |

---

## Checking Current Cluster State

```bash
# Overview of nodes and partitions
sinfo

# Show all currently running and queued jobs
squeue

# Show only your own jobs
squeue -u $USER

# Detailed node information (CPUs, memory, GPUs, state)
scontrol show nodes

# Show a single node
scontrol show node <nodename>

# Show cluster-level resource usage
sreport cluster utilization start=today

# Show your historical usage
sreport user top start=<YYYY-MM-DD> end=<YYYY-MM-DD>
```

---

## Resource Limit Cheatsheet

| Resource | SBATCH Flag | Example |
|---|---|---|
| Partition | `--partition` | `--partition=gpu` |
| QoS | `--qos` | `--qos=normal` |
| Account | `--account` | `--account=myproject` |
| Walltime | `--time` | `--time=12:00:00` |
| Total memory | `--mem` | `--mem=128G` |
| Memory/CPU | `--mem-per-cpu` | `--mem-per-cpu=4G` |
| CPUs/task | `--cpus-per-task` | `--cpus-per-task=8` |
| Tasks | `--ntasks` | `--ntasks=4` |
| Nodes | `--nodes` | `--nodes=2` |
| GPUs | `--gres` | `--gres=gpu:a100:2` |
| GPU constraint | `--constraint` | `--constraint=a100` |