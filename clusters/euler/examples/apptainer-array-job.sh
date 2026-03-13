#!/bin/bash
# =============================================================================
# Euler — Job Array with Apptainer/Singularity
# =============================================================================
# Runs the same containerised command multiple times in parallel, each task
# receiving a different parameter set via $SLURM_ARRAY_TASK_ID.
#
# Common use-cases:
#   - Hyperparameter sweeps
#   - Dataset shards / cross-validation folds
#   - Replicated experiments with different random seeds
#
# Submit:
#   mkdir -p logs
#   sbatch apptainer-array-job.sh
#
# Submit with an override range (ignores --array below):
#   sbatch --array=0-3 apptainer-array-job.sh
#
# Limit concurrency (e.g. at most 4 running at once):
#   sbatch --array=0-15%4 apptainer-array-job.sh
#
# Replace all <PLACEHOLDERS> with real values before submitting.
# =============================================================================

# ── Identity ──────────────────────────────────────────────────────────────────
#SBATCH --job-name=<JOB_NAME>_array

# Task IDs to run. Adjust the range to match the number of configurations.
# %N suffix limits N tasks running simultaneously, e.g. 0-31%8
#SBATCH --array=0-7

# ── Resources (per task) ──────────────────────────────────────────────────────
# NOTE: Do NOT specify --partition on Euler. Euler manages partitions internally
#       and specifying one only slows down scheduling.
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=<N_CPUS>      # e.g. 8
#SBATCH --mem-per-cpu=<MEM_PER_CPU>   # e.g. 8G
#SBATCH --time=<HH:MM:SS>             # wall-clock limit per task, e.g. 04:00:00

# Remove the line below if this is a CPU-only job.
# Do NOT specify a GPU type (e.g. --gpus=a100:1) unless your code strictly
# requires it — constraining GPU type increases queue wait time.
#SBATCH --gpus=1

# Request node-local scratch if your workload writes many small files.
# The path is available as $TMPDIR inside the job.
##SBATCH --tmp=50G

# ── Output & Logging ──────────────────────────────────────────────────────────
# %A = array job ID, %a = individual task ID, %x = job name
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err

# ── Account (optional) ────────────────────────────────────────────────────────
# Specify your shareholder group if you belong to more than one.
# The free public share for all ETH members is named "public".
##SBATCH --account=<SHARE_NAME>

# =============================================================================
# Environment
# =============================================================================

set -euo pipefail

echo "========================================================"
echo "Array Job ID  : $SLURM_ARRAY_JOB_ID"
echo "Task ID       : $SLURM_ARRAY_TASK_ID"
echo "Host          : $(hostname)"
echo "Submit dir    : $SLURM_SUBMIT_DIR"
echo "Start time    : $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================"

# Create the log directory (in case it does not exist yet).
mkdir -p logs

# Move to the submission directory so relative paths work correctly.
cd "$SLURM_SUBMIT_DIR"

# ── Apptainer environment setup ───────────────────────────────────────────────
# These should already be in your ~/.bashrc on Euler, but we set them
# explicitly here to guarantee correct behaviour inside the job.
export APPTAINER_CACHEDIR="$SCRATCH/.apptainer"
export APPTAINER_TMPDIR="${TMPDIR:-/tmp}"

# Path to the .sif image file.
# Store images in $HOME or group Project storage — NOT in the Apptainer cache
# directory ($SCRATCH/.apptainer), which is subject to the 15-day purge.
SIF="$HOME/containers/<IMAGE_NAME>.sif"

if [[ ! -f "$SIF" ]]; then
    echo "ERROR: container image not found: $SIF" >&2
    echo "Build it locally and rsync it to Euler. See containers.md." >&2
    exit 1
fi

# ── Verify Apptainer access ───────────────────────────────────────────────────
if ! id | grep -q ID-HPC-SINGULARITY; then
    echo "ERROR: Apptainer access not enabled." >&2
    echo "Run 'get-access' on a login node, then resubmit." >&2
    exit 1
fi

# =============================================================================
# Map Task ID → Configuration
# =============================================================================
# Choose ONE strategy below and comment out the others.

# ── Strategy 1: Inline parameter arrays ───────────────────────────────────────
# Define an array of values per hyperparameter. Each index corresponds to one
# task. All arrays must have the same number of elements as your --array range.
LEARNING_RATES=(1e-5 3e-5 1e-4 3e-4 1e-3 3e-3 1e-2 3e-2)
SEEDS=(0         1    2    3    4    5    6    7   )

LR="${LEARNING_RATES[$SLURM_ARRAY_TASK_ID]}"
SEED="${SEEDS[$SLURM_ARRAY_TASK_ID]}"

echo "Task $SLURM_ARRAY_TASK_ID → LR=$LR  SEED=$SEED"

# ── Strategy 2: Per-task config files ─────────────────────────────────────────
# Place one config file per task in a directory, named by task ID.
# Files: configs/sweep/0.yaml, configs/sweep/1.yaml, ..., configs/sweep/N.yaml
#
# CONFIG_DIR="$SLURM_SUBMIT_DIR/configs/sweep"
# CONFIG_FILE="$CONFIG_DIR/${SLURM_ARRAY_TASK_ID}.yaml"
# if [[ ! -f "$CONFIG_FILE" ]]; then
#     echo "ERROR: config file not found: $CONFIG_FILE" >&2
#     exit 1
# fi
# echo "Task $SLURM_ARRAY_TASK_ID → config: $CONFIG_FILE"

# ── Strategy 3: Arithmetic shards ─────────────────────────────────────────────
# Divide a fixed number of records evenly across tasks.
# Useful for dataset processing where each task handles one contiguous shard.
#
# TOTAL_RECORDS=80000
# TOTAL_SHARDS=8
# RECORDS_PER_SHARD=$(( TOTAL_RECORDS / TOTAL_SHARDS ))
# START_IDX=$(( SLURM_ARRAY_TASK_ID * RECORDS_PER_SHARD ))
# END_IDX=$(( START_IDX + RECORDS_PER_SHARD - 1 ))
# echo "Task $SLURM_ARRAY_TASK_ID → records $START_IDX–$END_IDX"

# =============================================================================
# Output Directory
# =============================================================================
# Each task writes to its own subdirectory under $SCRATCH.
# NOTE: $SCRATCH is automatically purged after 15 days — copy important results
#       to $HOME or group storage at the end of this script.

OUTPUT_DIR="$SCRATCH/runs/${SLURM_ARRAY_JOB_ID}/task_${SLURM_ARRAY_TASK_ID}"
mkdir -p "$OUTPUT_DIR"

echo "Output dir    : $OUTPUT_DIR"

# =============================================================================
# Optional: Stage data to node-local scratch for faster I/O
# =============================================================================
# Uncomment this block if your job reads many files (e.g. image datasets).
# Requires #SBATCH --tmp=<N>G above.
#
# DATA_SRC="$SCRATCH/<YOUR_DATASET>"
# DATA_LOCAL="$TMPDIR/dataset"
# echo "Staging data to node-local scratch..."
# rsync -aq "$DATA_SRC/" "$DATA_LOCAL/"
# echo "Staging complete."

# =============================================================================
# GPU check (only relevant if --gpus was requested)
# =============================================================================
echo ""
echo "--- GPU Info ---"
apptainer exec --nv "$SIF" nvidia-smi 2>/dev/null || echo "(No GPU requested or --nv not needed)"
echo "----------------"
echo ""

# =============================================================================
# Main Command — Apptainer exec
# =============================================================================
# Flags:
#   --nv                  Pass NVIDIA GPU drivers into the container.
#                         Remove this line for CPU-only jobs.
#   --bind src:dst        Bind-mount host paths into the container.
#                         Always bind $SCRATCH and $TMPDIR so your job can
#                         read and write data inside the container.
#   --cleanenv            (optional) Start with a clean environment inside the
#                         container. Use APPTAINERENV_* to pass specific vars.
# NOTE: Replace the python3 invocation below with your actual command.

apptainer exec \
    --nv \
    --bind "$SCRATCH":/scratch \
    --bind "$TMPDIR":/tmp \
    "$SIF" \
    python3 <YOUR_SCRIPT>.py \
        --lr           "$LR" \
        --seed         "$SEED" \
        --output-dir   "/scratch/runs/${SLURM_ARRAY_JOB_ID}/task_${SLURM_ARRAY_TASK_ID}" \
        --num-workers  "$SLURM_CPUS_PER_TASK"

# For Strategy 2 (config files):
# apptainer exec \
#     --nv \
#     --bind "$SCRATCH":/scratch \
#     --bind "$SLURM_SUBMIT_DIR/configs":/configs \
#     --bind "$TMPDIR":/tmp \
#     "$SIF" \
#     python3 <YOUR_SCRIPT>.py \
#         --config     "/configs/sweep/${SLURM_ARRAY_TASK_ID}.yaml" \
#         --output-dir "/scratch/runs/${SLURM_ARRAY_JOB_ID}/task_${SLURM_ARRAY_TASK_ID}"

# For Strategy 3 (dataset shards):
# apptainer exec \
#     --nv \
#     --bind "$SCRATCH":/scratch \
#     --bind "$TMPDIR":/tmp \
#     "$SIF" \
#     python3 <YOUR_SCRIPT>.py \
#         --start-idx  "$START_IDX" \
#         --end-idx    "$END_IDX" \
#         --output-dir "/scratch/runs/${SLURM_ARRAY_JOB_ID}/task_${SLURM_ARRAY_TASK_ID}"

# =============================================================================
# Post-run: copy important results to persistent storage
# =============================================================================
# $SCRATCH is purged after 15 days. Copy anything you need to keep to $HOME
# or group Project storage immediately after the run.
#
# Uncomment and adjust the block below:
# PERSISTENT_DIR="$HOME/results/${SLURM_ARRAY_JOB_ID}/task_${SLURM_ARRAY_TASK_ID}"
# mkdir -p "$PERSISTENT_DIR"
# rsync -auq "$OUTPUT_DIR/" "$PERSISTENT_DIR/"
# echo "Results saved to: $PERSISTENT_DIR"

# =============================================================================
echo ""
echo "========================================================"
echo "Task $SLURM_ARRAY_TASK_ID finished at $(date '+%Y-%m-%d %H:%M:%S')"
echo "Output: $OUTPUT_DIR"
echo "========================================================"
