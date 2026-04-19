"""
Build branch-year incumbent regression sample from raw data.

Inputs  (external):
  CLOSURE_PANEL  — branch-level panel with deposits and closure flags
  FDIC_SOD       — county-year total deposits (for county_dep_growth_t4_t1)

Output:
  code/approach-python-baseline/data/branch_panel.parquet
"""

import sys, os
sys.path.insert(0, "code/approach-python-baseline")

import numpy as np
import pandas as pd
from common import (
    load_rds, winsorize,
    CLOSURE_PANEL, FDIC_SOD,
    DATA_DIR, TOP4_CERT, START_YEAR, END_YEAR,
)

os.makedirs(DATA_DIR, exist_ok=True)

# ── 1. Load closure panel ──────────────────────────────────────────────────

print("Loading closure panel...")
raw = load_rds(CLOSURE_PANEL)
print(f"  shape: {raw.shape}")
print(f"  columns: {raw.columns.tolist()}")

raw["county"] = raw["STCNTYBR"].astype(str).str.zfill(5)
raw["YEAR"]   = raw["YEAR"].astype(int)

# ── 2. Branch-level lags and leads ────────────────────────────────────────

raw = raw.sort_values(["UNINUMBR", "YEAR"]).copy()

for lag in [1, 3]:
    raw[f"dep_lag{lag}"]  = raw.groupby("UNINUMBR")["DEPSUMBR"].shift(lag)
    raw[f"year_lag{lag}"] = raw.groupby("UNINUMBR")["YEAR"].shift(lag)

for lead in [1]:
    raw[f"dep_lead{lead}"]  = raw.groupby("UNINUMBR")["DEPSUMBR"].shift(-lead)
    raw[f"year_lead{lead}"] = raw.groupby("UNINUMBR")["YEAR"].shift(-lead)

# Require consecutive years (aligned lags/leads)
raw["dep_lag1_aligned"]  = np.where(raw["year_lag1"]  == raw["YEAR"] - 1, raw["dep_lag1"],  np.nan)
raw["dep_lag3_aligned"]  = np.where(raw["year_lag3"]  == raw["YEAR"] - 3, raw["dep_lag3"],  np.nan)
raw["dep_lead1_aligned"] = np.where(raw["year_lead1"] == raw["YEAR"] + 1, raw["dep_lead1"], np.nan)

# Outcome: 1-year branch deposit growth
raw["gr_branch"] = np.where(
    raw["dep_lag1_aligned"].notna() & (raw["dep_lag1_aligned"] > 0),
    (raw["dep_lead1_aligned"] - raw["dep_lag1_aligned"]) / raw["dep_lag1_aligned"],
    np.nan,
)

# ── 3. Identify organic (non-M&A) closures ────────────────────────────────
# M&A proxy: CERT changed in the prior 3 years for the same UNINUMBR.
# closure panel must have a 'closed' column (1 = closed this year).

print(f"\n'closed' column present: {'closed' in raw.columns}")
print(raw[["UNINUMBR","YEAR","DEPSUMBR","closed","CERT","RSSDID"]].head(10))

# Build prior-3-year CERT history per branch
raw_sorted = raw.sort_values(["UNINUMBR", "YEAR"])
for lag in [1, 2, 3]:
    raw_sorted[f"CERT_lag{lag}"] = raw_sorted.groupby("UNINUMBR")["CERT"].shift(lag)
    raw_sorted[f"yr_cert_lag{lag}"] = raw_sorted.groupby("UNINUMBR")["YEAR"].shift(lag)

def cert_changed(row):
    for lag in [1, 2, 3]:
        yr = row.get(f"yr_cert_lag{lag}")
        c  = row.get(f"CERT_lag{lag}")
        if pd.notna(yr) and (row["YEAR"] - yr) <= lag and pd.notna(c) and c != row["CERT"]:
            return True
    return False

# Only check closed branches (expensive row-wise — vectorise where possible)
closed_mask = raw_sorted["closed"] == 1
print(f"\nTotal closed obs: {closed_mask.sum():,}")

# Fast vectorised M&A flag: any of the 3 lag CERTs differs AND is consecutive
def ma_flag(df):
    flag = pd.Series(False, index=df.index)
    for lag in [1, 2, 3]:
        yr_ok   = df[f"yr_cert_lag{lag}"] == df["YEAR"] - lag
        changed = df[f"CERT_lag{lag}"] != df["CERT"]
        flag |= (yr_ok & changed)
    return flag

raw_sorted["ma_closure"] = False
raw_sorted.loc[closed_mask, "ma_closure"] = ma_flag(raw_sorted[closed_mask])

print(f"M&A closures flagged: {raw_sorted['ma_closure'].sum():,}")

raw = raw_sorted.copy()

# ── 4. County-year treatment: share of deposits in closed (non-M&A) competitor branches ──

organic_closed = raw[(raw["closed"] == 1) & (~raw["ma_closure"]) & raw["dep_lag1_aligned"].notna()].copy()

# County-year total deposits at t-1 (across all branches)
county_total = (
    raw[raw["dep_lag1_aligned"].notna()]
    .groupby(["county", "YEAR"])["dep_lag1_aligned"]
    .sum()
    .reset_index(name="total_deps_county_lag1")
)

# County-year closed deposits by type
closed_by_county = (
    organic_closed
    .groupby(["county", "YEAR"])
    .agg(
        closed_deps_top4    = ("dep_lag1_aligned", lambda x: x[organic_closed.loc[x.index, "CERT"].isin(TOP4_CERT)].sum()),
        closed_deps_nontop4 = ("dep_lag1_aligned", lambda x: x[~organic_closed.loc[x.index, "CERT"].isin(TOP4_CERT)].sum()),
        closed_deps_total   = ("dep_lag1_aligned", "sum"),
    )
    .reset_index()
)

county_shares = county_total.merge(closed_by_county, on=["county", "YEAR"], how="left")
county_shares = county_shares.fillna({"closed_deps_total": 0, "closed_deps_top4": 0, "closed_deps_nontop4": 0})

county_shares["share_deps_closed"]        = county_shares["closed_deps_total"]   / county_shares["total_deps_county_lag1"].replace(0, np.nan)
county_shares["share_deps_closed_top4"]   = county_shares["closed_deps_top4"]    / county_shares["total_deps_county_lag1"].replace(0, np.nan)
county_shares["share_deps_closed_nontop4"]= county_shares["closed_deps_nontop4"] / county_shares["total_deps_county_lag1"].replace(0, np.nan)
county_shares = county_shares.fillna({"share_deps_closed": 0, "share_deps_closed_top4": 0, "share_deps_closed_nontop4": 0})

# ── 5. County-year bank count ──────────────────────────────────────────────

bank_counts = (
    raw[raw["dep_lag1_aligned"].notna()]
    .groupby(["county", "YEAR"])["CERT"]
    .nunique()
    .reset_index(name="banks_county_curr")
)
bank_counts = bank_counts.sort_values(["county", "YEAR"])
bank_counts["banks_county_lag1"] = bank_counts.groupby("county")["banks_county_curr"].shift(1)

# ── 6. County deposit growth (4-yr trend) from FDIC SOD ───────────────────

print("\nLoading FDIC SOD for county deposit growth...")
sod = load_rds(FDIC_SOD)
print(f"  shape: {sod.shape}")
print(f"  columns: {sod.columns.tolist()}")

sod["county"] = sod["STCNTYBR"].astype(str).str.zfill(5)
sod["YEAR"]   = sod["YEAR"].astype(int)

county_deps_fdic = (
    sod.groupby(["county", "YEAR"])["DEPSUMBR"]
    .sum()
    .reset_index(name="total_deps")
    .sort_values(["county", "YEAR"])
)
county_deps_fdic["deps_lag1"] = county_deps_fdic.groupby("county")["total_deps"].shift(1)
county_deps_fdic["deps_lag4"] = county_deps_fdic.groupby("county")["total_deps"].shift(4)
county_deps_fdic["county_dep_growth_t4_t1"] = np.where(
    county_deps_fdic["deps_lag4"] > 0,
    (county_deps_fdic["deps_lag1"] - county_deps_fdic["deps_lag4"]) / county_deps_fdic["deps_lag4"],
    np.nan,
)

# ── 7. Identify incumbent branches ────────────────────────────────────────
# Incumbent: branch did NOT close in this county-year.
# Must have deposits at t-1 AND t+1.

branch_panel = raw[
    raw["gr_branch"].notna() &
    (raw["closed"] != 1)  # incumbent branches only
].copy()

# ── 8. Merge county-level variables ───────────────────────────────────────

branch_panel = branch_panel.merge(county_shares[["county","YEAR","share_deps_closed","share_deps_closed_top4","share_deps_closed_nontop4","total_deps_county_lag1"]], on=["county","YEAR"], how="left")
branch_panel = branch_panel.merge(bank_counts[["county","YEAR","banks_county_lag1"]], on=["county","YEAR"], how="left")
branch_panel = branch_panel.merge(county_deps_fdic[["county","YEAR","county_dep_growth_t4_t1"]], on=["county","YEAR"], how="left")

# ── 9. Bank size flags ────────────────────────────────────────────────────

branch_panel["top4_bank"] = branch_panel["CERT"].isin(TOP4_CERT).astype(int)

# ── 10. FE identifiers ────────────────────────────────────────────────────

branch_panel["state_yr"] = branch_panel["county"].str[:2] + branch_panel["YEAR"].astype(str)
branch_panel["bank_yr"]  = branch_panel["RSSDID"].astype(str) + branch_panel["YEAR"].astype(str)

# ── 11. Pre-computed log columns ──────────────────────────────────────────

branch_panel["log1p_dep_lag1"]       = np.log1p(branch_panel["dep_lag1_aligned"].fillna(0))
branch_panel["log1p_banks_county"]   = np.log1p(branch_panel["banks_county_lag1"].fillna(0))

# ── 12. Winsorize outcome ─────────────────────────────────────────────────

branch_panel["gr_branch"] = winsorize(branch_panel["gr_branch"])

# ── 13. Final sample filters ──────────────────────────────────────────────

n0 = len(branch_panel)
branch_panel = branch_panel[
    branch_panel["YEAR"].between(START_YEAR, END_YEAR) &
    (branch_panel["banks_county_lag1"] >= 3)
]
print(f"\nAfter year/bank-count filter: {len(branch_panel):,} rows (from {n0:,})")

# ── 14. Diagnostics ───────────────────────────────────────────────────────

print("\nshare_deps_closed by period:")
print(branch_panel.assign(period=pd.cut(branch_panel["YEAR"], bins=[2000,2011,2019,2025], labels=["pre2012","2012-2019","2020-2025"]))
      .groupby("period")["share_deps_closed"].describe())

print(f"\nN obs: {len(branch_panel):,}")
print(f"Unique branches (UNINUMBR): {branch_panel['UNINUMBR'].nunique():,}")
print(f"Year range: {branch_panel['YEAR'].min()} – {branch_panel['YEAR'].max()}")

# ── 15. Save ──────────────────────────────────────────────────────────────

out = f"{DATA_DIR}/branch_panel.parquet"
branch_panel.to_parquet(out, index=False)
print(f"\nSaved: {out}  ({len(branch_panel):,} rows)")
