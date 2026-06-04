# Clusters

This directory contains skills for accessing and operating compute clusters. Each subdirectory corresponds to a cluster technology or a specific named cluster.

---

## Universal Rule — Never Run Compute on Login Nodes

> **This rule applies to every cluster in this directory, without exception.**

When you SSH into a cluster you land on a **login node**. Login nodes are shared gateways — they have limited CPU and RAM, are shared by all users simultaneously, and are not meant for any workload beyond light file management and job submission.

**Never run any of the following on a login node:**
- Training runs or model inference
- Data preprocessing or transformation scripts
- Compilation of large codebases
- Any script or command expected to run for more than a few seconds or use significant CPU/memory

**Always use a compute node instead:**

```bash
# Submit a batch job (preferred for production workloads)
(remote) $ sbatch my_job.sh

# Start an interactive session on a compute node (for debugging/exploration)
(remote) $ srun --ntasks=1 --cpus-per-task=1 --mem-per-cpu=4G --time=01:00:00 --pty bash
```

Running heavy workloads on login nodes degrades the experience for every user on the cluster and may result in your process being killed or your account being suspended by the cluster administrators.

---

## Available Clusters

| Directory | Technology | Description |
|-----------|------------|-------------|
| [`slurm/`](slurm/README.md) | SLURM | HPC cluster(s) managed by the SLURM workload manager |
| [`euler/`](euler/README.md) | SLURM + Apptainer | ETH Zürich's central HPC cluster (Euler); uses Apptainer/Singularity for containers |
| [`cscs/`](cscs/README.md) | SLURM + enroot/pyxis | CSCS Alps (Clariden GH200 / Bristen A100); `.sqsh` images + EDF profiles; focus on building & operating images |

> Add a new row to this table each time a new cluster is documented.

---

## Choosing the Right Cluster

- Use **SLURM** clusters for batch HPC workloads, GPU training jobs, and large-scale parallel computation.
- Use **Euler** for ETH Zürich research workloads. Euler runs SLURM but has important differences from a generic cluster: do not specify `--partition`, use Apptainer/Singularity containers for custom software, and be aware of the 15-day Scratch purge policy.
- Use **CSCS Alps** (`cscs/`) for GH200 (Clariden) / A100 (Bristen) jobs. Runs SLURM but: the account flag is mandatory and per-cluster (`-A infra02` / `-A a-infra02`), containers are **enroot `.sqsh` + pyxis EDF** (no Apptainer), compute nodes are diskless (`/dev/shm` only), and the SSH cert expires daily.

---

## Common Concepts

Regardless of the cluster technology, each cluster skill directory documents the following:

| Topic | Typical filename |
|-------|-----------------|
| How to connect (SSH, VPN, jump hosts) | `connection.md` |
| Submitting, monitoring, and cancelling jobs | `jobs.md` |
| Available partitions, GPUs, memory, and quotas | `resources.md` |
| Ready-to-use job script templates | `examples/` |

---

## Adding a New Cluster

1. Create a subdirectory: `clusters/<cluster-name>/`
2. Add a `README.md` inside it with an overview and links to its skill files.
3. Add at minimum: `connection.md`, `jobs.md`, `resources.md`, and an `examples/` directory.
4. Register the new cluster in the table above.
5. Update `../CLAUDE.md` if a new cluster technology category is introduced.
