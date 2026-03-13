# Experiments

This document covers how to design, run, track, and report experiments for systems and ML research.

---

## Experiment design checklist

Before writing a single line of experiment code, answer all of these questions in writing (a scratchpad, a Notion page, anything). If you cannot answer them, the experiment is not ready to run.

1. **What is the hypothesis?**  
   One sentence. "We claim X achieves Y because of Z."  
   If you cannot write this sentence, stop and clarify the claim first.

2. **What is the primary metric?**  
   Pick one. Secondary metrics are fine, but the experiment must be designed to move the primary metric. Typical choices:
   - Throughput (jobs/hour, tokens/s, requests/s)
   - Latency (p50 / p99 / p999 end-to-end)
   - Resource efficiency (GPU utilisation, memory footprint)
   - Accuracy / loss at a fixed compute budget

3. **What are the baselines?** (See section below.)

4. **What workload / dataset will you use?**  
   Prefer publicly available traces or datasets so results are reproducible by others.  
   If using a private trace, describe it enough to characterise it (size, arrival distribution, job mix).

5. **What is the experimental budget?**  
   Estimate wall-clock time and GPU-hours before submitting. Do a 10-minute smoke-test run first.

6. **What do the results have to look like to support the claim?**  
   Write down the threshold before running. This prevents post-hoc rationalisation.

---

## Baseline selection

This is the most-scrutinised part of any paper evaluation. Follow these rules strictly.

### Rules

- **Always include the strongest published baseline**, even if it narrows your margin. Reviewers know the field; omitting an obvious baseline is a major red flag.
- **Always include at least one simple/naive baseline** (FIFO, round-robin, random, static config). It anchors the reader's intuition and shows your system's gains are not trivially achievable.
- **Implement baselines yourself** when the original code is unavailable. Document what you re-implemented and why. Do not estimate baseline performance from numbers in another paper unless you are certain the environment is identical.
- **Run all baselines in the same environment** (same cluster, same hardware generation, same OS/driver stack). Never compare your system on a newer machine against a baseline number from a paper run on older hardware.
- **Do not tune your system while holding baselines fixed.** If you re-tune your system, re-run the baselines.

### Naming baselines in code and figures

| Type | Naming convention | Example |
|------|-------------------|---------|
| Published system | AuthorYY or project name | `Tiresias`, `Gandiva`, `Sia` |
| Re-implemented prior work | `<Name>*` | `FIFO*` (with footnote explaining) |
| Your system | Short, consistent project name | `Ours`, or the actual system name |
| Ablated variant | `<Name>-no-<component>` | `Ours-no-preempt` |

---

## Ablation study structure

Ablations validate that each design decision contributes and that the whole is not accidentally greater than the sum of its parts.

### Standard ablation structure

Start from your full system and remove one component at a time:

```
Full system          <- always first row
  - component A      <- remove A, keep B C D
  - component B      <- remove B, keep A C D
  - component C      <- remove C, keep A B D
Baseline             <- always last row
```

Never start from the baseline and add components up. Starting from the full system is stricter — it proves each component is necessary, not merely helpful.

### What qualifies as a component

- An algorithm choice (e.g., work-stealing vs. centralised queue)
- A policy (e.g., preemption, priority ageing)
- An optimisation (e.g., speculative execution, batching)
- A key parameter made adaptive (e.g., fixed vs. learned batch size)

### Ablation scope

Ablations belong in the main evaluation, not a separate section labelled "Ablation Study". Integrate them into the same figures/tables as the main results where possible.

---

## Reproducibility requirements

A result that cannot be reproduced is noise. Every experiment run must satisfy all of the following before results are recorded.

### Fixed seeds

```python
import random, numpy as np, torch

SEED = 42  # or any fixed value — document it

random.seed(SEED)
np.random.seed(SEED)
torch.manual_seed(SEED)
torch.cuda.manual_seed_all(SEED)
# For full determinism (slower):
torch.backends.cudnn.deterministic = True
torch.backends.cudnn.benchmark = False
```

For distributed runs, also set the seed per-rank: `SEED + rank`.

### Config logging

Every run must log its complete configuration at start-up — not a subset, the full config. Use a structured format so configs are diff-able:

```python
import json, datetime, os, socket

def log_config(config: dict, log_dir: str) -> None:
    meta = {
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "host": socket.gethostname(),
        "git_commit": os.popen("git rev-parse HEAD").read().strip(),
        "config": config,
    }
    os.makedirs(log_dir, exist_ok=True)
    with open(os.path.join(log_dir, "config.json"), "w") as f:
        json.dump(meta, f, indent=2)
```

### Environment capture

Record the software environment alongside results:

```bash
# At the top of your job script, before the main command:
pip freeze > "$LOG_DIR/requirements.txt"
nvidia-smi > "$LOG_DIR/gpu_info.txt"
uname -a   > "$LOG_DIR/system_info.txt"
```

### Multiple seeds / runs

Report results across **at least 3 independent runs** (different seeds, same config) for any metric that has variance. Show mean ± standard deviation or mean with min/max error bars. A single-run result is only acceptable for experiments that are fully deterministic (e.g., exact replay of a fixed trace).

---

## Experiment naming convention

Name every experiment run with enough information to identify it without opening its log files.

### Pattern

```
YYYYMMDD_<system>_<variant>_<notes>
```

### Examples

```
20250310_ours_full_seren-trace
20250310_ours_no-preempt_seren-trace
20250310_fifo-baseline_seren-trace
20250312_ours_full_ali-trace-sweep-bsz
```

Rules:
- Use `snake_case` within each component; separate components with `_`.
- The date prefix is mandatory — it lets you sort runs chronologically.
- `<variant>` must match the ablation or baseline name used in the paper.
- Append a short free-text `<notes>` suffix for anything that does not fit above (e.g., `debug`, `camera-ready`, `rerun-seed5`).

---

## Results directory layout

Keep logs, configs, and outputs co-located. Never scatter results across different directories.

```
results/
  20250310_ours_full_seren-trace/
    config.json          # full config snapshot (auto-generated)
    requirements.txt     # pip freeze (auto-generated)
    gpu_info.txt
    metrics.csv          # one row per time step / epoch
    summary.json         # final scalar metrics (for quick comparison)
    stdout.log
    stderr.log
  20250310_fifo-baseline_seren-trace/
    ...
```

### `summary.json` format

```json
{
  "run_id": "20250310_ours_full_seren-trace",
  "primary_metric": "jct_p99_s",
  "primary_value": 1423.7,
  "secondary": {
    "jct_mean_s": 312.4,
    "gpu_util_pct": 78.2,
    "makespan_s": 9801.0
  },
  "seeds_completed": 3,
  "mean": 1423.7,
  "std": 18.4
}
```

Having a machine-readable `summary.json` lets you collect all results into a comparison table with a one-liner:

```bash
jq -s '[.[] | {run: .run_id, p99: .primary_value, std: .std}]' \
   results/*/summary.json | column -t
```

---

## Experiment tracking tools

Use one of the following. Do not mix two trackers in the same project.

### Weights & Biases (wandb) — recommended for ML training runs

```python
import wandb

wandb.init(
    project="<project-name>",
    name=RUN_ID,          # the naming convention above
    config=vars(args),    # full config dict
    tags=["seren", "full-system"],
)

# Inside training loop:
wandb.log({"loss": loss, "throughput": tput, "step": step})

# At end:
wandb.finish()
```

Key settings to always apply:

```python
# Disable wandb for quick smoke-tests
os.environ["WANDB_MODE"] = "disabled"   # or pass --no-wandb flag

# Save code snapshot (helps with reproducibility)
wandb.init(..., save_code=True)
```

### CSV logging — sufficient for systems experiments

When training-loop semantics do not apply (e.g., trace-driven simulations, scheduler experiments), a simple CSV is cleaner than wandb:

```python
import csv, os

class CSVLogger:
    def __init__(self, path: str, fields: list[str]):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self._f = open(path, "w", newline="")
        self._w = csv.DictWriter(self._f, fieldnames=fields)
        self._w.writeheader()

    def log(self, row: dict) -> None:
        self._w.writerow(row)
        self._f.flush()   # flush after every row so partial runs are readable

    def close(self) -> None:
        self._f.close()
```

---

## When to stop running experiments

Running more experiments is not always better. Stop when:

- The primary metric has converged across 3+ seeds (std < 5 % of mean).
- Every ablation variant has been run with the same number of seeds as the full system.
- You have results on at least two workloads / datasets (one is not enough to claim generality).

Do not run more experiments to make numbers look better. If the results are not convincing, the right response is to revisit the design, not to search for a favourable configuration.

---

## Statistical rigour checklist

Before finalising any table or figure with quantitative results:

- [ ] At least 3 independent seeds / runs for every variant.
- [ ] Mean and variance (std or error bars) reported — never a single run.
- [ ] All variants run on **identical hardware** in the same cluster session where possible.
- [ ] No warm-up effects: discard the first epoch / first N minutes of trace replay.
- [ ] Outlier policy documented: if you drop outliers, state the rule (e.g., "runs where the system crashed are excluded and counted separately").
- [ ] All axes start at zero unless the range is a ratio or percentage where zero is not meaningful.
- [ ] Speedup / improvement claims use the correct denominator (the strongest baseline, not FIFO).