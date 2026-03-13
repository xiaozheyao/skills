---
name: plotting
description: Conventions, helper functions, and patterns for creating publication-quality matplotlib/seaborn figures. Use whenever the user asks to plot, visualize data, create figures, draw CDFs, bar charts, or save plots to PDF.
---

# Plotting Skill

This skill documents the standard setup, reusable utilities, and figure patterns used across this codebase. Always use these conventions when creating or editing any plot.

Reusable code lives at: `${CLAUDE_PLUGIN_ROOT}/skills/plotting/examples/plot_utils.py`
A worked CDF example lives at: `${CLAUDE_PLUGIN_ROOT}/skills/plotting/examples/cdf_plot.py`

---

## Critical rules (read before writing any plot code)

1. **Always import from `plot_utils.py`** when the helper functions are available in the project. Do not rewrite them inline.
2. **Always set `pdf.fonttype = 42` and `ps.fonttype = 42`** so text remains editable in Illustrator/Inkscape.
3. **Always save with `bbox_inches="tight"`** to prevent legend or label clipping.
4. **Use `sns.despine()`** at the end of every figure to remove the top and right spines.
5. **Never hardcode a colour** — index into `cmp = sns.color_palette("tab10")` so colours are consistent across all figures.
6. **Default save format is PDF** at `./figure/`. Create the directory if it does not exist.
7. **Use `constrained_layout=True`** (not `tight_layout()`) when creating multi-panel figures with `plt.subplots`.

---

## Standard setup boilerplate

Every plotting script starts with this exact block:

```python
import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.lines import Line2D
from matplotlib.ticker import FixedLocator

SAVEPATH = "./figure"

sns.set_style("ticks")
font = {
    "font.family": "Roboto",
    "font.size": 12,
}
sns.set_style(font)
paper_rc = {
    "lines.linewidth": 3,
    "lines.markersize": 10,
}
sns.set_context("paper", font_scale=2, rc=paper_rc)
cmp = sns.color_palette("tab10")

matplotlib.rcParams["pdf.fonttype"] = 42
matplotlib.rcParams["ps.fonttype"] = 42
```

Key choices:
- **Font**: Roboto, base size 12, scaled ×2 via `font_scale=2` → effective body size ~24 pt for papers.
- **Color palette**: `tab10`, accessed as `cmp[0]`, `cmp[1]`, … Keep series ordering consistent across all figures in the same paper.
- **Line defaults**: linewidth 3, markersize 10 (overridden per-plot when needed).

---

## Helper functions

All helpers below are defined in `plot_utils.py`. Their signatures and intended use are described here.

### `autolabel(rects, ax, prec=1)`

Annotates each bar in a bar chart with its height value, centred above the bar.

| Argument | Type | Description |
|---|---|---|
| `rects` | `BarContainer` | Return value of `ax.bar(...)` |
| `ax` | `Axes` | The axes the bars belong to |
| `prec` | `int` | Decimal places shown in the label (default 1) |

Usage:
```python
rects = ax.bar(x, heights)
autolabel(rects, ax, prec=0)
```

---

### `read_csv_with_concat(path="./csv", file_name=None)`

Reads a CSV that may have been split into monthly shards named `<file_name>-2023-*.csv`.
Falls back to the shards automatically when the monolithic file does not exist.

| Argument | Default | Description |
|---|---|---|
| `path` | `"./csv"` | Directory containing the CSV files |
| `file_name` | `None` | Base name without `.csv` extension |

Returns: `pd.DataFrame`

Usage:
```python
df = read_csv_with_concat(path="./csv", file_name="processed_job_trace")
```

---

### `calculate_sum_cdf_axis100(df, dot_num=1000)`

Melts a wide-format utilisation DataFrame (columns: `Time`, then one column per server) and returns `(x, y)` coordinates for a CDF where the y-axis runs 0–100 %.

| Argument | Default | Description |
|---|---|---|
| `df` | — | Wide DataFrame with a `Time` column |
| `dot_num` | `1000` | Number of quantile points |

Returns: `(x: np.ndarray, y: np.ndarray)` — ready to pass directly to `ax.plot`.

---

### `calculate_num_cdf_customized_xaxis(df, x_axis, key)`

**Count-based CDF** with a caller-supplied x-axis grid.  
For each threshold in `x_axis`, computes the fraction of rows where `df[key] <= threshold`.

| Argument | Type | Description |
|---|---|---|
| `df` | `pd.DataFrame` | Source data |
| `x_axis` | `List[float]` | Threshold values (e.g. `[2**i for i in range(22)]`) |
| `key` | `str` | Column name to evaluate |

Returns: `List[float]` — y values in percent (0–100), same length as `x_axis`.

Typical use — job duration CDF on a log x-axis:
```python
x_axis = [2**i for i in range(0, 22)]
y = calculate_num_cdf_customized_xaxis(df[df["gpu_num"] > 0], x_axis, key="duration")
ax.plot(x_axis, y)
ax.set_xscale("log")
```

---

### `calculate_sum_cdf_customized_xaxis(df, x_axis, key, key_to_time=None)`

**Sum-based (weighted) CDF** with a caller-supplied x-axis grid.  
For each threshold, computes the fraction of the *total sum* contributed by rows where `df[key] <= threshold`.
Pass `key_to_time` to weight each row by `df[key] * df[key_to_time]` before summing (e.g. GPU-hours = GPUs × duration).

| Argument | Type | Description |
|---|---|---|
| `df` | `pd.DataFrame` | Source data |
| `x_axis` | `List[float]` | Threshold values |
| `key` | `str` | Column to threshold on |
| `key_to_time` | `str \| None` | Optional column to multiply `key` by (weighting) |

Returns: `List[float]` — weighted cumulative percentage, same length as `x_axis`.

---

## Common figure patterns

### Two-panel figure (side by side)

```python
fig, (ax1, ax2) = plt.subplots(
    ncols=2, nrows=1,
    constrained_layout=True,
    figsize=(9, 3.75),
)
```

- `figsize=(9, 3.75)` fits a two-column IEEE/USENIX paper at ~90 mm per column.
- Label sub-panels inline on the x-axis label: `ax1.set_xlabel("(a) GPU Job Duration (s)")`.

### Legend above the figure (shared across panels)

```python
handles, labels = ax1.get_legend_handles_labels()
fig.legend(
    handles=handles,
    labels=labels,
    ncols=5,
    bbox_to_anchor=(0.1, 1.145),
    loc=2,
    columnspacing=1.5,
    handletextpad=0.5,
)
```

Do **not** call `ax.legend()` — use `fig.legend()` so the legend is shared and placed above the figure bounds.

### CDF line plot (log x-axis)

```python
linestyles = ["-", "--", ":", "-.", (0, (3, 1, 1, 1))]

ax.plot(x_axis, y_values, linestyles[i], linewidth=3, alpha=0.9, color=cmp[i], label="<Series>")
ax.set_xscale("log")
ax.set_xticks([1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6])
ax.set_xlim(x_axis[0], x_axis[-1])
ax.set_ylim(-0.5, 100.8)
ax.set_xlabel("(a) <X label>")
ax.set_ylabel("CDF (%)")
ax.grid(linestyle=":")
```

### CDF line plot (linear x-axis, 0–100 %)

```python
ax.plot(x_values, y_values, linestyles[i], linewidth=3, alpha=0.9, color=cmp[i], label="<Series>")
ax.set_xlim(-0.8, 100.8)
ax.set_xticks([0, 25, 50, 75, 100])
ax.set_ylim(0, 100.8)
ax.set_xlabel("(b) <X label> (%)")
ax.set_ylabel("CDF (%)")
ax.grid(linestyle=":")
```

### Bar chart with value labels

```python
rects = ax.bar(x_positions, heights, color=cmp[0], label="<Series>")
autolabel(rects, ax, prec=1)
```

---

## Saving figures

```python
import os
os.makedirs(SAVEPATH, exist_ok=True)
fig.savefig(f"{SAVEPATH}/<figure_name>.pdf", bbox_inches="tight")
```

- Always use **PDF** for final figures (vector, editable fonts).
- `bbox_inches="tight"` is mandatory — legends placed outside the axes bounds will be clipped otherwise.
- Use `sns.despine()` immediately before `fig.savefig(...)`.

---

## Standard linestyle cycle

```python
linestyles = ["-", "--", ":", ":", ":"]
```

Use the same index as the `cmp` colour index so style and colour move together. When more than 3 series share a panel, differentiate primarily by colour; linestyle is a secondary cue for black-and-white printing.

---

## Dependencies

```
matplotlib
seaborn
numpy
pandas
squarify   # for treemap plots (imported but only used in treemap figures)
```

Install with:
```
pip install matplotlib seaborn numpy pandas squarify
```
The font **Roboto** must be installed at the OS level (or in matplotlib's font cache). On macOS: `brew install --cask font-roboto`. On Linux: install the `fonts-roboto` package, then clear the matplotlib font cache with `rm -rf ~/.cache/matplotlib`.