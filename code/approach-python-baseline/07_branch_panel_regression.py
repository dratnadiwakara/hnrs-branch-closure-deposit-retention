"""
Branch-year incumbent deposit regressions — Table 1 equivalent.

Replicates Table 1 from branch_panel_regression_app_03042026.qmd.

Outcome:   gr_branch = (dep_{t+1} - dep_{t-1}) / dep_{t-1}  [2-yr window]
Treatment: share_deps_closed  (deposit-weighted, competitor closures in county)
Controls:  log1p(dep_lag1_aligned), log1p(banks_county_lag1),
           county_dep_growth_t4_t1, log_population_density,
           lag_county_deposit_hhi, lag_establishment_gr, lag_payroll_gr,
           lag_hmda_mtg_amt_gr, lag_cra_loan_amount_amt_lt_1m_gr, lmi
FE:        Model A: UNINUMBR + state_yr + bank_yr
           Model B: state_yr + bank_yr  (no branch FE)
SE:        clustered at UNINUMBR (branch)
Incumbent: bank made NO closures in this county-year
Periods:   2012-2019 | 2020-2024
"""

import sys, os
sys.path.insert(0, "code/approach-python-baseline")

import numpy as np
import pandas as pd
import pyfixest as pf
from common import (load_rds, winsorize, stars,
                    CLOSURE_PANEL, COUNTY_CONTROLS, DATA_DIR)

# ── 1. Load branch panel ──────────────────────────────────────────────────

print("Loading branch panel...")
bp = pd.read_parquet(f"{DATA_DIR}/branch_panel.parquet")
print(f"  shape: {bp.shape}")
print(f"  columns: {bp.columns.tolist()}")

# ── 2. Re-derive incumbent flag (same logic as 03) ────────────────────────

print("\nDeriving incumbent flag...")
raw_small = load_rds(CLOSURE_PANEL)[["CERT","STCNTYBR","YEAR","closed"]].copy()
raw_small["county"] = raw_small["STCNTYBR"].astype(str).str.zfill(5)
raw_small["YEAR"]   = raw_small["YEAR"].astype(int)

closer_set = (
    raw_small[raw_small["closed"] == 1]
    [["CERT","county","YEAR"]].drop_duplicates()
)
closer_set["is_closer"] = True

bp = bp.merge(closer_set, on=["CERT","county","YEAR"], how="left")
bp["is_closer"] = bp["is_closer"].fillna(False).astype(bool)
inc = bp[~bp["is_closer"]].copy()
print(f"  Incumbent branch obs: {len(inc):,}  (dropped {len(bp)-len(inc):,} closer-bank obs)")

# ── 3. Load county controls ───────────────────────────────────────────────

print("\nLoading county controls...")
cc = load_rds(COUNTY_CONTROLS)
print(f"  shape: {cc.shape}")
print(f"  columns:\n  {cc.columns.tolist()}")

# Standardise join keys
if "county" not in cc.columns:
    for cand in ["county_code","STCNTYBR","county_fips","fips","FIPS","stcntybr"]:
        if cand in cc.columns:
            cc = cc.rename(columns={cand: "county"})
            break
cc["county"] = cc["county"].astype(str).str.zfill(5)

if "YEAR" not in cc.columns:
    for cand in ["year","Year","yr","YR"]:
        if cand in cc.columns:
            cc = cc.rename(columns={cand: "YEAR"})
            break
cc["YEAR"] = cc["YEAR"].astype(int)

print(f"\n  County controls after key standardisation: {len(cc):,} rows")
print(f"  Sample county col values: {cc['county'].head(5).tolist()}")

# ── 4. Identify control columns available ────────────────────────────────

# Reference controls (R code exact names)
wanted = [
    "log_population_density",
    "lag_county_deposit_hhi",
    "lag_establishment_gr",
    "lag_payroll_gr",
    "lag_hmda_mtg_amt_gr",
    "lag_cra_loan_amount_amt_lt_1m_gr",
    "lmi",
]

available   = [c for c in wanted if c in cc.columns]
unavailable = [c for c in wanted if c not in cc.columns]

print(f"\n  Available from wanted list:   {available}")
print(f"  NOT found (will be skipped): {unavailable}")

# ── 5. Merge county controls onto branch panel ────────────────────────────

cc_cols = ["county","YEAR"] + available
inc = inc.merge(cc[cc_cols].drop_duplicates(subset=["county","YEAR"]),
                on=["county","YEAR"], how="left")

# ── 6. Build controls list ────────────────────────────────────────────────

# Base controls (already in branch panel)
base_controls = ["log1p_dep_lag1", "log1p_banks_county", "county_dep_growth_t4_t1"]

# Additional controls from county_controls_panel (use whichever were found)
extra_controls = available

all_controls = base_controls + extra_controls
fml_rhs = " + ".join(all_controls)

print(f"\nControls in regression:\n  {all_controls}")

# ── 7. Summary stats (2019 baseline year) ────────────────────────────────

print("\n" + "=" * 70)
print("Summary Stats — Incumbent branches, YEAR == 2019")
print("=" * 70)
stat_vars = ["gr_branch","share_deps_closed"] + all_controls[:4]
sub2019 = inc[inc["YEAR"] == 2019][stat_vars].dropna()
print(f"  N = {len(sub2019):,}")
fmt = f"  {'Variable':40s}  {'Mean':>10s}  {'Median':>10s}  {'SD':>10s}"
print(fmt)
print("  " + "-" * 74)
for v in stat_vars:
    if v not in sub2019.columns: continue
    s = sub2019[v]
    print(f"  {v:40s}  {s.mean():>10.4f}  {s.median():>10.4f}  {s.std():>10.4f}")

# ── 8. Period filters ─────────────────────────────────────────────────────

needed = ["gr_branch","share_deps_closed","UNINUMBR","state_yr","bank_yr","YEAR"] + all_controls
inc_clean = inc[needed].dropna(subset=["gr_branch","share_deps_closed","UNINUMBR","state_yr","bank_yr"])
inc_clean["UNINUMBR"] = inc_clean["UNINUMBR"].astype(str)

pre  = inc_clean[inc_clean["YEAR"].between(2012, 2019)]
post = inc_clean[inc_clean["YEAR"] >= 2020]

print(f"\nPre-period (2012-2019): {len(pre):,} obs")
print(f"Post-period (2020-2024): {len(post):,} obs")

# Raw correlation check
for lbl, df in [("2012-2019", pre), ("2020-2024", post)]:
    sub = df[["share_deps_closed","gr_branch"]].dropna()
    r = sub.corr().iloc[0,1]
    print(f"  Raw corr(share_deps_closed, gr_branch) {lbl}: {r:.4f}")

# ── 9. Regressions ────────────────────────────────────────────────────────

fml_branch = f"gr_branch ~ share_deps_closed + {fml_rhs} | UNINUMBR + state_yr + bank_yr"
fml_nofe   = f"gr_branch ~ share_deps_closed + {fml_rhs} | state_yr + bank_yr"

models = []   # list of (label, fit | None)

for lbl, df, fml in [
    ("2012-2019 (branch FE)", pre,  fml_branch),
    ("2012-2019 (no branch)", pre,  fml_nofe),
    ("2020-2024 (branch FE)", post, fml_branch),
    ("2020-2024 (no branch)", post, fml_nofe),
]:
    needed_fml = ["gr_branch","share_deps_closed","UNINUMBR","state_yr","bank_yr"] + all_controls
    sub = df[needed_fml].dropna(subset=needed_fml)
    print(f"\nRunning {lbl}  (N={len(sub):,})...")
    try:
        fit = pf.feols(fml, data=sub, vcov={"CRV1": "UNINUMBR"},
                       fixef_maxiter=500000, fixef_tol=1e-5)
        models.append((lbl, fit))
        c = fit.coef()["share_deps_closed"]
        s = fit.se()["share_deps_closed"]
        p = fit.pvalue()["share_deps_closed"]
        print(f"  share_deps_closed: {c:+.4f}  se={s:.4f}  p={p:.3f}  {stars(p)}")
    except Exception as e:
        print(f"  ERROR: {e}")
        models.append((lbl, None))

# ── 10. Text table ────────────────────────────────────────────────────────

coef_vars  = ["share_deps_closed"] + all_controls
var_labels = ["share_deps_closed",
              "log1p(dep_lag1)",
              "log1p(banks_county)",
              "county_dep_growth_t4_t1"] + extra_controls

header_labels = [lbl for lbl, m in models if m is not None]
valid_models  = [m   for lbl, m in models if m is not None]

width = 80
print(f"\n{'=' * width}")
print("Incumbent Branch Deposit Growth")
print("Outcome: gr_branch = (dep_{t+1} - dep_{t-1}) / dep_{t-1}")
print("SE clustered at branch (UNINUMBR)")
print("=" * width)
col_w = 18
print(f"{'':28s}" + "".join(f"{h:>{col_w}s}" for h in header_labels))
print("-" * width)

for var, lbl in zip(coef_vars, var_labels):
    coef_row = f"{lbl:28s}"
    se_row   = f"{'':28s}"
    for m in valid_models:
        try:
            c = m.coef()[var]; s = m.se()[var]; p = m.pvalue()[var]
            coef_row += f"{c:>+17.4f}{stars(p):1s}"
            se_row   += f"{'(' + f'{s:.4f}' + ')':>{col_w}s}"
        except KeyError:
            coef_row += f"{'—':>{col_w}s}"; se_row += f"{'':>{col_w}s}"
    print(coef_row)
    print(se_row)

print("-" * width)
n_row  = f"{'N':28s}"
fe_row = f"{'Branch FE':28s}"
for lbl, m in zip(header_labels, valid_models):
    try:    n_row  += f"{int(m._N):>{col_w},}"
    except: n_row  += f"{'—':>{col_w}s}"
    fe_row += f"{'Yes' if 'branch FE' in lbl else 'No':>{col_w}s}"
print(n_row)
print(fe_row)
print(f"{'state_yr + bank_yr FE':28s}" + f"{'Yes':>{col_w}s}" * len(valid_models))
print("=" * width)
