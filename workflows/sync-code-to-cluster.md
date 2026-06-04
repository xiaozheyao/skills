# Workflow: Sync Code to a Remote Cluster (rcc push)

## Goal
Push your local project's **source code** to a remote cluster's working directory with [`rcc`](https://pypi.org/project/remote-cluster-controller/) (push/pull over SSH+rsync) — safely, without pushing data/secrets, deleting remote state, or disrupting running jobs.

## Prerequisites
- [ ] `rcc` installed and on `PATH` (`which rcc` → e.g. `~/.local/bin/rcc`).
- [ ] `.rcc/config.toml` in the repo root with a profile per cluster (`host`, `remote_dir`). `host` must resolve via `~/.ssh/config` (ProxyJump etc.).
- [ ] SSH works to the target host **today** (CSCS certs expire daily — see Troubleshooting): `ssh -o BatchMode=yes <host> hostname`.
- [ ] `.rcc/rccignore` excludes runtime/data/secrets — at minimum `.local/`, `wandb/`, `outputs/`, `checkpoints/`, `logs/`, `data/`, `runs/`, **`.env`**. Without this, a plain push shoves your local `.local/` (datasets, run state) *up* and can leak `.env`.

> `rcc` direction is **local → cluster** (`push`) / **cluster → local** (`pull`). The cluster copy is a deploy target, not a git repo — treat local as source of truth.

## Steps

### 1. Confirm reachability and profile
```bash
rcc status                                   # is the SSH ControlMaster open?
ssh -o BatchMode=yes -o ConnectTimeout=20 <host> 'echo OK; hostname'
```
Confirm: prints `OK` + the login node. If `Permission denied (publickey)`, renew your cert (Troubleshooting).

### 2. Dry-run the push (ALWAYS do this first)
```bash
rcc push --dry-run --exclude '.local/' --exclude 'wandb/'
```
The `--exclude` flags are belt-and-suspenders even if `.rcc/rccignore` already lists them. `--dry-run` (`-n`) transfers nothing.

### 3. Review the dry-run before committing
In the rsync summary, confirm:
- **`Number of deleted files: 0`** — you did NOT pass `--delete`, so remote-only files (the cluster's `.local/`, checkpoints, staged data) are safe.
- The transferred-files list is **only source** — no `.local/…`, no `.env`, no `wandb/…`, no giant `data/` or vendored-lib blobs.
- A small, sensible count (e.g. "regular files transferred: 79" for a code change), not thousands.

If anything looks wrong (e.g. `.local/` files listed), fix `.rcc/rccignore` / add `--exclude` and re-run the dry-run.

### 4. Push for real (no `--delete` unless you truly mean it)
```bash
rcc push --exclude '.local/' --exclude 'wandb/'
```
Omit `--delete`. With `--delete`, rsync **mirrors** — it removes everything on the cluster not present locally (curriculum data, checkpoints, in-flight run dirs). Only use `--delete` on a throwaway remote dir you intend to mirror exactly.

### 5. Verify on the cluster
Spot-check that the change actually landed:
```bash
ssh <host> 'grep -n "<some-changed-string>" <remote_dir>/path/to/file'
```
If a job is running from `remote_dir`, also confirm it's still alive (`squeue -j <id>`). It uses the code it loaded at process start, so a source push does not disturb a running job — only the *next* submission picks up the new code.

## Expected Outcome
- rsync reports `Number of deleted files: 0` and a small set of source files transferred.
- The cluster's `remote_dir` source matches local; `.local/`, `wandb/`, `.env`, checkpoints, and staged datasets are untouched.
- Already-running jobs continue unaffected; newly-submitted jobs use the synced code.

## Troubleshooting
- **`Permission denied (publickey)` to `ela.cscs.ch`/host:** the daily SSH cert (`~/.ssh/cscs-key-cert.pub`) expired. Renew via MFA (user action), then retry. Not a config bug. Running SLURM jobs are unaffected.
- **Accidentally pushed `.local/` / huge transfer:** you forgot the excludes and `.rcc/rccignore` is missing them. Add `.local/ wandb/ data/ outputs/ checkpoints/ runs/ logs/ .env` to `.rcc/rccignore`. Without `--delete`, the cluster just gained extra files (wasteful, not destructive) — clean them up manually if needed.
- **Pushed a secret (`.env`):** `.rcc/rccignore` did not list `.env`. Add it, then remove the remote copy: `ssh <host> 'rm -f <remote_dir>/.env'`, and rotate the key if it was sensitive.
- **`--delete` wiped remote data:** restore from a backup/restage; never run `--delete` against a `remote_dir` that holds run state or staged datasets. Prefer per-run `.local/` that is always excluded.
- **`rcc sync` not found:** the verbs are `push` / `pull` (not `sync`). See `rcc --help`.
- **Vendored libs re-transfer every time:** if `flash_evolve/libs/` (or similar large vendored trees) keeps transferring, the cluster copy diverged; it's harmless via rsync diff, but you can `--exclude` it when your change doesn't touch it.

> Related: cluster connection skills under `clusters/` (SSH/ProxyJump setup), container/EDF skills for how the *runtime* env differs from the synced repo.
