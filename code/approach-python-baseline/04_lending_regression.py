"""
Bank-county-year lending regressions (deposits + HMDA + CRA).

Spec: outcome ~ share_deps_closed + controls | bank_county_id + state_yr + bank_yr
SE clustered at bank_county_id.
3 outcomes × 3 periods = 9 regressions.

Output: output/lending_table.png
"""

import sys
sys.path.insert(0, "code/approach-python-baseline")

import numpy as np
import pandas as pd
import pyfixest as pf
from common import make_reg_table, DATA_DIR, OUTPUT_DIR

# ── 1. Load lending panel ─────────────────────────────────────────────────

print("Loading lending panel...")
panel = pd.read_parquet(f"{DATA_DIR}/lending_panel.parquet")
print(f"  shape: {panel.shape}")
print(f"  columns: {panel.columns.tolist()}")

controls  = ["log1p_dep_lag1", "log1p_banks_county", "county_dep_growth_t4_t1"]
fml_rhs   = " + ".join(controls)
outcomes  = ["dep_growth", "hmda_growth", "cra_growth"]
outcome_labels = ["Deposit Growth", "HMDA Mortgage Growth", "CRA SBL Growth"]

periods = {
    "Pre-2012":  panel[panel["YEAR"] < 2012],
    "2012–2024": panel[panel["YEAR"].between(2012, 2024)],
    "2012–2019": panel[panel["YEAR"].between(2012, 2019)],
}

# ── 2. Run 9 regressions ──────────────────────────────────────────────────

results = {}   # (outcome, period) → model or None

for outcome, olabel in zip(outcomes, outcome_labels):
    for period_label, df in periods.items():
        fml = f"{outcome} ~ share_deps_closed + {fml_rhs} | bank_county_id + state_yr + bank_yr"
        needed = [outcome, "share_deps_closed", "bank_county_id", "state_yr", "bank_yr"] + controls
        sub = df[needed].dropna(subset=needed)
        print(f"\n{olabel} | {period_label}  (N={len(sub):,})")
        if len(sub) < 100:
            print("  too few obs, skipping")
            results[(outcome, period_label)] = None
            continue
        try:
            fit = pf.feols(fml, data=sub, vcov={"CRV1": "bank_county_id"},
                           fixef_maxiter=500000, fixef_tol=1e-5)
            results[(outcome, period_label)] = fit
            c = fit.coef()["share_deps_closed"]
            s = fit.se()["share_deps_closed"]
            p = fit.pvalue()["share_deps_closed"]
            print(f"  coef={c:.4f}  se={s:.4f}  p={p:.3f}")
        except Exception as e:
            print(f"  ERROR: {e}")
            results[(outcome, period_label)] = None

# ── 3. Render combined table (one column per period, one panel per outcome) ──

import os, matplotlib.pyplot as plt

period_labels = list(periods.keys())
noutcomes  = len(outcomes)
nperiods   = len(period_labels)

# Collect rows for the table
# Structure: for each outcome, show share_deps_closed coef + se + N
table_rows = []
headers    = [""] + period_labels

for outcome, olabel in zip(outcomes, outcome_labels):
    # Separator row
    table_rows.append([f"── {olabel} ──"] + [""] * nperiods)
    coef_row = ["  share_deps_closed"]
    se_row   = [""]
    n_row    = ["  N"]
    for pl in period_labels:
        m = results.get((outcome, pl))
        if m is None:
            coef_row.append("–")
            se_row.append("")
            n_row.append("–")
        else:
            from common import stars
            c = m.coef()["share_deps_closed"]
            s = m.se()["share_deps_closed"]
            p = m.pvalue()["share_deps_closed"]
            coef_row.append(f"{c:.4f}{stars(p)}")
            se_row.append(f"({s:.4f})")
            n_row.append(f"{int(m._N):,}")
    table_rows.append(coef_row)
    table_rows.append(se_row)
    table_rows.append(n_row)

# Render
nrows  = len(table_rows)
ncols  = len(period_labels) + 1
fig_h  = max(4, nrows * 0.45 + 1.5)
fig_w  = max(9, ncols * 2.8)

fig, ax = plt.subplots(figsize=(fig_w, fig_h))
ax.axis("off")

tbl = ax.table(
    cellText  = table_rows,
    colLabels = headers,
    loc       = "center",
    cellLoc   = "center",
)
tbl.auto_set_font_size(False)
tbl.set_fontsize(9)
tbl.scale(1, 1.5)

for j in range(ncols):
    tbl[0, j].set_facecolor("#012169")
    tbl[0, j].set_text_props(color="white", fontweight="bold")

# Shade separator rows
for i, row in enumerate(table_rows, start=1):
    if row[0].startswith("──"):
        for j in range(ncols):
            tbl[i, j].set_facecolor("#e8ecf5")
            tbl[i, j].set_text_props(fontweight="bold", color="#012169")

ax.set_title(
    "Incumbent Bank-County-Year Regressions\n"
    "outcome ~ share_deps_closed + controls | bank_county_id + state_yr + bank_yr\n"
    "SE clustered at bank-county",
    fontsize=10, fontweight="bold", color="#012169", pad=12,
)
fig.tight_layout()

os.makedirs(OUTPUT_DIR, exist_ok=True)
out_path = f"{OUTPUT_DIR}/lending_table.png"
fig.savefig(out_path, dpi=150, bbox_inches="tight", facecolor="white")
plt.close(fig)
print(f"\nTable saved: {out_path}")
