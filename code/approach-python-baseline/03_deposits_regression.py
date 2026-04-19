"""
Branch-year incumbent deposit regressions.

Spec: gr_branch ~ share_deps_closed + controls | UNINUMBR + state_yr + bank_yr
SE clustered at UNINUMBR.
Three columns: pre-2012 | 2012-2024 | 2012-2019.

Output: output/deposits_table.png
"""

import sys
sys.path.insert(0, "code/approach-python-baseline")

import numpy as np
import pandas as pd
import pyfixest as pf
from common import winsorize, make_reg_table, DATA_DIR, OUTPUT_DIR, TOP4_CERT

# ── 1. Load branch panel ──────────────────────────────────────────────────

print("Loading branch panel...")
bp = pd.read_parquet(f"{DATA_DIR}/branch_panel.parquet")
print(f"  shape: {bp.shape}")

# ── 2. Add incumbent flag ──────────────────────────────────────────────────
# Incumbent = bank made no closures in this county-year.
# Derive from the panel itself: if CERT appears among closers (closed==1) in
# any branch in (county, YEAR), mark as closer.  We dropped closed==1 rows
# already, so reconstruct via the original panel's county-year closer set.
# Faster: any branch-row in bp whose CERT also has closed==1 rows in county-YEAR
# was already handled by 02 (we have is_closer from the closure panel there).
# Here: re-derive from CERT-county-YEAR level using the 'closed' column if present,
# otherwise use the branch panel as-is (already excludes closed==1 branches,
# but may include branches owned by banks that closed other branches).

# Re-load the raw closure panel to get the closer set
from common import load_rds, CLOSURE_PANEL

raw_small = load_rds(CLOSURE_PANEL)[["CERT","STCNTYBR","YEAR","closed"]].copy()
raw_small["county"] = raw_small["STCNTYBR"].astype(str).str.zfill(5)
raw_small["YEAR"]   = raw_small["YEAR"].astype(int)

closer_set = (
    raw_small[raw_small["closed"] == 1]
    [["CERT","county","YEAR"]]
    .drop_duplicates()
)
closer_set["is_closer"] = True

bp = bp.merge(closer_set, on=["CERT","county","YEAR"], how="left")
bp["is_closer"] = bp["is_closer"].fillna(False).astype(bool)

inc = bp[~bp["is_closer"]].copy()
print(f"  Incumbent branch obs: {len(inc):,}")

# Drop rows missing key variables
controls = ["log1p_dep_lag1", "log1p_banks_county", "county_dep_growth_t4_t1"]
fml_rhs  = " + ".join(controls)
fml      = f"gr_branch ~ share_deps_closed + {fml_rhs} | UNINUMBR + state_yr"

needed = ["gr_branch", "share_deps_closed", "UNINUMBR", "state_yr", "bank_yr"] + controls
inc = inc[needed + ["YEAR"]].dropna(subset=needed)
inc["UNINUMBR"] = inc["UNINUMBR"].astype(str)
print(f"  After dropping NAs: {len(inc):,}")

# ── 3. Period subsets ─────────────────────────────────────────────────────

periods = {
    "Pre-2012":   inc[inc["YEAR"] < 2012],
    "2012–2024":  inc[inc["YEAR"].between(2012, 2024)],
    "2012–2019":  inc[inc["YEAR"].between(2012, 2019)],
}

# ── 4. Run regressions ────────────────────────────────────────────────────

models = []
for label, df in periods.items():
    print(f"\nRunning {label}  (N={len(df):,})...")
    try:
        fit = pf.feols(fml, data=df, vcov={"CRV1": "UNINUMBR"},
                       fixef_maxiter=500000, fixef_tol=1e-5)
        models.append(fit)
        print(f"  coef share_deps_closed: {fit.coef()['share_deps_closed']:.4f}  "
              f"se: {fit.se()['share_deps_closed']:.4f}  "
              f"p: {fit.pvalue()['share_deps_closed']:.3f}")
    except Exception as e:
        print(f"  ERROR: {e}")
        models.append(None)

# ── 5. Render table ───────────────────────────────────────────────────────

valid_models  = [m for m in models if m is not None]
valid_labels  = [l for l, m in zip(periods.keys(), models) if m is not None]

if valid_models:
    out_path = f"{OUTPUT_DIR}/deposits_table.png"
    make_reg_table(
        models     = valid_models,
        col_labels = valid_labels,
        row_labels = ["share_deps_closed", "log(dep lag1)", "log(banks county)", "county dep growth (4yr)"],
        coef_names = ["share_deps_closed", "log1p_dep_lag1", "log1p_banks_county", "county_dep_growth_t4_t1"],
        title      = "Incumbent Branch Deposit Growth — gr_branch ~ share_deps_closed\nFE: branch + state×year  |  SE clustered at branch",
        out_path   = out_path,
    )
    print(f"\nTable saved: {out_path}")
else:
    print("No models succeeded.")
