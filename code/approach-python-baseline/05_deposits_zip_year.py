"""
Zip-year incumbent deposit reallocation regression.

Unit:      zip-year
Outcome:   (inc_deps_tp1 - inc_deps_tm1) / inc_deps_tm1  [2-year growth rate, own baseline]
           Normalization by inc_deps_tm1 avoids mechanical bias from denominator including
           closed-branch deposits (which would inflate total_t1 when treatment is high).
Treatment: share of zip deposits in closed branches (deposit-weighted)
Controls:  log(n_branches), log(n_banks)
FE:        zip + county×year
SE:        clustered at zip
Incumbent: banks with NO closed branch in this zip-year

Periods: pre-2012 | 2012-2019 | 2020-2024
"""

import sys, os
sys.path.insert(0, "code/approach-python-baseline")

import numpy as np
import pandas as pd
import pyfixest as pf
from common import load_rds, winsorize, stars, CLOSURE_PANEL, OUTPUT_DIR

# ── 1. Load raw closure panel ─────────────────────────────────────────────

print("Loading closure panel...")
raw = load_rds(CLOSURE_PANEL)
print(f"  shape: {raw.shape}")

raw["county"]     = raw["STCNTYBR"].astype(str).str.zfill(5)
raw["zip"]        = raw["ZIPBR"].astype(str).str.zfill(5)
raw["YEAR"]       = raw["YEAR"].astype(int)
raw["closed"]     = raw["closed"].fillna(0).astype(int)
raw["new_branch"] = raw["new_branch"].fillna(0).astype(int)

# ── 2. Branch-level lags and leads ────────────────────────────────────────

raw = raw.sort_values(["UNINUMBR", "YEAR"]).copy()
raw["dep_lag1"]   = raw.groupby("UNINUMBR")["DEPSUMBR"].shift(1)
raw["year_lag1"]  = raw.groupby("UNINUMBR")["YEAR"].shift(1)
raw["dep_lead1"]  = raw.groupby("UNINUMBR")["DEPSUMBR"].shift(-1)
raw["year_lead1"] = raw.groupby("UNINUMBR")["YEAR"].shift(-1)

raw["dep_lag1_aligned"]  = np.where(raw["year_lag1"]  == raw["YEAR"] - 1, raw["dep_lag1"],  np.nan)
raw["dep_lead1_aligned"] = np.where(raw["year_lead1"] == raw["YEAR"] + 1, raw["dep_lead1"], np.nan)

# ── 3. Zip-year aggregation ───────────────────────────────────────────────

# 3a. Total branches and deposits in zip at t-1
zip_total = (
    raw[raw["dep_lag1_aligned"].notna() & (raw["dep_lag1_aligned"] > 0)]
    .groupby(["zip","YEAR"])
    .agg(
        total_deps_t1 = ("dep_lag1_aligned", "sum"),
        n_branches_t1 = ("UNINUMBR",         "nunique"),
        n_banks_t1    = ("CERT",             "nunique"),
    )
    .reset_index()
)

# 3b. Share of deposits closed: sum of closed-branch dep_lag1 / total zip dep_lag1
zip_closed_deps = (
    raw[(raw["closed"] == 1) & raw["dep_lag1_aligned"].notna() & (raw["dep_lag1_aligned"] > 0)]
    .groupby(["zip","YEAR"])
    .agg(closed_deps_t1=("dep_lag1_aligned","sum"))
    .reset_index()
)

# 3c. Identify incumbent banks: NO closed branch in this zip-year
closers = (
    raw[raw["closed"] == 1][["zip","YEAR","CERT"]]
    .drop_duplicates()
)
closers["not_incumbent"] = True

raw_with_flag = raw.merge(closers, on=["zip","YEAR","CERT"], how="left")
raw_with_flag["not_incumbent"] = raw_with_flag["not_incumbent"].fillna(False).astype(bool)
inc = raw_with_flag[~raw_with_flag["not_incumbent"]].copy()

# 3d. Incumbent deposits: 2-year window, same branches required at both endpoints
inc_both = inc[
    inc["dep_lag1_aligned"].notna() & (inc["dep_lag1_aligned"] > 0) &
    inc["dep_lead1_aligned"].notna()
].copy()

inc_tm1 = (
    inc_both.groupby(["zip","YEAR"])["dep_lag1_aligned"]
    .sum().reset_index(name="inc_deps_tm1")
)
inc_tp1 = (
    inc_both.groupby(["zip","YEAR"])["dep_lead1_aligned"]
    .sum().reset_index(name="inc_deps_tp1")
)
zip_inc = inc_tm1.merge(inc_tp1, on=["zip","YEAR"], how="inner")

# ── 4. Build zip-year panel ───────────────────────────────────────────────

panel = zip_total.merge(zip_closed_deps, on=["zip","YEAR"], how="left")
panel = panel.merge(zip_inc,             on=["zip","YEAR"], how="left")

panel["closed_deps_t1"] = panel["closed_deps_t1"].fillna(0)

# Treatment: share of deposits closed
panel["share_deps_closed"] = panel["closed_deps_t1"] / panel["total_deps_t1"].clip(lower=1)

# Controls
panel["log_n_branches"] = np.log1p(panel["n_branches_t1"])
panel["log_n_banks"]    = np.log1p(panel["n_banks_t1"])

# Outcome: 2-year growth rate of incumbent deposits, normalized by own t-1 baseline.
# Using inc_deps_tm1 as denominator avoids mechanical negative bias: if we used
# total_deps_t1 (which includes closed-branch deposits), high-treatment zip-years
# would have an inflated denominator, mechanically pushing the coefficient negative.
panel["outcome"] = np.where(
    panel["inc_deps_tm1"] > 0,
    (panel["inc_deps_tp1"] - panel["inc_deps_tm1"]) / panel["inc_deps_tm1"],
    np.nan,
)

# FE identifiers
zip_county = raw[["zip","county"]].drop_duplicates("zip")
panel = panel.merge(zip_county, on="zip", how="left")
panel["county_yr"] = panel["county"] + "_" + panel["YEAR"].astype(str)

# Winsorize outcome
panel["outcome"] = winsorize(panel["outcome"].dropna()).reindex(panel.index)

# Sample filters
panel = panel[
    panel["YEAR"].between(2000, 2024) &
    (panel["n_banks_t1"] >= 2) &
    (panel["n_branches_t1"] >= 2) &
    panel["outcome"].notna() &
    panel["county"].notna()
]

print(f"\nZip-year panel: {len(panel):,} rows  |  Unique zips: {panel['zip'].nunique():,}")
print(f"Outcome  mean={panel['outcome'].mean():.4f}  median={panel['outcome'].median():.4f}")
print(f"Raw corr(share_deps_closed, outcome): {panel[['share_deps_closed','outcome']].corr().iloc[0,1]:.4f}")
print(f"\nshare_deps_closed by period:")
for lbl, mask in [("pre-2012",  panel["YEAR"] < 2012),
                  ("2012-2019", panel["YEAR"].between(2012,2019)),
                  ("2020-2024", panel["YEAR"].between(2020,2024))]:
    sub = panel[mask]
    print(f"  {lbl}: mean={sub['share_deps_closed'].mean():.4f}  N={len(sub):,}")

# ── 5. Regressions ────────────────────────────────────────────────────────

fml = "outcome ~ share_deps_closed + log_n_branches + log_n_banks | zip + county_yr"

periods = {
    "Pre-2012":  panel[panel["YEAR"] < 2012],
    "2012-2019": panel[panel["YEAR"].between(2012, 2019)],
    "2020-2024": panel[panel["YEAR"].between(2020, 2024)],
}

needed = ["outcome","share_deps_closed","log_n_branches","log_n_banks","zip","county_yr","YEAR"]

models = []
for label, df in periods.items():
    sub = df[needed].dropna(subset=needed)
    print(f"\nRunning {label}  (N={len(sub):,})...")
    try:
        fit = pf.feols(fml, data=sub, vcov={"CRV1": "zip"},
                       fixef_maxiter=500000, fixef_tol=1e-5)
        models.append((label, fit))
        c = fit.coef()["share_deps_closed"]
        s = fit.se()["share_deps_closed"]
        p = fit.pvalue()["share_deps_closed"]
        print(f"  share_deps_closed: {c:.4f}  se={s:.4f}  p={p:.3f}  {stars(p)}")
    except Exception as e:
        print(f"  ERROR: {e}")
        models.append((label, None))

# ── 6. Print text table ───────────────────────────────────────────────────

coef_vars = ["share_deps_closed", "log_n_branches", "log_n_banks"]
var_labels = ["share_deps_closed", "log(N branches)", "log(N banks)"]

header_labels = [lbl for lbl, m in models if m is not None]
valid_models  = [m  for lbl, m in models if m is not None]

print("\n" + "=" * 70)
print("Incumbent Deposit Growth -- Zip-Year Level")
print("FE: zip + county_yr  |  SE clustered at zip")
print("=" * 70)
print(f"{'':25s}" + "".join(f"{h:>15s}" for h in header_labels))
print("-" * 70)

for var, lbl in zip(coef_vars, var_labels):
    coef_row = f"{lbl:25s}"
    se_row   = f"{'':25s}"
    for m in valid_models:
        try:
            c = m.coef()[var];  s = m.se()[var];  p = m.pvalue()[var]
            coef_row += f"{c:>+14.4f}{stars(p):1s}"
            se_row   += f"{'(' + f'{s:.4f}' + ')':>15s}"
        except KeyError:
            coef_row += f"{'—':>15s}";  se_row += f"{'':>15s}"
    print(coef_row)
    print(se_row)

print("-" * 70)
n_row = f"{'N':25s}"
for m in valid_models:
    try:    n_row += f"{int(m._N):>15,}"
    except: n_row += f"{'—':>15s}"
print(n_row)
print(f"{'FE':25s}" + f"{'zip+county_yr':>15s}" * len(valid_models))
print("=" * 70)

# Also save PNG for reference
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

if valid_models:
    rows = []
    for var, lbl in zip(coef_vars, var_labels):
        coef_row = [lbl]; se_row = [""]
        for m in valid_models:
            try:
                c = m.coef()[var]; s = m.se()[var]; p = m.pvalue()[var]
                coef_row.append(f"{c:+.4f}{stars(p)}"); se_row.append(f"({s:.4f})")
            except KeyError:
                coef_row.append("—"); se_row.append("")
        rows += [coef_row, se_row]
    n_row_t = ["N"] + [f"{int(m._N):,}" for m in valid_models]
    rows.append(n_row_t)

    ncols = len(valid_models) + 1
    fig, ax = plt.subplots(figsize=(max(8, ncols*2.5), max(3, len(rows)*0.45+1.5)))
    ax.axis("off")
    tbl = ax.table(cellText=rows, colLabels=[""] + header_labels,
                   loc="center", cellLoc="center")
    tbl.auto_set_font_size(False); tbl.set_fontsize(9); tbl.scale(1, 1.4)
    for j in range(ncols):
        tbl[0,j].set_facecolor("#012169"); tbl[0,j].set_text_props(color="white", fontweight="bold")
    for i in range(1, len(rows)+1):
        for j in range(ncols):
            if i % 2 == 0: tbl[i,j].set_facecolor("#f5f5f5")
    ax.set_title("Incumbent Deposit Growth — Zip-Year Level\n"
                 "FE: zip + county×year  |  SE clustered at zip",
                 fontsize=11, fontweight="bold", color="#012169", pad=12)
    fig.tight_layout()
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = f"{OUTPUT_DIR}/deposits_zip_year.png"
    fig.savefig(out_path, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"\nPNG saved: {out_path}")
