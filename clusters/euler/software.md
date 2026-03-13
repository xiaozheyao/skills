# Euler — Software Environment

This document describes how to find, load, and manage software on Euler — covering the
module system, available software stacks, internet proxy for compute nodes, and Python
environment management.

Official docs: https://docs.hpc.ethz.ch/software/software-stack/

---

## Overview

Euler provides software through three complementary mechanisms:

| Mechanism | Best for |
|---|---|
| **Environment Modules** (`module load`) | Pre-installed compilers, MPI, CUDA, scientific libraries |
| **Spack** | Installing custom versions of packages on top of a central stack |
| **Apptainer / Singularity containers** | Fully custom environments, Python stacks, Docker images → see [containers.md](containers.md) |

For most machine-learning and Python workloads, **containers are the recommended approach**
on Euler — they avoid file-count and Lustre compatibility issues that affect Conda.

---

## Module System

Euler uses **Lmod** (Lua-based Environment Modules). Modules are organised in hierarchical
stacks: core → compiler → MPI. You cannot mix different compilers or MPI libraries within
one environment.

### Key commands

```bash
# List all available modules in the current stack
module avail

# Search for a module by name (works even if it's not yet visible)
module spider <name>
module spider python
module spider cuda

# Load a module
module load <name>/<version>
module load gcc/12.2.0

# List currently loaded modules
module list

# Unload a specific module
module unload <name>

# Unload ALL modules (clean slate — always do this at the top of job scripts)
module purge

# Show what a module does (paths it changes, env vars it sets)
module show <name>/<version>
```

### Important: no stack is loaded at login

When you first log in, **no software stack is active**. You must explicitly load a stack
before any stack-specific modules become available:

```bash
module load stack/2025-06    # latest stack (recommended)
# or
module load stack/2024-06
# or
module load stack/2024-04
```

Add this to your `~/.bashrc` if you always want the same stack:

```bash
# ~/.bashrc
module load stack/2025-06
```

---

## Software Stacks

| Stack | Based on | Notable content | Status |
|---|---|---|---|
| `stack/2025-06` | Spack v0.23.1 | gcc 8/12/14, oneAPI, nvhpc, aocc; 1800+ packages | **Current — recommended** |
| `stack/2024-06` | Spack | Fixed OpenMPI for Euler IX nodes; CUDA 12.1+ with GCC ≤12 | Stable |
| `stack/2024-04` | Spack | Older baseline | Use only if 2024-06 breaks something |

### Available compilers (2025-06)

| Compiler | Versions |
|---|---|
| GCC | 8, 12, 14 |
| Intel oneAPI | (see `module spider intel`) |
| NVIDIA HPC SDK (nvhpc) | (see `module spider nvhpc`) |
| AMD AOCC | (see `module spider aocc`) |

### Finding software

```bash
# Load a stack first
module load stack/2025-06

# Search for Python
module spider python

# Search for CUDA
module spider cuda

# Search for PyTorch (may not be available as a module — use containers instead)
module spider pytorch

# Once you know the version, get the full load sequence
module spider python/3.11.6
# Output will tell you what prerequisite modules to load first
```

### CUDA

CUDA is available as a module. Important constraint:

> **CUDA 12.x requires GCC ≤ 12.2.0.** Use `stack/2024-06` or `stack/2025-06`
> and load `gcc/12` before loading CUDA if you need to compile CUDA code.

```bash
module load stack/2025-06
module spider cuda          # find available versions

# Example full sequence:
module load gcc/12.2.0
module load cuda/12.4.0
nvcc --version
```

---

## `eth_proxy` — Internet Access from Compute Nodes

Compute nodes **do not have direct internet access**. To download packages, pull container
images, or clone repositories from a compute node or job script, load the ETH proxy first:

```bash
module load eth_proxy
```

This sets `http_proxy`, `https_proxy`, and `no_proxy` environment variables so that
standard tools (`curl`, `wget`, `pip`, `apt`, container pulls) route through the ETH proxy.

### In job scripts

```bash
#!/bin/bash
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=4G
#SBATCH --time=01:00:00

module load eth_proxy        # ← required before any internet access

# Now you can pull packages or containers
pip install some-package
apptainer pull docker://ubuntu:22.04
```

### In `~/.bashrc` (persistent)

If you frequently need internet access interactively on the login nodes, add it to your
shell startup file. Note: login nodes have internet access by default — this only matters
for compute nodes.

```bash
# ~/.bashrc
module load eth_proxy
```

---

## Python Environments

### Option 1: Apptainer container (recommended for complex environments)

The preferred approach on Euler. Avoids Lustre file-count issues entirely.
See [containers.md](containers.md) for full details.

Advantages:
- Single `.sif` file — no thousands of small files on Lustre
- Fully reproducible
- Can bundle PyTorch, CUDA, cuDNN, and all dependencies
- Works identically on any compute node

### Option 2: Python module + venv

Lightweight environments with few dependencies. Works well when the base Python version
from the module system is sufficient.

```bash
# Load a stack and Python module
module load stack/2025-06
module spider python            # find available versions
module load python/3.11.6       # adjust to available version

# Create a virtual environment (store in home or scratch)
python -m venv $HOME/.venvs/myenv

# Activate it
source $HOME/.venvs/myenv/bin/activate

# Install packages
pip install numpy pandas scikit-learn

# Deactivate
deactivate
```

In your job script:

```bash
#!/bin/bash
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=8G
#SBATCH --time=04:00:00

module purge
module load stack/2025-06
module load python/3.11.6

source $HOME/.venvs/myenv/bin/activate

python my_script.py
```

### Option 3: Conda / Miniforge

Conda is **not centrally installed** on Euler — users install it themselves.

> **WARNING:** Conda creates tens of thousands of small files. Lustre (Scratch, Work) is
> poorly suited for this. Use the **Home** directory for conda environments, but be aware
> of the 500 000 file limit. For large environments, prefer a container instead.

```bash
# Download and install Miniforge (recommended over Anaconda/Miniconda)
module load eth_proxy
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash Miniforge3-Linux-x86_64.sh -b -p $HOME/miniforge3

# Initialise (adds activation to ~/.bashrc)
$HOME/miniforge3/bin/conda init bash
source ~/.bashrc

# Create an environment
conda create -n myenv python=3.11
conda activate myenv
conda install numpy pytorch torchvision -c pytorch

# Check file count (stay well under 500 000)
find $HOME/miniforge3 -type f | wc -l
```

Recommended storage for conda:

| Location | Suitability | Notes |
|---|---|---|
| `$HOME` | OK for small envs | 500 000 file limit — watch out with large PyTorch/JAX envs |
| `$SCRATCH` | Temporary only | Purged after 15 days — not suitable for persistent envs |
| `$SCRATCH` + archive | Acceptable | Tar the env; unpack at job start into `$TMPDIR` |
| Container (`.sif`) | **Best** | Encapsulates all files; no quota issues |

---

## Custom Software with Spack

Euler's Spack instance allows you to install packages not in the central stack, using
the central stack's dependencies.

```bash
# Activate the Spack instance for the 2025-06 stack
. /cluster/software/stacks/2025-06/setup-env.sh

# Search for a package
spack list <name>

# Show available versions
spack versions <name>

# Install (run on a compute node with eth_proxy — installations are CPU-intensive)
module load eth_proxy
srun -c 8 spack install <package>@<version> %gcc@12
```

> **NOTE:** Spack installations can take a long time and substantial CPU. Always run
> `spack install` on a compute node via `srun`, not on a login node.

---

## Recommended `.bashrc` Setup

```bash
# ~/.bashrc — Euler recommended baseline

# Load the latest software stack
module load stack/2025-06

# Load internet proxy (useful on login nodes; compute nodes need it in job scripts)
# module load eth_proxy    # uncomment if you need it interactively

# Apptainer cache → Scratch (avoids filling Home)
export APPTAINER_CACHEDIR="$SCRATCH/.apptainer"
export APPTAINER_TMPDIR="${TMPDIR:-/tmp}"

# Optional: set a default Slurm account (if member of multiple shareholder groups)
# export SLURM_ACCOUNT=<your_share_name>
```

---

## Common Issues

| Problem | Cause | Fix |
|---|---|---|
| `module load X` fails with "not found" | No stack loaded | Run `module load stack/2025-06` first |
| `module load X/version` fails | Module requires a prerequisite | Run `module spider X/version` — output lists the full load sequence |
| Job fails: `python: command not found` | Module not loaded in job script | Add `module load stack/2025-06` + `module load python/...` to the script |
| `pip install` hangs on compute node | No internet access | Add `module load eth_proxy` to the script before `pip install` |
| Conda env hits file limit | Too many small files | Migrate to a container; or tar the env and unpack into `$TMPDIR` |
| NVCC compilation fails with GCC 13+ | CUDA 12.x incompatible with GCC > 12 | Use `module load gcc/12.2.0` before loading CUDA |