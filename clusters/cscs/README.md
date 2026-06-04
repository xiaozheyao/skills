# CSCS Alps — Clariden / Bristen

CSCS (Swiss National Supercomputing Centre) runs the **Alps** research infrastructure.
This skill covers the two Alps vClusters used here — **Clariden** (GH200) and **Bristen**
(A100) — with a focus on **building and operating container images** (enroot `.sqsh` +
pyxis EDF), the part that differs most from a generic SLURM cluster.

- **Official docs:** https://docs.cscs.ch/
- **NCCL / communication tuning:** https://docs.cscs.ch/software/communication/nccl/
- **Account / SSH key portal:** https://sshservice.cscs.ch/ (MFA — renews the daily SSH cert)

---

## Cluster Facts

| Property | Clariden | Bristen |
|---|---|---|
| Login host | `clariden.cscs.ch` (via `ela.cscs.ch` jump) | `bristen.cscs.ch` (via `ela.cscs.ch` jump) |
| Arch | **aarch64** | **x86_64** |
| GPU | GH200 (Grace-Hopper) | A100 |
| Fabric | Slingshot (CXI / AWS-OFI libfabric) | Ethernet |
| SLURM account flag | **`-A infra02`** | **`-A a-infra02`** |
| Scheduler | SLURM | SLURM |
| Container runtime | **enroot + pyxis** (`.sqsh` + `--environment=<edf>`) | same |
| Image variant needed | `*.aarch64.sqsh` | `*.x86_64.sqsh` |
| Shared storage | `/capstor`, `/iopsstor` (visible from **both** clusters) | same |

> Both clusters share `/capstor` and `/iopsstor`, so the same `.sqsh` images, datasets,
> and checkpoints are visible from either side — only the CPU arch and GPU/fabric differ.
> You still need a **separate image per arch**.

---

## ⚠️ Login Nodes Are Not for Computation

> **Never run compute-heavy work on a login node. Always use a compute node.**

Landing host after SSH is a shared login node (e.g. `clariden-ln003`). Use it only for
file management, `rcc`/`git`, and `sbatch`/`srun` submission. Run image builds, training,
data processing, and anything multi-second on a compute node via `sbatch` or
`srun --pty bash`. See [jobs.md](jobs.md).

---

## Contents

| File | What it covers |
|------|----------------|
| [connection.md](connection.md) | SSH (`ela.cscs.ch` jump), the **daily SSH-cert expiry**, code sync with `rcc` |
| [containers.md](containers.md) | **enroot/pyxis image model — full build AND cheap pip-overlay build on top of an existing `.sqsh`** |
| [jobs.md](jobs.md) | SLURM accounts, partitions, reservations, multi-node `srun` gotchas, NCCL env |
| [examples/](examples/) | Ready-to-use sbatch templates (enroot pip-overlay build) |

---

## Quick Reference

```bash
# Connect (SSH config aliases already proxy through ela.cscs.ch)
$ ssh clariden            # or: ssh bristen
# "Permission denied (publickey)" => your 24h SSH cert expired; renew via MFA (see connection.md)

# Sync code (NOT git push — see connection.md)
$ rcc push                          # rsync working tree to the default profile (clariden)
$ rcc --profile bristen push
$ rcc run "<cmd>"                   # run in the remote repo dir (does not word-split; prefer ssh for compound cmds)

# Submit a job (account flag is mandatory — default account is unset)
(remote) $ sbatch -A infra02   meta/cscs/build/clariden.sbatch     # clariden
(remote) $ sbatch -A a-infra02 meta/cscs/build/bristen.sbatch      # bristen

# Run inside the image on a compute node
(remote) $ srun -A infra02 --environment=flash-evolve-verl --pty bash
```

---

## Critical CSCS-Specific Rules

> Read these before submitting any job. Several differ sharply from generic SLURM / Euler.

### 1. SLURM account is mandatory and per-cluster

The default account is **unset** (jobs rejected without `-A`). Use:
- **Clariden:** `-A infra02`
- **Bristen:** `-A a-infra02` (NOT `infra02`)
- **Reservations** (e.g. the Apertus reservation): `-A infra01` (NOT `infra02`) — allocates instantly.

### 2. The SSH certificate expires every 24 hours

`ela.cscs.ch: Permission denied (publickey)` is almost always an **expired cert**
(`~/.ssh/cscs-key-cert.pub`), not a broken config. Renew it via MFA at the CSCS key
portal. **Running SLURM jobs are unaffected** by an expired cert. See [connection.md](connection.md).

### 3. Sync code with `rcc`, not `git push`

Code reaches the cluster via [`rcc`](https://pypi.org/project/remote-cluster-controller/)
(`rcc push`). Profiles + the remote repo dir live in `.rcc/config.toml`; `.rcc/rccignore`
excludes runtime dirs (`.local/ wandb/ outputs/ checkpoints/ data/ .env`) so a plain
`rcc push` is code-only and never leaks secrets or deletes cluster run state.

### 4. Containers are enroot + pyxis, NOT Apptainer

Images are squashfs `.sqsh` files referenced by an **EDF** TOML profile in `~/.edf/`,
selected per job with `srun --environment=<name>`. There is **no `apptainer`/`.sif`**
flow here. See [containers.md](containers.md) — this is the main skill.

### 5. Compute nodes are diskless — `/dev/shm` is the only node-local store

GH200 nodes have no local disk. The only node-local storage is RAM-backed tmpfs at
`/dev/shm`. Image builds (podman store, enroot rootfs) **must** live on `/dev/shm`, never
Lustre. See [containers.md](containers.md) for the exact env setup.

### 6. Multi-node `srun` inside an sbatch needs `--overlap` AND `--gres=none`

Without both, secondary `srun` steps block forever at SLURM step creation (the parent
`ray start --block` srun holds the task slot and the gres). See [jobs.md](jobs.md).

### 7. Multi-node Clariden needs CSCS NCCL/Libfabric env

GH200 + Slingshot multi-node jobs require `NCCL_NET="AWS Libfabric"`, `NCCL_CROSS_NIC=1`,
and `FI_CXI_*` rendezvous tuning, plus the `com.hooks.aws_ofi_nccl` EDF annotation.
Bristen (A100/Ethernet) does not. See [jobs.md](jobs.md).

### 8. EDF `[env]` beats sbatch runtime env

Variables set in the EDF `[env]` block (e.g. `PYTHONPATH`, `HF_HOME`, `workdir`) **override**
what the sbatch/runtime sets. On wrong-import / wrong-path bugs, check `~/.edf/<name>.toml`
first. See [containers.md](containers.md).

---

## Hardware at a Glance

| Cluster | Node | GPU | GPUs/node | Fabric |
|---|---|---|---|---|
| Clariden | GH200 (Grace-Hopper) | H100-class | 4 | Slingshot (CXI) |
| Bristen | x86_64 | A100 | 4–8 | Ethernet |

## Storage

| Path | Scope | Notes |
|---|---|---|
| `/capstor/store/cscs/swissai/<project>/<user>/` | Project store | Persistent; shared across Clariden + Bristen; holds images, datasets, checkpoints |
| `/iopsstor` | High-IOPS scratch | Shared across both clusters |
| `/users/<user>` | Home | Small quota; EDFs read from `~/.edf/` here |
| `/dev/shm` | Node-local | RAM-backed tmpfs; **only** node-local store on diskless nodes; gone at job end |
