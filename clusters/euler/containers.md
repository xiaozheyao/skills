# Euler — Containers (Apptainer / Singularity)

Apptainer (formerly Singularity) is the **primary recommended way to run custom, complex,
or reproducible software environments on Euler**. Because users have no `sudo` access and
cannot install system packages, containers let you bring your entire software stack —
including any Linux distribution, Python version, CUDA runtime, or compiled library —
packaged as a single portable `.sif` file.

Official docs: https://docs.hpc.ethz.ch/software/apptainer/

> **For Claude Code:** When a task on Euler requires software not available in the module
> system, or needs a specific environment (e.g. a particular PyTorch + CUDA version), the
> answer is almost always **Apptainer**. Default to containers over Conda when possible on
> Euler — Conda creates thousands of small files that degrade Lustre performance.

---

## What is Apptainer / Singularity?

Apptainer and Singularity are the same project (Apptainer is the current name after
Singularity was contributed to the Linux Foundation). The command-line tool is called
`apptainer`, but `singularity` still works as an alias on Euler for backward compatibility.

Key differences from Docker:
- **No daemon, no root required to run** — safe on shared HPC systems
- Containers run as the invoking user, not as root
- The host filesystem is accessible via bind mounts
- Single-file images (`.sif`) are portable and immutable

---

## One-Time Setup

### 1. Request access

Apptainer is installed as an OS package (no `module load` needed), but access is
restricted for security reasons. Run this **once** on a login node:

```bash
(remote) $ get-access
```

Follow any prompts. Your account will be added to the `ID-HPC-SINGULARITY` group.

### 2. Verify access

After `get-access` completes (may take a moment to propagate), confirm:

```bash
(remote) $ id | grep ID-HPC-SINGULARITY
```

If the command returns output, you have access. If it returns nothing, wait a few
minutes and try again. If it still fails, contact cluster support.

### 3. Configure cache and tmp directories

Add these two lines to your `~/.bashrc` on Euler. They redirect Apptainer's working
files away from your 50 GB Home quota:

```bash
export APPTAINER_CACHEDIR="$SCRATCH/.apptainer"
export APPTAINER_TMPDIR="${TMPDIR:-/tmp}"
```

After saving, reload:

```bash
(remote) $ source ~/.bashrc
(remote) $ mkdir -p "$APPTAINER_CACHEDIR"
```

| Variable | Purpose | Why this location |
|---|---|---|
| `APPTAINER_CACHEDIR` | Stores pulled/converted image layers | Scratch has 2.5 TB; cache is safe to delete |
| `APPTAINER_TMPDIR` | Temporary files during image builds/conversions | Node-local `/tmp` is fast and ephemeral |

> **WARNING:** The Apptainer cache lives in `$SCRATCH` and is subject to the 15-day
> auto-purge. Cached layers will be re-downloaded if purged. Store your final `.sif`
> files in `$HOME` or a Project/Work share — **not** in the cache directory.

---

## Building Container Images

> **Container images cannot be built directly on Euler.** Building requires root
> privileges, which are not available to users. You must build images on a machine
> where you have root or `sudo` access (your laptop, a local server, or a CI system),
> then transfer the `.sif` file to Euler.

### Option A — Build from a Dockerfile on your local machine

```bash
# On your LOCAL machine (requires Docker + Apptainer/Singularity installed):

# 1. Build the Docker image
docker build -t my_image:latest .

# 2. Convert it to a .sif file
apptainer build my_image.sif docker-daemon://my_image:latest

# 3. Transfer to Euler
rsync -avh my_image.sif euler:/cluster/home/<username>/containers/
```

### Option B — Build from an Apptainer definition file (`.def`)

```bash
# my_env.def — example definition file
Bootstrap: docker
From: nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

%post
    apt-get update && apt-get install -y python3 python3-pip git
    pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
    pip3 install numpy pandas scikit-learn

%environment
    export PYTHONPATH=/usr/local/lib/python3/dist-packages:$PYTHONPATH

%labels
    Author <your_name>
    Version 1.0
```

```bash
# Build on your LOCAL machine (requires root or --fakeroot):
sudo apptainer build my_env.sif my_env.def

# Transfer to Euler
rsync -avh my_env.sif euler:/cluster/home/<username>/containers/
```

### Option C — Pull a pre-built image directly on Euler

You can pull public images directly on Euler, but **compute nodes need `eth_proxy`** for
internet access. Do this on a login node or inside a job with `eth_proxy` loaded.

```bash
(remote) $ module load eth_proxy    # internet access for login nodes too

# From Docker Hub
(remote) $ apptainer pull docker://pytorch/pytorch:2.1.0-cuda12.1-cudnn8-runtime

# From NVIDIA NGC (optimised CUDA containers)
(remote) $ apptainer pull docker://nvcr.io/nvidia/pytorch:24.01-py3

# From Sylabs Library
(remote) $ apptainer pull library://sylabs/examples/lolcow:latest
```

Pulled images are stored in `$APPTAINER_CACHEDIR` and a `.sif` is created in the
current directory. Move the `.sif` to `$HOME/containers/` for long-term storage.

---

## Running Containers

### Core commands

| Command | Purpose |
|---|---|
| `apptainer exec <image.sif> <command>` | Run a single command inside the container |
| `apptainer shell <image.sif>` | Open an interactive shell inside the container |
| `apptainer run <image.sif>` | Run the container's default `%runscript` |
| `apptainer inspect <image.sif>` | Show image metadata and labels |

`singularity` is a valid alias for `apptainer` — both work on Euler.

### Running a command

```bash
(remote) $ apptainer exec my_image.sif python3 train.py --config config.yaml
```

### Interactive shell (for debugging)

```bash
(remote) $ apptainer shell my_image.sif
Apptainer> python3 --version
Apptainer> exit
```

---

## Bind Mounts — Accessing Euler's Filesystems Inside the Container

By default, Apptainer auto-binds your home directory. However, `$SCRATCH`, `$TMPDIR`,
and group storage paths must be explicitly bound.

```bash
apptainer exec \
    --bind $SCRATCH:/scratch \
    --bind $TMPDIR:/tmp \
    my_image.sif \
    python3 train.py --data /scratch/dataset --output /scratch/outputs
```

### Bind mount syntax

```
--bind <host_path>:<container_path>
```

Multiple `--bind` flags are allowed. The container path does not need to pre-exist in
the image when using `--bind` (Apptainer creates it at runtime).

### Recommended bind mounts for most Euler jobs

```bash
apptainer exec \
    --bind $SCRATCH:/scratch \
    --bind $TMPDIR:/tmp \
    --bind /cluster/project/<group>:/project \   # if using group storage
    my_image.sif <command>
```

> **Always bind `$SCRATCH` and `$TMPDIR`** in your job scripts. Without this, paths
> like `/cluster/scratch/...` are inaccessible inside the container, and jobs that
> write to the default `/tmp` (which maps to the host `/tmp` of unknown size) may run
> out of space.

---

## GPU Containers

To give the container access to the host NVIDIA drivers and CUDA libraries, add `--nv`:

```bash
apptainer exec --nv \
    --bind $SCRATCH:/scratch \
    my_cuda_image.sif \
    python3 train.py
```

The `--nv` flag:
- Injects the host NVIDIA driver libraries into the container at runtime
- Makes `nvidia-smi` and CUDA work inside the container
- Does **not** require CUDA to be installed on the host — the driver is sufficient
- The CUDA version **inside** the container must be ≤ the host driver version

### Requesting GPUs in a SLURM job

```bash
#SBATCH --gpus=1               # any GPU
#SBATCH --gpus=rtx_4090:1      # specific model (only if required)
```

Then inside the job script:

```bash
apptainer exec --nv \
    --bind $SCRATCH:/scratch \
    my_cuda_image.sif \
    python3 train.py
```

### Confirming GPU visibility inside the container

```bash
apptainer exec --nv my_cuda_image.sif nvidia-smi
apptainer exec --nv my_cuda_image.sif python3 -c "import torch; print(torch.cuda.is_available())"
```

---

## Environment Variables Inside Containers

By default, Apptainer passes your current shell environment into the container.
To pass only specific variables, or to set new ones:

```bash
# Pass a specific variable
MYVAR=hello apptainer exec my_image.sif bash -c 'echo $MYVAR'

# Set a variable only inside the container using APPTAINERENV_ prefix
export APPTAINERENV_MYVAR="inside_value"
apptainer exec my_image.sif bash -c 'echo $MYVAR'

# Run in a clean environment (no host env vars leaked)
apptainer exec --cleanenv my_image.sif python3 script.py
```

For CUDA, the `--nv` flag also sets `CUDA_VISIBLE_DEVICES` from the SLURM allocation.

---

## MPI Containers

For multi-node MPI jobs with containers, the MPI library must be built **inside the
container** (matching the host's OpenMPI version and compiled with UCX for performance).

### Setup

```bash
# Import the Slurm integration data from Euler to your local machine:
$ scp -r <username>@euler.ethz.ch:/cluster/apps/slurm ./slurm-libs

# Copy the slurm libs into your container build context (Dockerfile or .def)
```

### Example batch script for MPI container job

```bash
#!/bin/bash
#SBATCH -n 4
#SBATCH -N 2
#SBATCH --ntasks-per-node=2
#SBATCH --constraint=ib          # require InfiniBand nodes
#SBATCH --time=00:30:00
#SBATCH --exclusive
#SBATCH --contiguous

module load openmpi

mpirun -np 4 apptainer exec \
    --bind $SCRATCH:/scratch \
    my_mpi_image.sif \
    /path/to/mpi_program
```

Full MPI example: https://gitlab.ethz.ch/hpc-applications/mpi-test

---

## Full Job Script Examples

See [examples/](examples/) for complete, ready-to-submit scripts. The two primary ones:

- [`apptainer-gpu-job.sh`](examples/apptainer-gpu-job.sh) — GPU training job with a container
- [`apptainer-array-job.sh`](examples/apptainer-array-job.sh) — Job array sweep with containers

### Minimal GPU container job

```bash
#!/bin/bash
#SBATCH --job-name=train_container
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=8G
#SBATCH --gpus=1
#SBATCH --time=12:00:00
#SBATCH --output=logs/%j.out
#SBATCH --error=logs/%j.err

set -euo pipefail

SIF=$HOME/containers/my_image.sif
WORKDIR=$SCRATCH/runs/$SLURM_JOB_ID

mkdir -p "$WORKDIR" logs

apptainer exec --nv \
    --bind $SCRATCH:/scratch \
    --bind $TMPDIR:/tmp \
    "$SIF" \
    python3 train.py \
        --output-dir /scratch/runs/$SLURM_JOB_ID \
        --num-workers $SLURM_CPUS_PER_TASK
```

---

## Workflow: From Dockerfile to Running on Euler

This is the end-to-end sequence for the most common use case.

```
1. Write a Dockerfile on your local machine
2. docker build -t my_env:latest .
3. apptainer build my_env.sif docker-daemon://my_env:latest
4. rsync -avh my_env.sif euler:~/containers/
5. On Euler: verify access with `id | grep ID-HPC-SINGULARITY`
6. Write a job script using `apptainer exec --nv --bind $SCRATCH:/scratch ~/containers/my_env.sif`
7. sbatch my_job.sh
8. Monitor with `myjobs`
```

---

## Troubleshooting

### Cannot run Apptainer — not in group

```bash
(remote) $ id | grep ID-HPC-SINGULARITY
# → empty output means no access
(remote) $ get-access
# → follow prompts, then wait a few minutes and check again
```

### Container fails with "permission denied" on /scratch

You forgot to bind the scratch path. Add `--bind $SCRATCH:/scratch` to your command.

### `CUDA_VISIBLE_DEVICES` is empty / GPU not found inside container

- Confirm you added `--nv` to the `apptainer exec` command.
- Confirm the SLURM job requested a GPU (`--gpus=1` or similar).
- Check the CUDA version in your container is compatible with the host driver:
  ```bash
  (remote) $ apptainer exec --nv my_image.sif nvidia-smi
  ```

### Apptainer cache fills Home quota

You forgot to set `APPTAINER_CACHEDIR`. Check:
```bash
echo $APPTAINER_CACHEDIR   # should be under $SCRATCH, not $HOME
```
If it's empty or pointing to `~/.apptainer`, add the export to your `~/.bashrc`.

### Image build fails / `TMPDIR` issues

Set `APPTAINER_TMPDIR` to a location with sufficient space:
```bash
export APPTAINER_TMPDIR="${TMPDIR:-/tmp}"
```
If building locally and `/tmp` is too small, point to a larger directory.

### Container runs fine interactively but fails in a batch job

Most common causes:
1. **Missing bind mount** — the path exists on the login node but is not bound inside
   the container in the job script.
2. **Missing `--nv`** — GPU not available in batch mode without the flag.
3. **Environment leak** — use `--cleanenv` and set explicit `APPTAINERENV_*` variables
   for reproducibility.
4. **No internet in compute node** — add `module load eth_proxy` if the container tries
   to download anything at runtime.

---

## Best Practices Summary

| Practice | Reason |
|---|---|
| Store `.sif` files in `$HOME/containers/` or Project | Prevents 15-day purge from losing your image |
| Set `APPTAINER_CACHEDIR=$SCRATCH/.apptainer` in `.bashrc` | Keeps Home quota free |
| Always `--bind $SCRATCH:/scratch --bind $TMPDIR:/tmp` | Ensures job I/O paths are accessible |
| Always add `--nv` for GPU jobs | GPU is invisible without it |
| Build images locally, not on Euler | Euler has no root access |
| Prefer containers over Conda on Lustre filesystems | Conda small-file explosion degrades Lustre |
| Use `--cleanenv` + `APPTAINERENV_*` for reproducible jobs | Avoids host environment leaking into container |
| Pull with `module load eth_proxy` active | Compute nodes have no direct internet |