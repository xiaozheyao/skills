# CSCS Alps — Connection & Code Sync

## SSH

Access to Clariden/Bristen is through the CSCS front-end **`ela.cscs.ch`** (a jump host).
The SSH config aliases already encode the `ProxyJump`:

```
Host ela ela.cscs.ch
    Hostname ela.cscs.ch
    User <user>
    IdentityFile ~/.ssh/cscs-key

Host clariden clariden.cscs.ch
    Hostname clariden.cscs.ch
    User <user>
    IdentityFile ~/.ssh/cscs-key
    ProxyJump ela

Host bristen bristen.cscs.ch
    Hostname bristen.cscs.ch
    User <user>
    IdentityFile ~/.ssh/cscs-key
    ProxyJump ela
```

So a plain alias just works:

```bash
$ ssh clariden        # lands on a login node, e.g. clariden-ln003
$ ssh bristen
```

## ⚠️ The SSH certificate expires every 24 hours

CSCS issues a **short-lived (24 h) SSH certificate**, `~/.ssh/cscs-key-cert.pub`, alongside
the long-lived key `~/.ssh/cscs-key`. When it expires you get:

```
ela.cscs.ch: Permission denied (publickey)
```

**This is an expired cert, not a broken config or a bug.** Renew it via **MFA** at the CSCS
key/SSH service (https://sshservice.cscs.ch/ — signs a fresh `cscs-key-cert.pub`). The user
performs the MFA step; you cannot.

- Check the cert's validity: `ssh-keygen -L -f ~/.ssh/cscs-key-cert.pub` (look at `Valid:`).
- **Running SLURM jobs are unaffected** by an expired cert — only new SSH/`rcc`/`scp`
  sessions fail. Don't restart jobs over this.

## Code sync — `rcc`, not `git push`

Code reaches the cluster with [`rcc`](https://pypi.org/project/remote-cluster-controller/)
(remote-cluster-controller), an rsync+SSH wrapper. Profiles live in `.rcc/config.toml` in
the repo, each naming a `host` and a `remote_dir`:

```toml
default = "clariden"
[profiles.clariden]
host = "clariden"
remote_dir = "/capstor/store/cscs/swissai/infra02/xyao/code/flash-evolve"
[profiles.bristen]
host = "bristen"
remote_dir = "/capstor/store/cscs/swissai/infra02/xyao/code/flash-evolve"
```

```bash
$ rcc push                       # rsync working tree -> default profile (clariden)
$ rcc --profile bristen push     # -> bristen
$ rcc pull                       # pull remote files back
$ rcc shell                      # interactive shell in remote_dir
$ rcc status                     # is the SSH ControlMaster open?
```

- `.rcc/rccignore` excludes runtime dirs (`.local/ wandb/ outputs/ checkpoints/ data/`)
  and `.env`, so a plain `rcc push` is **code-only** — it never uploads large artifacts,
  leaks secrets, or deletes cluster run state.
- **`rcc run "<cmd>"` does not word-split** the command through a shell — a compound
  command like `sbatch -A infra02 path.sbatch` fails as `No such file or directory`. For
  compound/argument-bearing commands, use direct SSH instead:
  ```bash
  $ ssh clariden 'cd <remote_dir> && sbatch -A infra02 meta/cscs/build/clariden.sbatch'
  ```

## WANDB credentials

WANDB keys are read from `~/.netrc` at runtime; the sbatches extract them. Never hard-code
keys. A stale local `~/.netrc` key is a common cause of auth failures — refresh it if
runs can't log to WANDB.
