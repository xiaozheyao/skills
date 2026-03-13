# Workflows

This directory contains end-to-end, multi-step task guides. Each workflow document describes a higher-level goal that typically involves **multiple clusters and/or resources working together**.

Start here when you have a task like:
- "Run a training experiment on the SLURM cluster and save results to object storage"
- "Process a dataset from the database and write outputs to shared filesystem"
- "Deploy a new model version to a serving service"

---

## When to Use a Workflow vs. a Skill

| Use a **skill** when… | Use a **workflow** when… |
|---|---|
| You need to do one specific thing (submit a job, query a DB) | You need to orchestrate multiple steps across systems |
| The task is self-contained within a single cluster or resource | The task involves handoffs between clusters and resources |
| You are troubleshooting a single component | You are executing a full end-to-end pipeline |

---

## Available Workflows

> Add a row here each time you create a new workflow document.

| File | Goal | Clusters / Resources Involved |
|------|------|-------------------------------|
| _(none yet)_ | | |

---

## Workflow Document Template

When creating a new workflow, use this structure:

```
# Workflow: <Short Title>

## Goal
One-sentence description of what this workflow accomplishes.

## Prerequisites
- [ ] Access to <cluster/resource>
- [ ] Environment variable `FOO` set to ...
- [ ] ...

## Steps

### 1. <Step Name>
What this step does and why.
Commands / instructions.

### 2. <Step Name>
...

## Expected Outcome
What success looks like — output files, logs, return codes, etc.

## Troubleshooting
Common failure modes and how to recover.
```

---

## Conventions

- Each step should be independently verifiable — include a "how to confirm this step succeeded" note where useful.
- If a step requires a skill from `clusters/` or `resources/`, link to the relevant document rather than duplicating instructions.
- Keep workflows focused on **one goal per file**. If a workflow becomes too long, break it into sub-workflows and link them together.