"""
cdf_plot.py — Worked example: two-panel CDF figure.

Panel (a): Count-based CDF of GPU job duration across multiple clusters.
Panel (b): CDF of GPU utilisation across multiple clusters.

Demonstrates:
  - Importing and using plot_utils helpers
  - Multi-panel figure layout with constrained_layout
  - Log-scale x-axis with manual tick placement
  - Shared legend placed above the figure
  - Saving to PDF via savefig()

Run from the project root (where ./csv/ and ./cluster_util/ live):
    python cdf_plot.py
"""

import pickle

import matplotlib.pyplot as plt
import pandas as pd
from plot_utils import (
    LINESTYLES,
    SAVEPATH,
    calculate_num_cdf_customized_xaxis,
    cmp,
    read_csv_with_concat,
    savefig,
    summarize_traces,
)

# ---------------------------------------------------------------------------
# 1. Paths
# ---------------------------------------------------------------------------

SAVEPKL = "../cluster_util/plot_pkl"
KALOSPKL = "../cluster_util/plot_pkl_ali"
SEREN_PKL = "../cluster_util/plot_pkl_zm/util_gpu_s5.pkl"
PHILLY_PKL = f"{SAVEPKL}/util_gpu_util_philly.pkl"
KALOS_PKL = f"{KALOSPKL}/util_gpu_util_mem_s.pkl"
ANTMAN_PHILLY_CSV = "../cluster_util/util_trace_antman_philly.csv"

# ---------------------------------------------------------------------------
# 2. Load job-trace data
# ---------------------------------------------------------------------------

data_s = read_csv_with_concat(file_name="processed_job_trace")
data_ali = read_csv_with_concat(file_name="processed_ali_trace")
data_philly = pd.read_csv("./csv_previous_work/philly_trace.csv")
data_helios = pd.read_csv("./csv_previous_work/helios_trace.csv")
data_pai = pd.read_csv("./csv_previous_work/pai_trace.csv")

# ---- Normalise column names / values so every trace shares the same schema ----

# PAI: rename columns and scale CPU/GPU counts (raw values are ×100)
data_pai.rename(
    columns={
        "plan_cpu": "cpu_num",
        "plan_gpu": "gpu_num",
        "wait_time": "queue",
        "status": "state",
    },
    inplace=True,
)
data_pai[["cpu_num", "gpu_num"]] /= 100
# NOTE: PAI states cannot be mapped to COMPLETED/CANCELLED — leave as-is.
data_pai["state"] = data_pai["state"].map({"Failed": "FAILED"})

# Philly: map pass/fail/kill to canonical state labels
data_philly["state"] = data_philly["state"].map(
    {"Pass": "COMPLETED", "Failed": "FAILED", "Killed": "CANCELLED"}
)

# ---------------------------------------------------------------------------
# 3. Summarise all traces (also writes ./csv/cluster_summary.csv)
# ---------------------------------------------------------------------------

trace_dict = {
    "Seren": data_s,
    "Kalos": data_ali,
    "Philly": data_philly,
    "Helios": data_helios,
    "PAI": data_pai,
}
summarize_traces(trace_dict)

# ---------------------------------------------------------------------------
# 4. Panel (a): count-based CDF of GPU job duration
# ---------------------------------------------------------------------------

# Log-spaced x-axis: 2^0 … 2^21 seconds
x_duration = [2**i for i in range(0, 22)]

# Filter to GPU-only jobs before computing the CDF
y_s = calculate_num_cdf_customized_xaxis(
    data_s[data_s["gpu_num"] > 0], x_duration, key="duration"
)
y_ali = calculate_num_cdf_customized_xaxis(
    data_ali[data_ali["gpu_num"] > 0], x_duration, key="duration"
)
y_philly = calculate_num_cdf_customized_xaxis(
    data_philly[data_philly["gpu_num"] > 0], x_duration, key="duration"
)
y_helios = calculate_num_cdf_customized_xaxis(
    data_helios[data_helios["gpu_num"] > 0], x_duration, key="duration"
)
y_pai = calculate_num_cdf_customized_xaxis(
    data_pai[data_pai["gpu_num"] > 0], x_duration, key="duration"
)

# ---------------------------------------------------------------------------
# 5. Panel (b): GPU utilisation CDFs from pre-computed pickle files
# ---------------------------------------------------------------------------

# Seren — pickle contains 10 arrays; we only need the first two (x, y)
with open(SEREN_PKL, "rb") as f:
    xx_s, y_util_s, *_ = pickle.load(f)

# Kalos — pickle contains (gpu_x, gpu_y, mem_x, mem_y)
with open(KALOS_PKL, "rb") as f:
    xx_ali, y_util_ali, _mem_x, _mem_y = pickle.load(f)

# Philly
with open(PHILLY_PKL, "rb") as f:
    xx_philly, y_util_philly = pickle.load(f)

# PAI / Antman — read from CSV (pre-computed by an external tool)
df_antman = pd.read_csv(ANTMAN_PHILLY_CSV)
pai_util = df_antman[["ali_gpuutil_x", "ali_gpuutil_y"]].dropna()

# ---------------------------------------------------------------------------
# 6. Draw the figure
# ---------------------------------------------------------------------------

fig, (ax1, ax2) = plt.subplots(
    ncols=2,
    nrows=1,
    constrained_layout=True,
    figsize=(9, 3.75),
)

# --- Panel (a) ---
series_duration = [
    (x_duration, y_s, "Seren"),
    (x_duration, y_ali, "Kalos"),
    (x_duration, y_philly, "Philly"),
    (x_duration, y_helios, "Helios"),
    (x_duration, y_pai, "PAI"),
]
for i, (x, y, label) in enumerate(series_duration):
    ax1.plot(
        x,
        y,
        LINESTYLES[i],
        linewidth=3,
        alpha=0.9,
        color=cmp[i],
        label=label,
    )

ax1.set_xlabel("(a) GPU Job Duration (s)")
ax1.set_ylabel("CDF (%)")
ax1.set_xscale("log")
ax1.set_xticks([1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6])
ax1.set_xlim(x_duration[0], x_duration[-1])
ax1.set_ylim(-0.5, 100.8)
ax1.grid(linestyle=":")

# --- Panel (b) ---
series_util = [
    (xx_s, y_util_s, "Seren"),
    (xx_ali, y_util_ali, "Kalos"),
    (xx_philly, y_util_philly, "Philly"),
    # Helios utilisation data not available — skip
    (pai_util["ali_gpuutil_x"], pai_util["ali_gpuutil_y"], "PAI"),
]
# NOTE: PAI is index 4 in cmp to stay consistent with panel (a) colours.
util_color_idx = [0, 1, 2, 4]
for j, (x, y, label) in enumerate(series_util):
    ax2.plot(
        x,
        y,
        linewidth=3,
        alpha=0.9,
        color=cmp[util_color_idx[j]],
        label=label,
    )

ax2.set_xlabel("(b) GPU Utilization (%)")
ax2.set_ylabel("CDF (%)")
ax2.set_xlim(-0.8, 100.8)
ax2.set_xticks([0, 25, 50, 75, 100])
ax2.set_ylim(0, 100.8)
ax2.grid(linestyle=":")

# ---------------------------------------------------------------------------
# 7. Shared legend above both panels
# ---------------------------------------------------------------------------

# Pull handles/labels from panel (a) which contains all five series.
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

# ---------------------------------------------------------------------------
# 8. Save
# ---------------------------------------------------------------------------

savefig(fig, "cdf_job_duration_util")
