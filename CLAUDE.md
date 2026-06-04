# Skills Repository

This repository contains skills — structured knowledge documents — that describe how to access and operate infrastructure resources. Use these documents to understand how to connect to clusters, manage compute jobs, access storage and databases, and execute multi-step workflows.

## How to Use This Repo

When you need to perform an infrastructure task:
1. Identify the relevant category below.
2. Navigate to the appropriate subdirectory and read the `README.md` first.
3. Follow the more specific skill documents for the exact operation.
4. Prefer copying from `examples/` directories when available.

Always read the relevant skill document **before** attempting any operation. Do not guess at commands, hostnames, or credentials — they are documented here.

---

## Directory Map

### `clusters/`
Compute cluster access and job management skills.
Each subdirectory covers a specific cluster technology or named cluster.

| Path | What it covers |
|------|----------------|
| `clusters/README.md` | Index of all available clusters |
| `clusters/slurm/` | Generic SLURM-based HPC cluster(s) |
| `clusters/euler/` | Euler HPC cluster at ETH Zürich (SLURM + **Apptainer/Singularity**) |
| `clusters/cscs/` | CSCS Alps — Clariden (GH200) / Bristen (A100) (SLURM + **enroot/pyxis** `.sqsh` images); building & operating images |

### `resources/`
Shared infrastructure resources that are accessible across clusters or independently.

| Path | What it covers |
|------|----------------|
| `resources/README.md` | Index of all resources |
| `resources/storage/` | Filesystems, object storage (e.g. S3, NFS, Lustre) |
| `resources/databases/` | Database access, credentials, and query patterns |
| `resources/services/` | Internal APIs and microservices |

### `workflows/`
End-to-end, multi-step task guides that combine clusters and resources.
Start here when you have a higher-level task (e.g. "run a training experiment", "process a dataset").

| Path | What it covers |
|------|----------------|
| `workflows/README.md` | Index of all workflows |

### `tools/`
Reusable code utilities and conventions for common development tasks.

| Path | What it covers |
|------|----------------|
| `tools/plotting/` | Publication-quality matplotlib/seaborn figures: setup, helper functions, CDF patterns, saving to PDF |
| `tools/research/` | Academic research process: reading and finding papers, designing experiments, writing and submitting papers |

---

## Container Environments

Several clusters use container runtimes as the **primary** way to run custom software.
Pay close attention to the container skill file for those clusters before attempting to
install or run software any other way.

| Cluster | Container runtime | Key skill file |
|---------|-------------------|----------------|
| `clusters/euler/` | Apptainer / Singularity (`.sif`) | `clusters/euler/containers.md` |
| `clusters/cscs/` | enroot + pyxis (`.sqsh` + EDF) | `clusters/cscs/containers.md` |

**On Euler specifically:** When a task requires software not available in the module
system, default to Apptainer containers — not Conda. Conda creates thousands of small
files that degrade Lustre filesystem performance. Containers bundle the entire
environment into a single `.sif` file and avoid all quota and performance issues.

**On CSCS Alps specifically:** containers are **enroot `.sqsh`** images selected by a
**pyxis EDF** (`srun --environment=<edf>`), not Apptainer. To add/upgrade a pip package,
prefer the **overlay build** (`enroot create → start --rw + pip → export` to a new `.sqsh`,
~1 min) over a full podman rebuild (~1.5 h). Compute nodes are diskless — put all
enroot/podman working paths on `/dev/shm`. See `clusters/cscs/containers.md`.

---

## Conventions Used Across All Skills

- **Test on cluster compute nodes, not locally.** Always run and verify scripts, jobs, and environments on the target cluster's compute nodes — not on your local machine or on login nodes. Local environments differ in OS, filesystem, module systems, schedulers, and available hardware. Login nodes lack GPUs, have restricted resources, and may kill long-running processes. Submit a short test job (e.g. via `srun` or a small `sbatch` script) to validate on an actual compute node before scaling up.
- **Placeholders** are written in `<ANGLE_BRACKETS>`. Replace them with real values before running.
- **Environment variables** are UPPER_SNAKE_CASE and should be set in your shell or `.env` before use.
- **Comments** in shell scripts starting with `# NOTE:` contain important caveats to read before executing.
- Commands prefixed with `$` are run on your **local machine**; commands prefixed with `(remote) $` are run on a remote host after SSH-ing in.

---

## Adding New Skills

When adding a new cluster or resource, follow this checklist:
1. Create a subdirectory under `clusters/<name>/` or `resources/<category>/`.
2. Add a `README.md` with an overview and a table of contents linking to other files.
3. Update the parent `README.md` to include the new entry.
4. Update the table in this file if a new top-level category is added.

When adding a new coding utility (e.g. a plotting convention, data-processing helper), follow this checklist:
1. Create a subdirectory under `tools/<name>/`.
2. Add a `SKILL.md` with a YAML front-matter block (`name:`, `description:`), usage rules, function reference, and code patterns.
3. Place any reusable source files or worked examples under `tools/<name>/examples/`.
4. Update the `tools/` table in this file.