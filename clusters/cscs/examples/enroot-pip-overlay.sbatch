#!/bin/bash
#SBATCH --job-name=enroot-pip-overlay
#SBATCH --time=00:45:00
#SBATCH --partition=debug
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=72
#SBATCH --exclusive
# NOTE: SLURM parses --output/--error BEFORE bash runs, so they can't use env vars.
#       Point them at a Lustre dir you own; replace <IMAGES_DIR> below.
#SBATCH --output=<IMAGES_DIR>/overlay.%j.log
#SBATCH --error=<IMAGES_DIR>/overlay.%j.err

# Layer extra pip packages ON TOP OF an existing enroot .sqsh image — no ~1.5 h podman
# rebuild. Flow: enroot create -> start --root --rw + pip install -> export to a NEW .sqsh.
# A patch-level pip bump on a ~32 GB image takes ~1 minute.
#
# Submit (Clariden / aarch64):
#   sbatch -A infra02 \
#     --export=ALL,SRC_SQSH=<IMAGES_DIR>/<image>.aarch64.sqsh,FE_OVERLAY_PIP="<pkg>==<ver>" \
#     enroot-pip-overlay.sbatch
# Bristen / x86_64: use -A a-infra02 and the x86_64 .sqsh.
#
# Knobs (env):
#   SRC_SQSH        source image (required)
#   DST_SQSH        output image (default: ${SRC_SQSH%.sqsh}.overlay.sqsh)
#   FE_OVERLAY_PIP  packages to install (e.g. "flash-sandbox==0.2.8")
#
# NOTE: writes a NEW .sqsh; never overwrites SRC_SQSH (a running job / the EDF may still
#       reference it). Adopt by pointing ~/.edf/<name>.toml `image = ` at DST_SQSH, or — once
#       validated and no job is reading it — `mv` DST over SRC.
# NOTE: enroot export can exit non-zero AFTER writing a good .sqsh — verify by file size.

set -euo pipefail
echo "=== pip-overlay started $(date) on $(hostname) ($(uname -m)) ==="

: "${SRC_SQSH:?set SRC_SQSH to the source .sqsh}"
DST_SQSH="${DST_SQSH:-${SRC_SQSH%.sqsh}.overlay.sqsh}"
FE_OVERLAY_PIP="${FE_OVERLAY_PIP:?set FE_OVERLAY_PIP to the package(s) to install}"
[ -s "$SRC_SQSH" ] || { echo "!!! source image not found: $SRC_SQSH" >&2; exit 1; }
echo "  SRC=$SRC_SQSH  DST=$DST_SQSH  PKG=$FE_OVERLAY_PIP"

# Diskless GH200 nodes: /dev/shm (RAM tmpfs) is the only node-local store. Point every
# enroot path there; /run/user/$UID is absent on compute nodes so set XDG_RUNTIME_DIR too.
SHM_ROOT=/dev/shm/$USER
export XDG_RUNTIME_DIR="$SHM_ROOT/run"
export ENROOT_DATA_PATH="$SHM_ROOT/enroot/data"
export ENROOT_CACHE_PATH="$SHM_ROOT/enroot/cache"
export ENROOT_RUNTIME_PATH="$SHM_ROOT/enroot/runtime"
export ENROOT_TEMP_PATH="$SHM_ROOT/enroot/temp"
# A stale user-bus address from a --export=ALL login shell points at a dead socket on the
# compute node; unset it (same STEP-1 killer class as the podman build).
unset DBUS_SESSION_BUS_ADDRESS || true
mkdir -p "$XDG_RUNTIME_DIR" "$ENROOT_DATA_PATH" "$ENROOT_CACHE_PATH" \
         "$ENROOT_RUNTIME_PATH" "$ENROOT_TEMP_PATH"

NAME="overlay-${SLURM_JOB_ID:-manual}"
cleanup() { enroot remove -f "$NAME" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

echo "=== enroot create ($NAME) from $SRC_SQSH ==="
enroot create --name "$NAME" "$SRC_SQSH"

echo "=== pip overlay: $FE_OVERLAY_PIP ==="
enroot start --root --rw \
    --env "FE_OVERLAY_PIP=$FE_OVERLAY_PIP" \
    --env "https_proxy=${https_proxy:-}" \
    --env "http_proxy=${http_proxy:-}" \
    "$NAME" bash -c '
        set -euo pipefail
        echo "--- before ---"; pip list 2>/dev/null | tail -n +1 >/dev/null
        pip install --no-cache-dir ${FE_OVERLAY_PIP}
        echo "--- after  ---"; python -c "print(\"overlay pip install OK\")"
    '

echo "=== enroot export -> $DST_SQSH ==="
[ -f "$DST_SQSH" ] && rm -f "$DST_SQSH"
enroot export --output "$DST_SQSH" "$NAME" || echo "  (export rc!=0; verifying by size)"
if [ ! -s "$DST_SQSH" ] || [ "$(stat -c %s "$DST_SQSH")" -lt 20000000000 ]; then
    echo "!!! $DST_SQSH missing or too small (<20 GB) — export really failed" >&2
    exit 1
fi

ls -lh "$SRC_SQSH" "$DST_SQSH"
echo "Adopt: point ~/.edf/<name>.toml 'image = ' at $DST_SQSH"
echo "=== pip-overlay finished $(date) ==="
