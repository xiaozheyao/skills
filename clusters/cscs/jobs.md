# CSCS Alps — Jobs (SLURM)

## Accounts are mandatory and per-cluster

The default SLURM account is **unset** — jobs are rejected without `-A`:

| Target | Flag | Note |
|---|---|---|
| Clariden | `-A infra02` | |
| Bristen | `-A a-infra02` | NOT `infra02` |
| Reservation (e.g. Apertus) | `-A infra01` | NOT `infra02`; allocates **instantly** within the reservation |

```bash
(remote) $ sbatch -A infra02   meta/cscs/examples/gsm8k-async-2node-debug-clariden.sbatch
(remote) $ srun   -A infra02 --environment=flash-evolve-verl --pty bash
```

## Partitions

| Partition | Use | Notes |
|---|---|---|
| `debug` | Quick jobs, image builds, smoke tests | Fast allocation, short walltime cap; an image build (~1:10) fits |
| `normal` | Longer training / multi-hour builds | Use when a job exceeds the debug cap |

> Reservations allocate immediately regardless of partition pressure when you submit with
> the reservation's account (see above).

## `--environment` selects the container image

Pyxis maps `--environment=<name>` to `~/.edf/<name>.toml` (the EDF). See
[containers.md](containers.md). Every `srun --environment=...` step gets a **fresh
container overlay** — a file written into the container in one `srun` step is invisible to
another. Inline any in-container patching into the same `bash -c` block that later spawns
the work.

## Multi-node gotchas (Clariden, GH200 + Slingshot)

### 1. Secondary `srun` needs `--overlap` AND `--gres=none`

Inside a multi-node sbatch, the parent `ray start --block` srun holds the task slot **and**
the gres. A coordinator/polling `srun` that requests gres then blocks forever at step
creation. Pass **both** flags on every secondary step:

```bash
srun --overlap --gres=none --environment=... bash -c '...'
```

### 2. CSCS NCCL / Libfabric env is required

GH200 + Slingshot multi-node needs the AWS-OFI libfabric path, set via the runtime env
(e.g. Ray runtime env) and the `com.hooks.aws_ofi_nccl` EDF annotation:

```bash
NCCL_NET="AWS Libfabric"
NCCL_CROSS_NIC=1
FI_CXI_*  # rendezvous tuning — see https://docs.cscs.ch/software/communication/nccl/
```

Without this, 2-node Clariden jobs hang ~30 min then SIGABRT in the NCCL watchdog.
**Bristen (A100 / Ethernet) is unaffected.**

### 3. NCCL 2.27.5 hang → image pins 2.30.4

The container-bundled NCCL 2.27.5 hangs on GH200 + Slingshot multi-node param-sync; the
Dockerfile pins `nvidia-nccl-cu12==2.30.4`. If you rebuild the image, keep that pin.

### 4. `ROCR_VISIBLE_DEVICES` clash on GH200

The EDF sets `ROCR_VISIBLE_DEVICES`; verl/some stacks reject it when
`CUDA_VISIBLE_DEVICES` is also set.
- Single-node: `export ROCR_VISIBLE_DEVICES=""` before submission.
- Multi-node `srun`: SLURM re-injects it per task, so blank it through the launcher
  (e.g. pass `--override env.ROCR_VISIBLE_DEVICES=` to the app/CLI).

## Debugging a live job

`#SBATCH --output=` / `--error=` are parsed before bash runs, so they **cannot** reference
env vars — they're hardcoded in the sbatches; edit or symlink if you relocate the log dir.

To probe a running job (GPU/CPU/env/log), `ssh` into its node:

```bash
(remote) $ squeue -j <JOBID> -o "%.10i %.20j %.8T %.10M %.6D %R"   # find the node
(remote) $ sacct -j <JOBID> --format=JobID,State,Elapsed,ExitCode  # post-mortem
```

> A benign `FAILED 1:0` is the **expected** final state of the image-build sbatches (the
> trailing `enroot import` cleanup exits non-zero after writing a good `.sqsh`). Verify the
> image by file size, not job state. See [containers.md](containers.md).
