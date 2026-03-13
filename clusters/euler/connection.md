# Euler — Connection

This document describes how to connect to the Euler HPC cluster at ETH Zürich.

Official docs: https://docs.hpc.ethz.ch/connections/ssh/

---

## Prerequisites

- [ ] You have a valid ETH Zürich account (or an ETH guest account sponsored by an ETH group).
- [ ] Your account is linked to a valid ETH email address (`<username>@ethz.ch`).
- [ ] For external collaborators: ETH VPN must be explicitly enabled on your guest account.
- [ ] You are connected to the ETH network or to the ETH VPN (see below).

---

## Network Access

> **Euler is only reachable from within the ETH network or via VPN.**
> If you are off-campus, connect to the ETH VPN before attempting SSH.

ETH VPN instructions: https://ethz.ch/services/en/it-services/catalogue/networks-connections/vpn.html

Once on the VPN, proceed with the SSH steps below.

---

## SSH — Basic Connection

```bash
$ ssh <ETH_USERNAME>@euler.ethz.ch
```

The hostname `euler.ethz.ch` is a **load balancer** that distributes sessions across 50 login nodes
(`eu-login-01.euler.ethz.ch` … `eu-login-50.euler.ethz.ch`). Always connect through the load balancer
unless you need to reconnect to a specific node to re-attach a `screen` or `tmux` session.

---

## First Login — Account Activation

On your very first login, Euler will:

1. Prompt you to accept the Acceptable Use Policy (BOT).
2. Send a **one-time verification code** to your ETH email address.
3. Ask you to enter the code in the terminal.

```
Please note that the Euler cluster is subject to the "Acceptable Use Policy
for Telematics Resources" ("Benutzungsordnung fuer Telematik", BOT) of ETH Zürich...

An access code has been sent to your registered email address.
Enter the access code at the prompt below.
Access code (ending on ******qV):
```

Once entered correctly, your account is created automatically.

**Troubleshooting — no verification code prompt:**
Some SSH config settings suppress the prompt. Try:

```bash
$ ssh -o PreferredAuthentications=keyboard-interactive \
      -o PubkeyAuthentication=no \
      <ETH_USERNAME>@euler.ethz.ch
```

Check your spam folder if the code email doesn't arrive within a few minutes.

---

## SSH Keys (Recommended for Repeated Access)

Using SSH keys avoids entering your ETH password every time.

### 1. Generate a key pair (if you don't have one)

```bash
$ ssh-keygen -t ed25519 -C "<your_email@ethz.ch>"
```

Use a strong passphrase — never leave it empty.

### 2. Copy the public key to Euler

```bash
$ ssh-copy-id <ETH_USERNAME>@euler.ethz.ch
```

Or manually append your `~/.ssh/id_ed25519.pub` contents to `~/.ssh/authorized_keys` on Euler.

### 3. Ensure correct permissions on Euler

```bash
(remote) $ chmod 700 ~/.ssh
(remote) $ chmod 600 ~/.ssh/authorized_keys
```

---

## SSH Config (Recommended)

Add an entry to your local `~/.ssh/config` to connect with a short alias:

```
# ~/.ssh/config

Host euler
    HostName        euler.ethz.ch
    User            <ETH_USERNAME>
    IdentityFile    ~/.ssh/id_ed25519
    IdentitiesOnly  yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

After saving, connect with:

```bash
$ ssh euler
```

### Connecting to a specific login node (for tmux/screen reattachment only)

```
Host euler-login-01
    HostName        eu-login-01.euler.ethz.ch
    User            <ETH_USERNAME>
    IdentityFile    ~/.ssh/id_ed25519
    IdentitiesOnly  yes
    ProxyJump       euler
```

> **NOTE:** Only connect to specific login nodes when you need to re-attach an existing
> `screen` or `tmux` session. For all other work, always use the load balancer (`euler.ethz.ch`).

---

## Verifying the Connection

Once connected, confirm the environment:

```bash
(remote) $ hostname                  # should be eu-login-XX.euler.ethz.ch
(remote) $ whoami                    # your ETH username
(remote) $ pwd                       # /cluster/home/<username>
(remote) $ lquota                    # show your storage quotas
(remote) $ sinfo -s                  # show SLURM partition summary
```

> ⚠️ **You are now on a login node — do not run any compute here.**
> Login nodes are shared by all connected users and have limited CPU and RAM. Use them only
> for file management, editing, and job submission. Dispatch all compute work to a compute
> node via `sbatch` (batch jobs) or `srun --pty bash` (interactive sessions).
> See [jobs.md](jobs.md) for how to submit jobs.

---

## Transferring Files

### Small files — `scp`

```bash
# Local → Euler
$ scp <LOCAL_FILE> euler:<REMOTE_PATH>

# Euler → Local
$ scp euler:<REMOTE_FILE> <LOCAL_PATH>
```

### Directories and large transfers — `rsync`

```bash
# Dry run first (shows what would be transferred)
$ rsync -avhn <LOCAL_DIR>/ euler:<REMOTE_DIR>/

# Execute the transfer (remove -n)
$ rsync -avh <LOCAL_DIR>/ euler:<REMOTE_DIR>/
```

### Globus (TB-scale transfers)

For datasets in the terabyte range, use Globus:
https://docs.hpc.ethz.ch/ (search "Globus")

Contact cluster support for guidance on very large transfers.

---

## Internet Access from Compute Nodes

Compute nodes on Euler **do not have direct internet access** by default.
To access the internet from a compute node (e.g., to download packages or containers),
load the proxy module **before** your network call:

```bash
(remote) $ module load eth_proxy
```

Add this to your job script or `.bashrc` if you need internet access regularly.
Example use-case: pulling a container image inside a job.

```bash
module load eth_proxy
apptainer pull docker://pytorch/pytorch:latest
```

---

## Tunneling into a Running Batch Job

To SSH into a compute node that is running one of your jobs, use the Euler tunnel helper:

```bash
(remote) $ euler-tunnel
```

This sets up an SSH tunnel to the allocated compute node for interactive debugging.

---

## Common Connection Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `Connection timed out` | Not on ETH network / VPN | Connect to ETH VPN first |
| `Permission denied (publickey,password)` | Wrong password or too many failed attempts | Check password at https://www.password.ethz.ch/ |
| No verification code prompt on first login | SSH config suppressing interactive auth | Add `-o PreferredAuthentications=keyboard-interactive -o PubkeyAuthentication=no` |
| `Too many authentication failures` | >6 keys offered by SSH agent | Add `IdentitiesOnly yes` to SSH config and specify `IdentityFile` |
| SSH disconnects frequently | Idle timeout | Add `ServerAliveInterval 60` to SSH config |
| `setlocale: LC_CTYPE: cannot change locale` | macOS sending locale env vars | Comment out `SendEnv LANG LC_*` in `/etc/ssh/ssh_config` on your Mac |
| `Host key verification failed` | Login node replaced, host key changed | Run `ssh-keygen -R euler.ethz.ch`, reconnect, verify new key against https://docs.hpc.ethz.ch/connections/host-keys/ |

---

## Host Key Fingerprints

When connecting for the first time, verify the presented host key matches the official fingerprints
published at: https://docs.hpc.ethz.ch/connections/host-keys/

Current fingerprints (ED25519):
```
SHA256: ontwFjITBT9rYE+4QnoN8272Q47W6OGOd5dwFfBivZ0
MD5:    96:0b:48:81:89:18:d1:22:0d:e5:e0:17:7d:d9:02:d2
```

---

## Cluster Summary

| Property | Value |
|----------|-------|
| SSH hostname | `euler.ethz.ch` |
| Login nodes | 50 nodes (load-balanced); Intel Xeon E3, 32 GB RAM each |
| Specific node pattern | `eu-login-<01–50>.euler.ethz.ch` |
| Default shell | `bash` |
| Home directory | `/cluster/home/<username>` |
| Default account | `public` (shared free tier) |
| Full docs | https://docs.hpc.ethz.ch/ |