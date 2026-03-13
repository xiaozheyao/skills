#!/bin/bash
# =============================================================================
# Euler — GPU Job with Apptainer/Singularity Container
# =============================================================================
# Runs a GPU workload inside an Apptainer (.sif) container on Euler.
#
# Usage:
#   sbatch apptainer-gpu-job.sh
#
# Prerequisites:
#   1. Run `get-access` on Euler once to enable Apptainer.
#   2. Build your .sif image locally and transfer it to Euler:
#        apptainer build my_image.sif docker-daemon://my_image:latest
#        rsync -avh my_image.sif euler:~/containers/
#   3. Set APPTAINER_CACHEDIR and APPTAINER_TMPDIR in your ~/.bashrc:
#        export APPTAINER_CACHEDIR="$SCRATCH/.apptainer"
#        export APPTAINER_TMPDIR="${TMPDIR:-/tmp}"
#
# Replace all <PLACEHOLDERS> with real values before submitting.
# =============================================================================

# ── Identity ──────────────────────────────────────────────────────────────────
#SBATCH --job-name=<JOB_NAME>

# ── Resources ─────────────────────────────────────────────────────────────────
# NOTE: Do NOT specify --partition on Euler. The scheduler manages this.
# NOTE: Do NOT specify GPU type unless your code strictly requires it.
#       Using --gpus=1 (no type) gives the fastest scheduling.
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=<N_CPUS>       # e.g. 8  (passed to DataLoader workers, etc.)
#SBATCH --mem-per-cpu=<MEM_PER_CPU>G   # e.g. 8  (total RAM = cpus-per-task × mem-per-cpu)
#SBATCH --gpus=<N_GPUS>                # e.g. 1  (any available GPU — preferred)
##SBATCH --gpus=a100:1                 # uncomment ONLY if a specific GPU model is required
#SBATCH --time=<HH:MM:SS>             # e.g. 12:00:00
#SBATCH --tmp=<TMP_GB>G               # node-local scratch via $TMPDIR (e.g. 50)

# ── Account (required if member of a shareholder group) ───────────────────────
##SBATCH --account=<SHARE_NAME>        # uncomment and set, e.g. es_mygroup
                                       # leave commented to use public share

# ── Output & Logging ──────────────────────────────────────────────────────────
#SBATCH --output=logs/%x_%j.out        # %x = job name, %j = job ID
#SBATCH --error=logs/%x_%j.err

# ── Notifications (optional) ──────────────────────────────────────────────────
##SBATCH --mail-type=BEGIN,END,FAIL
##SBATCH --mail-user=<your_email@ethz.ch>

# =============================================================================
# Environment
# =============================================================================

set -euo pipefail   # exit on error, unset variable, or pipe failure

# Purge any modules inherited from the submitting shell, then load a clean stack.
# NOTE: Euler jobs inherit the submitting shell's environment. Always purge first.
module purge
module load stack/2025-06             # load latest software stack

# Uncomment if this job needs to pull anything from the internet at runtime
# (e.g. downloading a dataset or pip-installing something inside the container):
# module load eth_proxy

# ── Paths ─────────────────────────────────────────────────────────────────────

# Path to your Apptainer image file.
# Store .sif files in $HOME or group Project storage — NOT in $SCRATCH
# (Scratch is purged after 15 days and the image would be lost).
SIF="$HOME/containers/<IMAGE_NAME>.sif"

# Per-job working directory on Scratch (fast Lustre NVMe storage).
# Each job gets its own directory named by job ID to avoid collisions.
WORKDIR="$SCRATCH/runs/$SLURM_JOB_ID"

mkdir -p "$WORKDIR" logs

# =============================================================================
# Pre-flight checks
# =============================================================================

echo "======================================================================"
echo "Job ID           : $SLURM_JOB_ID"
echo "Job name         : $SLURM_JOB_NAME"
echo "Node             : $SLURMD_NODENAME"
echo "CPUs/task        : $SLURM_CPUS_PER_TASK"
echo "GPUs on node     : $SLURM_GPUS_ON_NODE"
echo "Submit dir       : $SLURM_SUBMIT_DIR"
echo "Work dir         : $WORKDIR"
echo "Tmp dir          : $TMPDIR"
echo "Container image  : $SIF"
echo "Start time       : $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================================================"

# Verify the container image exists
if [[ ! -f "$SIF" ]]; then
    echo "ERROR: Container image not found: $SIF" >&2
    echo "Build locally and transfer with:" >&2
    echo "  rsync -avh <image>.sif euler:~/containers/" >&2
    exit 1
fi

# Verify Apptainer access
if ! id | grep -q ID-HPC-SINGULARITY; then
    echo "ERROR: You do not have Apptainer access." >&2
    echo "Run 'get-access' on a login node and wait a few minutes." >&2
    exit 1
fi

# Confirm GPU is visible to SLURM
echo ""
echo "--- Host GPU info (nvidia-smi) ---"
nvidia-smi
echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
echo "----------------------------------"
echo ""

# =============================================================================
# (Optional) Stage input data to node-local storage
# =============================================================================
# If your job does many small reads, copying data to $TMPDIR (fast NVMe on the
# compute node) can significantly improve throughput.
# Uncomment and adapt if needed:

# INPUT_DATA="$SCRATCH/<YOUR_DATASET_DIR>"
# echo "Staging input data to $TMPDIR/data ..."
# rsync -aq "$INPUT_DATA/" "$TMPDIR/data/"
# echo "Staging complete."

# =============================================================================
# Main workload — run inside the Apptainer container
# =============================================================================
#
# Key flags:
#   --nv          inject host NVIDIA driver + CUDA into the container (REQUIRED for GPU)
#   --bind        expose host directories inside the container
#
# Bind mounts used here:
#   $SCRATCH → /scratch    fast per-user Lustre storage (2.5 TB, 15-day purge)
#   $TMPDIR  → /tmp        node-local NVMe storage (fastest, gone when job ends)
#
# NOTE: Without --bind $SCRATCH, paths like /cluster/scratch/... are invisible
#       inside the container and your job will fail with "no such file" errors.
# =============================================================================

echo "Launching container workload ..."

apptainer exec \
    --nv \
    --bind "$SCRATCH:/scratch" \
    --bind "$TMPDIR:/tmp" \
    "$SIF" \
    python3 <YOUR_SCRIPT>.py \
        --output-dir "/scratch/runs/$SLURM_JOB_ID" \
        --num-workers "$SLURM_CPUS_PER_TASK" \
        --config     "<CONFIG_FILE>"
        # Add more arguments as needed.
        # Reference container-internal paths (e.g. /scratch/...) not host paths.

# =============================================================================
# Post-run: copy important results to persistent storage
# =============================================================================
# Scratch is purged after 15 days. Copy final artefacts (e.g. best checkpoint,
# metrics) to Home or group Project storage immediately after the job.

RESULT_DIR="$HOME/results/$SLURM_JOB_NAME/$SLURM_JOB_ID"
mkdir -p "$RESULT_DIR"

# Example: copy the best checkpoint and a metrics file
# Adjust the glob to match your actual output filenames.
rsync -auq "$WORKDIR/" "$RESULT_DIR/" || echo "WARNING: rsync of results failed."

echo ""
echo "======================================================================"
echo "End time    : $(date '+%Y-%m-%d %H:%M:%S')"
echo "Results     : $RESULT_DIR"
echo "Scratch dir : $WORKDIR  (will be purged after 15 days)"
echo "Job $SLURM_JOB_ID completed."
echo "======================================================================"
