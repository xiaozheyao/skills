# Skills Repository

A structured knowledge base for autonomous infrastructure access and task execution.
Each skill is a markdown document (or a directory of documents) that describes **how to connect to, query, or operate a specific piece of infrastructure** — written so that both humans and AI agents (e.g. Claude Code) can follow them reliably.

---

## Repository Structure

```
skills/
├── CLAUDE.md              # Entry point and navigation guide for Claude Code
├── README.md              # This file
│
├── clusters/              # Compute cluster skills (HPC, cloud VMs, etc.)
│   ├── README.md
│   └── slurm/             # SLURM-based HPC clusters
│       ├── README.md
│       ├── connection.md
│       ├── jobs.md
│       ├── resources.md
│       └── examples/
│
├── resources/             # Shared infrastructure resources
│   ├── README.md
│   ├── storage/           # Filesystems and object storage
│   ├── databases/         # Databases and query patterns
│   └── services/          # Internal APIs and microservices
│
└── workflows/             # Multi-step, end-to-end task guides
    └── README.md
```

---

## Categories

### Clusters
Skills for connecting to and operating compute clusters. Covers authentication,
job submission, resource monitoring, and environment setup for each cluster.

Currently documented:
- **SLURM** — `clusters/slurm/`

### Resources
Skills for accessing shared infrastructure that may be used across multiple clusters
or independently. Covers storage mounts, database connections, and internal services.

Currently documented:
- **Storage** — `resources/storage/`
- **Databases** — `resources/databases/`
- **Services** — `resources/services/`

### Workflows
Higher-level guides that combine multiple clusters and resources to accomplish a
complete task (e.g. launching a training run, processing a large dataset, deploying
a model). These are the best starting point when the goal is task-level rather than
resource-level.

Currently documented: *(none yet — add yours here)*

---

## Publishing to GitHub

To publish your skills repo so you can install it on any machine:

```bash
# 1. Initialise git (from the skills/ directory)
git init
git add .
git commit -m "Initial commit"

# 2. Create a repo on GitHub (using the GitHub CLI, or do it in the browser)
gh repo create skills --private --source=. --push
# Or: git remote add origin https://github.com/<YOU>/skills.git && git push -u origin main
```

After that, every time you add or update a skill:

```bash
git add .
git commit -m "Update Euler jobs doc"
git push
```

---

## Installation

### Option A — Via `/plugin` (recommended, native Claude Code plugin system)

This repo is a self-contained Claude Code plugin **and** marketplace. Once pushed
to GitHub, you can install it directly inside any Claude Code session with two
commands — no cloning required.

**1. Add the marketplace** (registers the catalog; does not install anything yet):

```
/plugin marketplace add xiaozheyao/skills
```

**2. Install the plugin** (downloads and wires up the skills):

```
/plugin install infrastructure-skills@my-skills
```

That's it. The `/euler` and `/slurm` slash commands are now available in every
Claude Code session on this machine (user scope, the default).

**Keeping it up to date** — Claude Code can auto-update the plugin when you push
changes. Toggle it in `/plugin` → **Marketplaces** → select your marketplace →
**Enable auto-update**. Or update manually at any time:

```
/plugin marketplace update my-skills
```

**Scopes** — Install to a specific scope with the `--scope` flag:

```
# Available in every project on this machine (default)
/plugin install infrastructure-skills@my-skills --scope user

# Shared with everyone who clones this project (committed to .claude/settings.json)
/plugin install infrastructure-skills@my-skills --scope project

# Only on your machine in this project (gitignored)
/plugin install infrastructure-skills@my-skills --scope local
```

**Uninstall:**

```
/plugin uninstall infrastructure-skills@my-skills
```

---

### Option B — `install.sh` fallback (for use without the plugin system)

Use this if you prefer to manage the repo manually (e.g. as a git submodule), or
if you are on an older version of Claude Code that does not support `/plugin`.

**Global install** — available in every Claude Code session on this machine:

```bash
# Clone once to a stable location (e.g. ~/skills)
git clone https://github.com/<YOU>/skills.git ~/skills

# Wire it into Claude Code's global memory + install slash-command wrappers
~/skills/install.sh
```

Re-run `install.sh` only when you add new skills. Edits to existing skill docs
take effect immediately — no re-install needed.

**Per-project install** — scoped to one repository only:

```bash
# Inside your project root:
git submodule add https://github.com/<YOU>/skills.git .skills
git commit -m "Add skills submodule"

# Wire it into this project's CLAUDE.md only (does not touch ~/.claude/)
.skills/install.sh --project .
```

To pull the latest skills into the submodule later:

```bash
git submodule update --remote .skills
git commit -m "Update skills submodule"
```

To uninstall, remove the `=== Infrastructure Skills Repository ===` block from
the relevant `CLAUDE.md` (global `~/.claude/CLAUDE.md` or project-level).

---

## Contributing

1. **New cluster** → create `clusters/<cluster-name>/` with a `README.md` and at least a `connection.md`.
2. **New resource** → create `resources/<category>/<resource-name>.md` or a subdirectory if it needs multiple files.
3. **New workflow** → add a markdown file under `workflows/` and link it from `workflows/README.md`.
4. **Keep placeholders explicit** — use `<ANGLE_BRACKETS>` for any value that varies per user or environment.
5. **Update parent `README.md` files** whenever you add new entries so the index stays accurate.

---

## Conventions

| Convention | Meaning |
|---|---|
| `<PLACEHOLDER>` | Replace with a real value before running |
| `$ command` | Run on your local machine |
| `(remote) $ command` | Run on a remote host after connecting |
| `# NOTE:` comments | Important caveats — read before executing |
| `UPPER_SNAKE_CASE` vars | Shell / environment variables to set beforehand |
