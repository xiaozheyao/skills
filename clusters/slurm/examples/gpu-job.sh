#!/bin/bash
# =============================================================================
# SLURM GPU Job Template
# =============================================================================
# Usage:
#   sbatch gpu-job.sh
#   sbatch --partition=<PARTITION> --gres=gpu:<N> gpu-job.sh   # override inline
#
# Replace all <PLACEHOLDERS> with real values before submitting.
# =============================================================================

# -----------------------------------------------------------------------------
# Job metadata
# -----------------------------------------------------------------------------
#SBATCH --job-name=<JOB_NAME>
#SBATCH --comment="<Optional human-readable description of this run>"

# -----------------------------------------------------------------------------
# Resource requests
# -----------------------------------------------------------------------------
#SBATCH --partition=<PARTITION>          # Target partition (e.g. gpu, gpu-a100)
#SBATCH --nodes=1                        # Number of nodes
#SBATCH --ntasks=1                       # Number of tasks (1 for single-process jobs)
#SBATCH --cpus-per-task=<N_CPUS>         # CPU cores available to each task (e.g. 8)
#SBATCH --mem=<MEM>G                     # Total memory per node (e.g. 64G)
#SBATCH --gres=gpu:<GPU_TYPE>:<N_GPUS>   # GPUs: type and count (e.g. gpu:a100:1)
                                         # Omit type to accept any GPU: --gres=gpu:1
#SBATCH --time=<HH:MM:SS>               # Wall-clock time limit (e.g. 12:00:00)

# -----------------------------------------------------------------------------
# QoS / account (required on many clusters)
# -----------------------------------------------------------------------------
#SBATCH --account=<ACCOUNT>             # Project / charge account
#SBATCH --qos=<QOS>                     # Quality of service tier (e.g. normal, high)

# -----------------------------------------------------------------------------
# Output and error logs
# Tokens: %j = job ID, %x = job name, %A = array job ID, %a = array task ID
# -----------------------------------------------------------------------------
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

# -----------------------------------------------------------------------------
# Email notifications (optional — comment out if not needed)
# -----------------------------------------------------------------------------
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=<YOUR_EMAIL>

# -----------------------------------------------------------------------------
# Fault tolerance (optional)
# -----------------------------------------------------------------------------
# Automatically requeue the job if the node fails (not on user error):
##SBATCH --requeue

# =============================================================================
# Setup
# =============================================================================

set -euo pipefail   # exit on error, unset variable, or pipe failure

echo "======================================================================"
echo "Job ID        : $SLURM_JOB_ID"
echo "Job Name      : $SLURM_JOB_NAME"
echo "Node          : $SLURMD_NODENAME"
echo "CPUs/task     : $SLURM_CPUS_PER_TASK"
echo "GPUs          : $SLURM_GPUS_ON_NODE"
echo "Submit dir    : $SLURM_SUBMIT_DIR"
echo "Start time    : $(date)"
echo "======================================================================"

# Create log directory if it does not exist
mkdir -p logs

# Move to the directory from which the job was submitted
cd "$SLURM_SUBMIT_DIR"

# -----------------------------------------------------------------------------
# Load required modules
# NOTE: Always load modules here, not just interactively. The job runs in a
#       clean shell environment where nothing is pre-loaded.
# -----------------------------------------------------------------------------
module purge
module load <MODULE_1>          # e.g. cuda/12.1
module load <MODULE_2>          # e.g. cudnn/8.9
# module load <MODULE_3>        # add more as needed

echo "Loaded modules:"
module list

# -----------------------------------------------------------------------------
# Activate Python / Conda environment (choose one approach)
# -----------------------------------------------------------------------------

# Option A: Conda environment
# source "$(conda info --base)/etc/profile.d/conda.sh"
# conda activate <CONDA_ENV_NAME>

# Option B: venv / virtualenv
# source <PATH_TO_VENV>/bin/activate

# Option C: uv
# source <PATH_TO_VENV>/.venv/bin/activate

echo "Python        : $(which python)"
echo "Python version: $(python --version)"

# -----------------------------------------------------------------------------
# Confirm GPU visibility
# -----------------------------------------------------------------------------
echo ""
echo "--- GPU Info ---"
nvidia-smi
echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
echo "----------------"
echo ""

# =============================================================================
# Main workload
# =============================================================================
# Replace the command(s) below with your actual workload.
# Pass $SLURM_CPUS_PER_TASK to any multi-threaded library that needs it.
# -----------------------------------------------------------------------------

python <YOUR_SCRIPT>.py \
    --config <CONFIG_FILE> \
    --output-dir <OUTPUT_DIR> \
    --num-workers "$SLURM_CPUS_PER_TASK"
    # Add more arguments as needed

# =============================================================================
# Teardown
# =============================================================================

echo ""
echo "======================================================================"
echo "End time      : $(date)"
echo "Job $SLURM_JOB_ID finished."
echo "======================================================================"
