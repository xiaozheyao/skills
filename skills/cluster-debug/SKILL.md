---
name: cluster-debug
description: Probe a live SLURM job (running, hung, or recently completed) for GPU/CPU activity, environment variables, step records, and failure signatures. Use whenever a multi-node training job appears stuck, silent, or just crashed — instead of waiting for walltime + log dumps.
---

# Cluster Job Debugging

When a multi-node SLURM job stalls, crashes, or behaves unexpectedly, inspect the live state — GPU activity, process tree, environment variables, sacct step records, log signatures — to diagnose root cause without waiting for the job to walltime out.

The helper script is at `${CLAUDE_PLUGIN_ROOT}/skills/cluster-debug/examples/probe.sh`.

## When to use

- Job is `RUNNING` in `squeue` but stdout has been silent for minutes.
- Suspect a NCCL/Libfabric hang, OOM, broken transport, or hung collective.
- Want to confirm a fix worked (e.g., env vars actually reached the worker procs).
- Post-mortem on a `FAILED` job to extract the abort signature.
- Verify that secondary `srun` steps inside a multi-node sbatch actually fired.

## How to use

The script takes the cluster name as an **ssh-config alias** (the same name used in the `host = ...` field of `.rcc/config.toml`, so `ssh <name>` and `rcc run --profile <name>` both resolve to the same host).

```
probe.sh CLUSTER JOBID SUBCOMMAND [ARGS]

Subcommands:
  state                squeue + sacct summary
  steps                per-step sacct (find blocked srun steps)
  gpu                  nvidia-smi snapshot on every job node
  procs [PATTERN]      ps on every job node, regex-filtered
  env PATTERN [REGEX]  env of first proc matching PATTERN, regex-filtered
  log [N]              tail last N lines of .out + .err
  abort                grep stdout for SIGABRT / Fatal Python / TerminateHandler
```

Every probe internally attaches via `srun --overlap --gres=none --jobid=$JOBID`. The two flags are **critical**: `--overlap` shares the task slot held by the running job, and `--gres=none` waives the GPU request that would otherwise be inherited from the sbatch header. Skipping either makes the probe srun block at slurm step creation (a real footgun — the probe just hangs silently with no error).

## Recipes

### 1. Job is running but log is silent for minutes

Run `gpu` and `procs` together. Three patterns to recognise:

| Pattern | Reading |
|---|---|
| GPUs idle, no Python procs | Ray bootstrapped but driver crashed. Run `log` and look at the tail. |
| GPUs 100%, proc CPU% **high** (>100%) | Tight spin loop — typically a misconfigured transport or a watchdog about to fire. |
| GPUs 100%, proc CPU% **low** (5-10%) | Kernel wait on IO — usually NCCL doing slow but real work. Be patient. |

The CPU% distinction matters: PyTorch NCCL collectives in a healthy run are mostly kernel-wait (low CPU%); collectives that have hit the watchdog and are unwinding/aborting are CPU-hot. Treat the CPU% delta as a free signal — it tells you whether to wait or kill.

### 2. Multi-node job hangs at the same point every time

Run `env <worker-pattern> '^NCCL_|^FI_'` to confirm the NCCL/Libfabric env vars made it through. Surprises:

- sbatch-level `export FOO=bar` does **not** automatically propagate into Ray workers. The ray-job-submit driver only sees env vars passed via `--runtime-env-json='{"env_vars": {...}}'`. Forgetting to put a NCCL var there is a common cause of "I set it but it didn't help".
- Container hooks (e.g. CSCS's `com.hooks.aws_ofi_nccl`) inject their own env vars at container start. `NCCL_NET_PLUGIN=ofi` showing up unexpectedly is normal for enroot.

### 3. A coordinator `srun` inside an sbatch appears to do nothing

Run `steps`. Look for the expected step record. If a coordinator `srun` (e.g. the polling `ray status` loop, or the final `ray job submit`) has no `sacct` row, it's blocked at slurm step creation. Two causes:

- Missing `--overlap`: the step is queued behind the background `ray start --block` step that already holds the task slot.
- Missing `--gres=none`: the step inherited `gpu:N` from the sbatch header and is waiting for GPUs that the `ray start` steps already hold.

Both flags are usually needed together on any `srun` inside a multi-node sbatch that runs alongside a backgrounded `ray start --block`.

### 4. Job is `FAILED 1:0` and you want the post-mortem

Run `abort`. It greps the stdout for the usual catastrophic signatures:

- `SIGABRT` / `Fatal Python error: Aborted` / `ray::TerminateHandler` → C++ unhandled exception in native code. Often a NCCL/CUDA fault.
- `NCCL.*timeout` → collective watchdog fired. Default PyTorch timeout is 1800 s (30 min). A SIGABRT exactly 30 min after a known collective started is the smoking gun.
- `CUDA error` / `OOM` → driver-side fault.

### 5. Verifying that a fix worked

After patching an sbatch and resubmitting, run `env <worker-pattern>` once the job is past bootstrap to confirm the new env vars reached the workers. Then run `procs` to compare CPU% against the failing baseline (see Recipe #1). A healthy training step typically shows low CPU% in worker procs except during forward/backward compute spikes; an unhealthy spin-loop stays pegged.

## Network/GPU fabric layer — `netdebug`

For deeper fabric and GPU-health diagnostics beyond what `probe.sh` covers, use
`python -m tools.netdebug <sub> CLUSTER JOBID` (see `tools/netdebug/README.md`):

- **`audit`** — lint `NCCL_*`/`FI_*`/`MPICH_*` env per rank against the CSCS CXI baseline;
  flags `CONTRADICTS_BASELINE` / `MISSING` / `INCONSISTENT_ACROSS_RANKS` with error/warn/info severity.
  Exit nonzero if any error findings → usable as a pre-flight check.
- **`transport`** — resolve `libnccl.so.2` and OFI-plugin paths from `/proc/<pid>/maps`; flag ABI skew.
- **`counters [--delta SEC]`** — CXI/HSN link telemetry from `/sys/class/cxi/`; optional rate mode.
- **`hang`** — trigger faulthandler SIGUSR1 per rank, group by collective, flag rank divergence.
  Requires `FLASH_EVOLVE_DEBUG=TRUE` in the job.
- **`mem` / `gpu`** — per-rank GPU memory headroom (OOM risk) and full `nvidia-smi` telemetry.
- **`bench --nodes N`** — submit a self-contained sbatch: `all_reduce_perf` busbw curve + pairwise
  allreduce latency matrix across all ranks.

All attach commands use `srun --overlap --gres=none` (same pattern as `probe.sh`) and are read-only.

## Notes

- The `srun --overlap --gres=none --jobid=$JOBID --ntasks-per-node=1` pattern fans out to every node in the job. For per-pid probes (`env`), expect output from every node and `(no proc matching ...)` on the nodes where the target isn't running.
- If `scontrol show job` no longer returns the job (typical after a few minutes post-completion), `log` and `abort` fall back to needing a manual log path. The `.out` file is preserved on shared storage by the sbatch's `--output=` directive.
- `rcc run --profile X -- 'command'` is functionally equivalent to `ssh X 'command'` for the one-off probes used here, except `rcc run` cd's into the configured `remote_dir` first. The script uses plain `ssh` so probes work even when `remote_dir` is not the job's working directory.
- This skill is cluster-agnostic — works on any SLURM cluster reachable via ssh. The `--gres=none` flag in particular is what makes the probes safe regardless of how the parent sbatch declared GPU requests.
