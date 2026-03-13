#!/bin/bash
# =============================================================================
# SLURM Job Array Template
# =============================================================================
# Use this template for running the same script multiple times in parallel with
# different inputs — hyperparameter sweeps, dataset shards, cross-validation
# folds, seed replication, etc.
#
# Submit:
#   sbatch array-job.sh
#
# Submit with a specific range (overrides --array below):
#   sbatch --array=0-7 array-job.sh
#
# Limit concurrency to N simultaneous tasks:
#   sbatch --array=0-31%8 array-job.sh
# =============================================================================

# ── Identity ──────────────────────────────────────────────────────────────────
#SBATCH --job-name=<JOB_NAME>_array
#SBATCH --array=0-7                  # Task IDs to run (inclusive). Edit range as needed.
                                     # %N suffix limits N tasks running at once, e.g. 0-31%4

# ── Resources ─────────────────────────────────────────────────────────────────
#SBATCH --partition=<PARTITION>
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=<N_CPUS>     # CPU cores available to each task
#SBATCH --mem=<MEM>G                 # Memory per task (e.g. 32G)
#SBATCH --time=<HH:MM:SS>            # Wall-clock limit per task (e.g. 04:00:00)
#SBATCH --gres=gpu:<N_GPUS>          # GPUs per task — remove line if no GPU needed

# ── Output & Logging ──────────────────────────────────────────────────────────
# %A = array job ID, %a = individual task ID
#SBATCH --output=logs/%A_%a.out
#SBATCH --error=logs/%A_%a.err

# ── Notifications (optional) ──────────────────────────────────────────────────
#SBATCH --mail-type=ARRAY_TASKS,FAIL
#SBATCH --mail-user=<YOUR_EMAIL>

# ── Account / QoS (if required) ───────────────────────────────────────────────
#SBATCH --account=<ACCOUNT>
#SBATCH --qos=<QOS>

# =============================================================================
# Environment Setup
# =============================================================================

set -euo pipefail   # Exit on error, unset variable, or pipe failure

echo "========================================================"
echo "Job array ID  : $SLURM_ARRAY_JOB_ID"
echo "Task ID       : $SLURM_ARRAY_TASK_ID"
echo "Running on    : $(hostname)"
echo "Working dir   : $(pwd)"
echo "Start time    : $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================"

# Create log directory if it does not exist
mkdir -p logs

# Load required modules — always load explicitly inside the script
module purge
module load <MODULE_NAME>/<VERSION>    # e.g. cuda/12.1, python/3.11, ...

# Activate Python / conda environment (choose one approach)
# Option A — conda:
# source activate <ENV_NAME>
# Option B — venv:
# source <VENV_PATH>/bin/activate

# =============================================================================
# Map Task ID → Configuration
# =============================================================================
# Choose the mapping strategy that fits your use case.
# Only ONE of the strategies below should be active at a time.

# ── Strategy 1: Parallel config files ─────────────────────────────────────────
# Place one config file per task in a directory.
# Files should be named 0.yaml, 1.yaml, ..., N.yaml (matching task IDs).
#
# CONFIG_DIR="configs/sweep"
# CONFIG_FILE="${CONFIG_DIR}/${SLURM_ARRAY_TASK_ID}.yaml"
# if [[ ! -f "$CONFIG_FILE" ]]; then
#     echo "ERROR: config file not found: $CONFIG_FILE" >&2
#     exit 1
# fi

# ── Strategy 2: Inline parameter lists ────────────────────────────────────────
# Define arrays of values; index into them with the task ID.
# Each array must have the same number of elements as your --array range.
#
LEARNING_RATES=(1e-4 5e-4 1e-3 5e-3 1e-2 5e-2 1e-1 5e-1)
SEEDS=(0 1 2 3 4 5 6 7)

LR="${LEARNING_RATES[$SLURM_ARRAY_TASK_ID]}"
SEED="${SEEDS[$SLURM_ARRAY_TASK_ID]}"

echo "Task $SLURM_ARRAY_TASK_ID → LR=$LR  SEED=$SEED"

# ── Strategy 3: Arithmetic ranges ─────────────────────────────────────────────
# Useful for dataset shards — each task processes one contiguous chunk.
#
# TOTAL_SHARDS=8
# SHARD_ID=$SLURM_ARRAY_TASK_ID
#
# TOTAL_RECORDS=800000
# RECORDS_PER_SHARD=$(( TOTAL_RECORDS / TOTAL_SHARDS ))
# START_IDX=$(( SHARD_ID * RECORDS_PER_SHARD ))
# END_IDX=$(( START_IDX + RECORDS_PER_SHARD - 1 ))
# echo "Task $SHARD_ID → records $START_IDX–$END_IDX"

# =============================================================================
# Output Directory
# =============================================================================

OUTPUT_DIR="<OUTPUT_BASE_DIR>/task_${SLURM_ARRAY_TASK_ID}"
mkdir -p "$OUTPUT_DIR"

# =============================================================================
# Main Command
# =============================================================================

# NOTE: Replace the command below with your actual workload.
# All SLURM_* variables are available here as environment variables.

python <YOUR_SCRIPT>.py \
    --lr         "$LR" \
    --seed       "$SEED" \
    --output-dir "$OUTPUT_DIR"

# For config-file strategy (Strategy 1), use:
# python <YOUR_SCRIPT>.py --config "$CONFIG_FILE" --output-dir "$OUTPUT_DIR"

# For shard strategy (Strategy 3), use:
# python <YOUR_SCRIPT>.py --start-idx "$START_IDX" --end-idx "$END_IDX" \
#     --output-dir "$OUTPUT_DIR"

# =============================================================================
# Post-Run Bookkeeping
# =============================================================================

echo "========================================================"
echo "Task $SLURM_ARRAY_TASK_ID finished at $(date '+%Y-%m-%d %H:%M:%S')"
echo "Output written to: $OUTPUT_DIR"
echo "========================================================"
