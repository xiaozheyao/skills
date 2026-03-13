"""
plot_utils.py — Reusable plotting utilities and standard setup.

Import this module at the top of any plotting script:

    from plot_utils import *          # pulls in fig setup + all helpers
    # or selectively:
    from plot_utils import cmp, autolabel, calculate_num_cdf_customized_xaxis
"""

import os
from glob import glob
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

import matplotlib
import matplotlib.patches as mpatches
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
from matplotlib.lines import Line2D
from matplotlib.ticker import FixedLocator

# ---------------------------------------------------------------------------
# Output paths (override in your script after importing if needed)
# ---------------------------------------------------------------------------

SAVEPATH = "./figure"

# ---------------------------------------------------------------------------
# Global matplotlib / seaborn style  (applied on import)
# ---------------------------------------------------------------------------

sns.set_style("ticks")
_font_rc = {
    "font.family": "Roboto",
    "font.size": 12,
}
sns.set_style(_font_rc)

_paper_rc = {
    "lines.linewidth": 3,
    "lines.markersize": 10,
}
sns.set_context("paper", font_scale=2, rc=_paper_rc)

# Shared colour palette — always index into this so colours are consistent
# across all figures in the same paper.
cmp = sns.color_palette("tab10")

# Keep text as actual text (not outlines) in PDF/PS exports so figures
# remain editable in Illustrator / Inkscape.
matplotlib.rcParams["pdf.fonttype"] = 42
matplotlib.rcParams["ps.fonttype"] = 42

# Linestyle cycle — pair with cmp index so colour + style move together.
LINESTYLES: List[str] = ["-", "--", ":", "-.", (0, (3, 1, 1, 1))]

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------


def autolabel(rects, ax, prec: int = 1) -> None:
    """Attach a text label above each bar in *rects*, displaying its height.

    Parameters
    ----------
    rects:
        The ``BarContainer`` returned by ``ax.bar(...)``.
    ax:
        The ``Axes`` the bars belong to.
    prec:
        Number of decimal places shown in the label (default 1).

    Example
    -------
    >>> rects = ax.bar(x, heights)
    >>> autolabel(rects, ax, prec=0)
    """
    for rect in rects:
        height = rect.get_height()
        ax.annotate(
            f"{height:.{prec}f}",
            xy=(rect.get_x() + rect.get_width() / 2, height),
            xytext=(0, 3),  # 3 pt vertical offset above the bar
            textcoords="offset points",
            ha="center",
            va="bottom",
            size=16,
        )


def read_csv_with_concat(
    path: str = "./csv", file_name: Optional[str] = None
) -> pd.DataFrame:
    """Read a CSV file, falling back to monthly shards when the full file is absent.

    Some large trace files are split into monthly shards named
    ``<file_name>-2023-*.csv``.  This function transparently handles both cases.

    Parameters
    ----------
    path:
        Directory that contains the CSV file(s).
    file_name:
        Base name **without** the ``.csv`` extension.

    Returns
    -------
    pd.DataFrame
        The loaded (and possibly concatenated) DataFrame.

    Example
    -------
    >>> df = read_csv_with_concat(path="./csv", file_name="processed_job_trace")
    """
    file = Path(path, f"{file_name}.csv")

    if file.exists():
        print(f"Reading {file_name}")
        return pd.read_csv(file)

    # Fall back to split shards
    split_files = sorted(glob(f"{path}/{file_name}-2023-*.csv"))
    if not split_files:
        raise FileNotFoundError(
            f"Neither '{file}' nor any shard '{path}/{file_name}-2023-*.csv' was found."
        )
    print(f"Reading split files: {split_files}")
    df = pd.concat([pd.read_csv(f) for f in split_files])
    df.reset_index(drop=True, inplace=True)
    return df


def calculate_sum_cdf_axis100(
    df: pd.DataFrame,
    dot_num: int = 1000,
) -> Tuple[np.ndarray, np.ndarray]:
    """Compute a CDF from a wide-format utilisation DataFrame.

    The DataFrame is expected to have a ``Time`` column plus one column per
    server.  All non-NaN values are pooled and quantised into *dot_num* evenly
    spaced percentile points.

    Parameters
    ----------
    df:
        Wide DataFrame with a ``Time`` column and one numeric column per server.
    dot_num:
        Number of quantile points (resolution of the CDF curve).

    Returns
    -------
    x : np.ndarray
        Data values at each percentile.
    y : np.ndarray
        Corresponding percentile values in **percent** (0–100).

    Example
    -------
    >>> x, y = calculate_sum_cdf_axis100(util_df)
    >>> ax.plot(x, y)
    >>> ax.set_ylabel("CDF (%)")
    """
    print("Parsing")
    data = df.melt(id_vars="Time", var_name="Server")
    data.dropna(subset=["value"], inplace=True)

    y = np.linspace(0, 1, num=dot_num)
    x = data["value"].quantile(y).values
    y = y * 100
    return x, y


def calculate_num_cdf_customized_xaxis(
    df: pd.DataFrame,
    x_axis: List[float],
    key: str,
) -> List[float]:
    """Count-based CDF evaluated at caller-supplied x-axis thresholds.

    For each threshold *t* in *x_axis* the function returns the percentage of
    rows where ``df[key] <= t``.  Use this when you want a non-uniform or
    log-spaced x-axis (e.g. powers of two for job duration).

    Parameters
    ----------
    df:
        Source DataFrame.
    x_axis:
        List of threshold values that define the x-axis grid.
    key:
        Name of the column to evaluate.

    Returns
    -------
    List[float]
        Y values in percent (0–100), same length as *x_axis*.

    Example
    -------
    >>> x_axis = [2**i for i in range(0, 22)]
    >>> y = calculate_num_cdf_customized_xaxis(df[df["gpu_num"] > 0], x_axis, "duration")
    >>> ax.plot(x_axis, y)
    >>> ax.set_xscale("log")
    """
    data = df[[key]].copy()
    data.dropna(inplace=True)
    total = len(data)
    return [len(data[data[key] <= x]) / total * 100 for x in x_axis]


def calculate_sum_cdf_customized_xaxis(
    df: pd.DataFrame,
    x_axis: List[float],
    key: str,
    key_to_time: Optional[str] = None,
) -> List[float]:
    """Sum-based (weighted) CDF evaluated at caller-supplied x-axis thresholds.

    For each threshold *t* in *x_axis* the function returns what fraction of
    the *total sum* is contributed by rows where ``df[key] <= t``.

    Pass *key_to_time* to weight each row by ``df[key] * df[key_to_time]``
    before summing — useful for GPU-hour breakdowns where you want to weight
    jobs by ``gpu_num * duration``.

    Parameters
    ----------
    df:
        Source DataFrame.
    x_axis:
        List of threshold values that define the x-axis grid.
    key:
        Column to threshold on.
    key_to_time:
        Optional column to multiply *key* by (weighting).  Pass ``None``
        (default) for an unweighted sum CDF.

    Returns
    -------
    List[float]
        Weighted cumulative percentage (0–100), same length as *x_axis*.

    Example
    -------
    >>> # GPU-hour weighted CDF of job duration
    >>> y = calculate_sum_cdf_customized_xaxis(df, x_axis, "duration", "gpu_num")
    >>> ax.plot(x_axis, y)
    """
    if key_to_time is not None:
        data = df[[key, key_to_time]].copy()
        data["new"] = data[key] * data[key_to_time]
    else:
        data = df[[key]].copy()
        data["new"] = data[key]
    data.dropna(inplace=True)
    total = data["new"].sum()
    return [data[data[key] <= x]["new"].sum() / total * 100 for x in x_axis]


def summarize_traces(trace_dict: Dict[str, pd.DataFrame]) -> pd.DataFrame:
    """Build a per-cluster summary table from a dict of job-trace DataFrames.

    Each DataFrame must contain at least these columns:
    ``gpu_num``, ``duration``, ``queue``, ``state``.

    The resulting summary is also written to ``./csv/cluster_summary.csv``.

    Parameters
    ----------
    trace_dict:
        Mapping of ``cluster_name -> job_trace_dataframe``.
        Use the key ``"PAI"`` for traces that lack a ``state`` column with
        COMPLETED/CANCELLED labels (final-state analysis is skipped for PAI).

    Returns
    -------
    pd.DataFrame
        Summary table indexed by cluster name with columns for job counts,
        average/median/max run times, queue times, GPU counts, and
        completion/cancellation/failure rates.

    Example
    -------
    >>> trace_dict = {"Seren": df_s, "Kalos": df_ali, "Philly": df_philly}
    >>> summary = summarize_traces(trace_dict)
    >>> print(summary[["job_num", "avg_run_time_gpu", "complete_rate_gpu"]])
    """
    df = pd.DataFrame(columns=["id"])
    df.set_index("id", drop=True, inplace=True)

    for cluster, log in trace_dict.items():
        clog = log[log["gpu_num"] == 0]
        glog = log[log["gpu_num"] > 0]

        df.at[cluster, "job_num"] = len(log)
        df.at[cluster, "cpu_job_num"] = len(clog)
        df.at[cluster, "gpu_job_num"] = len(glog)

        df.at[cluster, "avg_run_time_gpu"] = glog["duration"].mean()
        df.at[cluster, "avg_que_time_gpu"] = glog["queue"].mean()
        df.at[cluster, "avg_gpu_num"] = glog["gpu_num"].mean()

        df.at[cluster, "med_run_time_gpu"] = glog["duration"].median()
        df.at[cluster, "med_que_time_gpu"] = glog["queue"].median()
        df.at[cluster, "med_gpu_num"] = glog["gpu_num"].median()

        df.at[cluster, "max_run_time_gpu"] = glog["duration"].max()
        df.at[cluster, "max_gpu"] = glog["gpu_num"].max()

        if cluster != "PAI":
            n_gpu = len(glog)
            df.at[cluster, "complete_rate_gpu"] = (
                len(glog[glog["state"] == "COMPLETED"]) / n_gpu
            )
            df.at[cluster, "cancel_rate_gpu"] = (
                len(glog[glog["state"] == "CANCELLED"]) / n_gpu
            )
            df.at[cluster, "fail_rate_gpu"] = (
                1
                - df.at[cluster, "cancel_rate_gpu"]
                - df.at[cluster, "complete_rate_gpu"]
            )

            glog = glog.copy()
            glog["gpu_time"] = glog["duration"] * glog["gpu_num"]
            gcomplete = glog[glog["state"] == "COMPLETED"]
            gcancel = glog[glog["state"] == "CANCELLED"]
            total_gpu_time = glog["gpu_time"].sum()

            df.at[cluster, "complete_gpu_time"] = gcomplete["gpu_time"].sum()
            df.at[cluster, "cancel_gpu_time"] = gcancel["gpu_time"].sum()
            df.at[cluster, "fail_gpu_time"] = (
                total_gpu_time
                - df.at[cluster, "complete_gpu_time"]
                - df.at[cluster, "cancel_gpu_time"]
            )

            df.at[cluster, "complete_rate_gpu_time"] = (
                gcomplete["gpu_time"].sum() / total_gpu_time
            )
            df.at[cluster, "cancel_rate_gpu_time"] = (
                gcancel["gpu_time"].sum() / total_gpu_time
            )
            df.at[cluster, "fail_rate_gpu_time"] = (
                df.at[cluster, "fail_gpu_time"] / total_gpu_time
            )

        if len(clog) != 0:
            df.at[cluster, "avg_run_time_cpu"] = clog["duration"].mean()
            df.at[cluster, "avg_que_time_cpu"] = clog["queue"].mean()
            df.at[cluster, "med_run_time_cpu"] = clog["duration"].median()
            df.at[cluster, "med_que_time_cpu"] = clog["queue"].median()

            df.at[cluster, "complete_rate_cpu"] = len(
                clog[clog["state"] == "COMPLETED"]
            ) / len(clog)
            df.at[cluster, "cancel_rate_cpu"] = len(
                clog[clog["state"] == "CANCELLED"]
            ) / len(clog)
            df.at[cluster, "fail_rate_cpu"] = (
                1
                - df.at[cluster, "cancel_rate_cpu"]
                - df.at[cluster, "complete_rate_cpu"]
            )

    df = df.round(3)
    df[["job_num", "cpu_job_num", "gpu_job_num"]] = df[
        ["job_num", "cpu_job_num", "gpu_job_num"]
    ].astype(int)

    os.makedirs("./csv", exist_ok=True)
    df.to_csv("./csv/cluster_summary.csv")
    return df


# ---------------------------------------------------------------------------
# Figure-saving convenience wrapper
# ---------------------------------------------------------------------------


def savefig(fig, name: str, savepath: str = SAVEPATH) -> None:
    """Save *fig* as a PDF (and despine first).

    Parameters
    ----------
    fig:
        The ``matplotlib.figure.Figure`` to save.
    name:
        Output filename **without** extension (e.g. ``"cdf_job_duration"``).
    savepath:
        Directory to write into.  Created automatically if absent.

    Example
    -------
    >>> savefig(fig, "cdf_job_duration_util")
    # writes ./figure/cdf_job_duration_util.pdf
    """
    os.makedirs(savepath, exist_ok=True)
    sns.despine()
    fig.savefig(os.path.join(savepath, f"{name}.pdf"), bbox_inches="tight")
    print(f"Saved {os.path.join(savepath, name)}.pdf")
