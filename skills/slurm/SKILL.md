---
name: slurm
description: Documentation and job templates for generic SLURM HPC clusters. Use when the user needs to submit batch jobs, monitor jobs, use job arrays, request GPUs, or understand SLURM partitions, QoS, and resource flags. For the Euler cluster specifically, use the `euler` skill instead.
---

The SLURM cluster documentation lives at `${CLAUDE_PLUGIN_ROOT}/clusters/slurm/`.

When helping with SLURM tasks, read the relevant skill files first before writing any commands or scripts.

## Skill files

**Before connecting to the cluster:**
Read `${CLAUDE_PLUGIN_ROOT}/clusters/slurm/connection.md`
- SSH config, VPN requirements, jump hosts, file transfer

**Before submitting or managing jobs:**
Read `${CLAUDE_PLUGIN_ROOT}/clusters/slurm/jobs.md`
- sbatch, srun, squeue, scancel, job arrays, interactive sessions, exit codes

**Before selecting resources (partition, GPU, memory):**
Read `${CLAUDE_PLUGIN_ROOT}/clusters/slurm/resources.md`
- Available partitions, GPU types and SLURM identifiers, QoS policies, accounts

**For ready-to-use job script templates:**
Read `${CLAUDE_PLUGIN_ROOT}/clusters/slurm/examples/gpu-job.sh`
Read `${CLAUDE_PLUGIN_ROOT}/clusters/slurm/examples/array-job.sh`

## Key rules for any SLURM cluster

- **Never run compute-heavy work on login nodes.** After SSH-ing in you are on a login
  node. Use `sbatch` for batch jobs or `srun --pty bash` for interactive compute sessions.
  See `${CLAUDE_PLUGIN_ROOT}/clusters/slurm/jobs.md` for details.
- Always use `module purge` at the top of job scripts before loading modules — jobs inherit the submitting shell's environment.
- Replace all `<PLACEHOLDER>` values before submitting any script.
- Create the `logs/` directory before submitting if the script uses `--output=logs/...`.
- Prefer `--mem-per-cpu` over `--mem` for portability across nodes.
- Use `sacct -j <JOBID>` to diagnose finished or failed jobs.