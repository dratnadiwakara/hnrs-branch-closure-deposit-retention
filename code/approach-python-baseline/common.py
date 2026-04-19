import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

# ---------------------------------------------------------------------------
# Raw data paths
# ---------------------------------------------------------------------------
EXTERNAL = "C:/Users/dimut/OneDrive/data"

CLOSURE_PANEL   = f"{EXTERNAL}/closure_opening_data_simple.rds"
FDIC_SOD        = f"{EXTERNAL}/fdic_sod_2000_2025_simple.rds"
COUNTY_CONTROLS = f"{EXTERNAL}/nrs_branch_closure/county_controls_panel.rds"
HMDA_DB         = "C:/empirical-data-construction/hmda/hmda.duckdb"
CRA_DB          = "C:/empirical-data-construction/cra/cra.duckdb"

# Relative to project root (run scripts from project root)
MOBILE_SUB = "data/raw/perc_hh_wMobileSub.csv"

# Constructed data and output live inside this approach folder
APPROACH_DIR = "code/approach-python-baseline"
DATA_DIR     = f"{APPROACH_DIR}/data"
OUTPUT_DIR   = f"{APPROACH_DIR}/output"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
TOP4_CERT   = {628, 3510, 3511, 7213}
START_YEAR  = 2001
END_YEAR    = 2025

# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

def load_rds(path):
    import pyreadr
    result = pyreadr.read_r(path)
    return list(result.values())[0]


def winsorize(s, low=0.025, high=0.975):
    lo = s.quantile(low)
    hi = s.quantile(high)
    return s.clip(lo, hi)


def stars(p):
    if p < 0.01:  return "***"
    if p < 0.05:  return "**"
    if p < 0.10:  return "*"
    return ""


def make_reg_table(models, col_labels, row_labels, title, out_path,
                   coef_names=None):
    """
    Render a regression coefficient table as a PNG and save it.

    models      : list of pyfixest model objects
    col_labels  : list of column header strings (one per model)
    row_labels  : list of variable display names (one per coef_names entry)
    coef_names  : list of coefficient names to extract (must match pyfixest names)
    title       : figure title string
    out_path    : full path to save PNG
    """
    if coef_names is None:
        coef_names = row_labels

    rows = []
    for name, label in zip(coef_names, row_labels):
        coef_row = [label]
        se_row   = [""]
        for m in models:
            try:
                coef = m.coef().loc[name]
                se   = m.se().loc[name]
                pval = m.pvalue().loc[name]
                coef_row.append(f"{coef:.4f}{stars(pval)}")
                se_row.append(f"({se:.4f})")
            except KeyError:
                coef_row.append("")
                se_row.append("")
        rows.append(coef_row)
        rows.append(se_row)

    # footer: N and FE
    n_row = ["N"]
    for m in models:
        try:    n_row.append(f"{int(m._N):,}")
        except: n_row.append("")
    rows.append(n_row)

    fe_row = ["FE"]
    for m in models:
        fe_row.append("branch + state×yr + bank×yr")
    rows.append(fe_row)

    ncols = len(models) + 1
    nrows = len(rows)

    fig_h = max(3, nrows * 0.45 + 1.5)
    fig_w = max(8, ncols * 2.5)
    fig, ax = plt.subplots(figsize=(fig_w, fig_h))
    ax.axis("off")

    headers = [""] + col_labels
    tbl = ax.table(
        cellText=rows,
        colLabels=headers,
        loc="center",
        cellLoc="center",
    )
    tbl.auto_set_font_size(False)
    tbl.set_fontsize(9)
    tbl.scale(1, 1.4)

    # style header row
    for j in range(ncols):
        tbl[0, j].set_facecolor("#012169")
        tbl[0, j].set_text_props(color="white", fontweight="bold")

    # style SE rows (every second data row) lighter
    for i in range(1, nrows + 1):
        for j in range(ncols):
            if i % 2 == 0:
                tbl[i, j].set_facecolor("#f5f5f5")

    ax.set_title(title, fontsize=11, fontweight="bold", color="#012169", pad=12)
    fig.tight_layout()
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    fig.savefig(out_path, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"Saved: {out_path}")
    return out_path
