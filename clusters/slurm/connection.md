# SLURM Cluster — Connection

This document describes how to connect to the SLURM cluster(s). Read this before running any jobs.

---

## Prerequisites

- [ ] Your SSH public key has been registered with the cluster admin.
- [ ] You have the required VPN client installed (if the cluster is behind a VPN).
- [ ] You know your cluster username (`<CLUSTER_USER>`).
- [ ] You have the login node hostname (`<LOGIN_NODE_HOST>`).

---

## VPN

> **NOTE:** Skip this section if the cluster is accessible directly from your network.

1. Connect to the VPN before attempting SSH:
   ```
   $ vpn-client connect <VPN_ENDPOINT>
   ```
2. Confirm connectivity:
   ```
   $ ping <LOGIN_NODE_HOST>
   ```

---

## SSH — Basic Connection

```
$ ssh <CLUSTER_USER>@<LOGIN_NODE_HOST>
```

If your SSH key is not in the default location (`~/.ssh/id_rsa` or `~/.ssh/id_ed25519`), specify it explicitly:

```
$ ssh -i <PATH_TO_PRIVATE_KEY> <CLUSTER_USER>@<LOGIN_NODE_HOST>
```

---

## SSH Config (Recommended)

Add an entry to your local `~/.ssh/config` so you can connect with a short alias:

```
# ~/.ssh/config

Host <CLUSTER_ALIAS>
    HostName        <LOGIN_NODE_HOST>
    User            <CLUSTER_USER>
    IdentityFile    ~/.ssh/<KEY_FILENAME>
    ServerAliveInterval 60
    ServerAliveCountMax 3
    # Uncomment the lines below if access requires a jump host:
    # ProxyJump       <JUMP_USER>@<JUMP_HOST>
    # ForwardAgent    yes
```

After saving, connect with:

```
$ ssh <CLUSTER_ALIAS>
```

---

## Jump Host (Bastion)

If the login node is not directly reachable and requires a jump through a bastion host:

```
$ ssh -J <JUMP_USER>@<JUMP_HOST> <CLUSTER_USER>@<LOGIN_NODE_HOST>
```

Or add it to `~/.ssh/config` (see the `ProxyJump` line in the section above).

---

## Verifying the Connection

Once connected, confirm you are on the right system:

```
(remote) $ hostname
(remote) $ whoami
(remote) $ sinfo -s          # should list available SLURM partitions
```

> ⚠️ **You are now on a login node — do not run compute-heavy work here.**
> Login nodes are shared by all connected users and have limited CPU and RAM.
> They are for file management, editing, and job submission only.
> Always use `sbatch` (batch jobs) or `srun --pty bash` (interactive compute session) to run anything CPU/GPU/memory intensive on a proper **compute node**.

---

## Transferring Files

### Small files — `scp`

```
# Local → Remote
$ scp <LOCAL_FILE> <CLUSTER_ALIAS>:<REMOTE_PATH>

# Remote → Local
$ scp <CLUSTER_ALIAS>:<REMOTE_FILE> <LOCAL_PATH>
```

### Large files or directories — `rsync`

```
# Sync a directory to the cluster (dry-run first):
$ rsync -avhn <LOCAL_DIR>/ <CLUSTER_ALIAS>:<REMOTE_DIR>/

# Run for real (remove -n):
$ rsync -avh <LOCAL_DIR>/ <CLUSTER_ALIAS>:<REMOTE_DIR>/
```

### Mounted filesystem (if available)

> **NOTE:** Some clusters expose a shared filesystem that you can mount locally via SSHFS. Check `resources/storage/README.md` for details.

```
$ sshfs <CLUSTER_ALIAS>:<REMOTE_PATH> <LOCAL_MOUNTPOINT>
```

Unmount when done:

```
$ umount <LOCAL_MOUNTPOINT>       # Linux
$ diskutil unmount <LOCAL_MOUNTPOINT>   # macOS
```

---

## Common Connection Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `Connection refused` | VPN not connected, or wrong hostname | Connect to VPN; double-check `<LOGIN_NODE_HOST>` |
| `Permission denied (publickey)` | Wrong key or key not registered | Confirm your public key is on file with admin; specify `-i <KEY>` |
| `Connection timed out` | Firewall or bastion required | Add `ProxyJump` to SSH config |
| SSH disconnects frequently | Idle timeout | Add `ServerAliveInterval 60` to SSH config |
| `Host key verification failed` | Host fingerprint changed | Run `ssh-keygen -R <LOGIN_NODE_HOST>` then reconnect and verify fingerprint with admin |

---

## Cluster Inventory

> Fill in this table as clusters are provisioned. One row per login node / cluster.

| Alias (`<CLUSTER_ALIAS>`) | Login Node (`<LOGIN_NODE_HOST>`) | Location / Notes |
|---------------------------|----------------------------------|------------------|
| _(add entry)_ | | |