"""
Build bank-county-year lending panel (deposits + HMDA + CRA).

Inputs:
  branch_panel.parquet  (from 01_build_branch_panel.py)
  CLOSURE_PANEL         (for CERT ↔ RSSDID crosswalk)
  HMDA_DB               (DuckDB)
  CRA_DB                (DuckDB)

Output:
  code/approach-python-baseline/data/lending_panel.parquet
"""

import sys, os
sys.path.insert(0, "code/approach-python-baseline")

import numpy as np
import pandas as pd
import duckdb
from common import (
    load_rds, winsorize,
    CLOSURE_PANEL, HMDA_DB, CRA_DB,
    DATA_DIR, TOP4_CERT,
)

# ── 1. Load branch panel ──────────────────────────────────────────────────

print("Loading branch panel...")
bp = pd.read_parquet(f"{DATA_DIR}/branch_panel.parquet")
print(f"  shape: {bp.shape}")

# Identify incumbent banks: bank did NOT close any branch in this county-year.
# A bank is an incumbent if none of its branches in that county-year have closed == 1.
# We need to re-load the raw closure panel to get this at bank-county-year level.
# Simpler: the branch panel already excludes closed branches (closed != 1 filter).
# But banks that closed OTHER branches in the same county-year are still present.
# Flag them out.

# From the branch panel, check which (CERT, county, YEAR) combos have ANY closure.
# We don't have the closed==1 rows in bp (we filtered them out).
# Re-derive from closure panel.
print("Loading closure panel for incumbent flag...")
raw = load_rds(CLOSURE_PANEL)
raw["county"] = raw["STCNTYBR"].astype(str).str.zfill(5)
raw["YEAR"]   = raw["YEAR"].astype(int)

closer_bcy = (
    raw[raw["closed"] == 1]
    .groupby(["CERT", "county", "YEAR"])
    .size()
    .reset_index(name="n_closed")
    [["CERT", "county", "YEAR"]]
)
closer_bcy["is_closer"] = True

bp = bp.merge(closer_bcy, on=["CERT", "county", "YEAR"], how="left")
bp["is_closer"] = bp["is_closer"].fillna(False).astype(bool)
bp_inc = bp[~bp["is_closer"]].copy()
print(f"  Incumbent branch obs: {len(bp_inc):,}  (dropped {len(bp)-len(bp_inc):,} closer-bank obs)")

# ── 2. Aggregate to bank-county-year deposit growth ──────────────────────

dep_bcy = (
    bp_inc[bp_inc["dep_lag1_aligned"].notna() & bp_inc["dep_lead1_aligned"].notna() &
           (bp_inc["dep_lag1_aligned"] > 0)]
    .groupby(["CERT", "county", "YEAR"])
    .agg(
        dep_lag1_total  = ("dep_lag1_aligned",  "sum"),
        dep_lead1_total = ("dep_lead1_aligned", "sum"),
    )
    .reset_index()
)
dep_bcy["dep_growth"] = (dep_bcy["dep_lead1_total"] - dep_bcy["dep_lag1_total"]) / dep_bcy["dep_lag1_total"]

# ── 3. County-year controls (one row per county-year from branch panel) ───

cy_cols = ["county", "YEAR", "share_deps_closed", "banks_county_lag1",
           "county_dep_growth_t4_t1", "log1p_banks_county"]
cy_controls = bp_inc[cy_cols].drop_duplicates(subset=["county","YEAR"])

# ── 4. CERT ↔ RSSDID crosswalk ───────────────────────────────────────────

cert_rssd = (
    raw[raw["RSSDID"].notna() & (raw["RSSDID"] != 0)]
    .groupby(["CERT", "YEAR"])["RSSDID"]
    .agg(lambda x: x.value_counts().index[0])  # most common RSSDID per CERT-year
    .reset_index()
)

# ── 5. Query HMDA DuckDB ─────────────────────────────────────────────────

print("\nQuerying HMDA...")
con = duckdb.connect(HMDA_DB, read_only=True)
print("  avery_crosswalk cols:", con.execute("SELECT * FROM avery_crosswalk LIMIT 0").df().columns.tolist())

hmda_pre = con.execute("""
    SELECT
        CAST(a.rssd_id AS VARCHAR)  AS rssdid,
        LEFT(l.census_tract, 5)     AS county_fips,
        l.year,
        SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM lar_panel l
    JOIN avery_crosswalk a
      ON  l.respondent_id = a.respondent_id
      AND CAST(l.agency_code AS INTEGER) = CAST(a.agency_code AS INTEGER)
      AND l.year = a.activity_year
    WHERE l.action_taken = '1'
      AND l.year < 2018
      AND LENGTH(l.census_tract) >= 5
    GROUP BY rssdid, county_fips, l.year
""").df()

hmda_post = con.execute("""
    SELECT
        CAST(a.rssd_id AS VARCHAR)  AS rssdid,
        LEFT(l.census_tract, 5)     AS county_fips,
        l.year,
        SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM lar_panel l
    JOIN avery_crosswalk a
      ON  l.lei = a.lei
      AND l.year = a.activity_year
    WHERE l.action_taken = '1'
      AND l.year >= 2018
      AND LENGTH(l.census_tract) >= 5
    GROUP BY rssdid, county_fips, l.year
""").df()
con.close()

hmda = pd.concat([hmda_pre, hmda_post], ignore_index=True)
hmda = hmda[hmda["rssdid"].notna() & (hmda["rssdid"] != "0")]
hmda["YEAR"]   = hmda["year"].astype(int)
hmda["rssdid"] = hmda["rssdid"].astype(float).astype(int)
hmda = hmda.groupby(["rssdid","county_fips","YEAR"])["hmda_amt"].sum().reset_index()

# Map RSSDID → CERT
hmda = hmda.merge(cert_rssd.rename(columns={"RSSDID":"rssdid"}), on=["rssdid","YEAR"], how="left")
hmda = hmda[hmda["CERT"].notna()].copy()
hmda["CERT"] = hmda["CERT"].astype(int)
hmda_bcy = hmda.groupby(["CERT","county_fips","YEAR"])["hmda_amt"].sum().reset_index()
hmda_bcy = hmda_bcy.rename(columns={"county_fips":"county"})
print(f"  HMDA rows: {len(hmda_bcy):,}")

# Build growth: lag1 and lead1 per (CERT, county)
def build_growth(df, amt_col, growth_col):
    df = df.sort_values(["CERT","county","YEAR"]).copy()
    df["amt_lag1"]  = df.groupby(["CERT","county"])[amt_col].shift(1)
    df["yr_lag1"]   = df.groupby(["CERT","county"])["YEAR"].shift(1)
    df["amt_lead1"] = df.groupby(["CERT","county"])[amt_col].shift(-1)
    df["yr_lead1"]  = df.groupby(["CERT","county"])["YEAR"].shift(-1)
    df["amt_lag1"]  = np.where(df["yr_lag1"]  == df["YEAR"]-1, df["amt_lag1"],  np.nan)
    df["amt_lead1"] = np.where(df["yr_lead1"] == df["YEAR"]+1, df["amt_lead1"], np.nan)
    df[growth_col]  = np.where(
        df["amt_lag1"].notna() & (df["amt_lag1"] > 0) & df["amt_lead1"].notna(),
        (df["amt_lead1"] - df["amt_lag1"]) / df["amt_lag1"],
        np.nan,
    )
    return df[["CERT","county","YEAR", growth_col]]

hmda_bcy = build_growth(hmda_bcy, "hmda_amt", "hmda_growth")

# ── 6. Query CRA DuckDB ───────────────────────────────────────────────────

print("\nQuerying CRA...")
con = duckdb.connect(CRA_DB, read_only=True)
print("  transmittal_panel cols:", con.execute("SELECT * FROM transmittal_panel LIMIT 0").df().columns.tolist())

cra_raw = con.execute("""
    SELECT
        CAST(t.rssdid AS VARCHAR)  AS rssdid,
        d.county_fips,
        d.year,
        SUM(
          (COALESCE(CAST(d.amt_loans_lt_100k   AS DOUBLE), 0) +
           COALESCE(CAST(d.amt_loans_100k_250k AS DOUBLE), 0) +
           COALESCE(CAST(d.amt_loans_250k_1m   AS DOUBLE), 0)) * 1000
        ) AS cra_amt
    FROM disclosure_panel d
    JOIN transmittal_panel t
      ON  d.respondent_id = t.respondent_id
      AND d.agency_code   = t.agency_code
      AND d.year          = t.year
    WHERE TRIM(d.table_id)     = 'D1-1'
      AND TRIM(d.report_level) = '040'
      AND CAST(d.action_taken  AS INTEGER) = 1
      AND d.county_fips IS NOT NULL
    GROUP BY rssdid, d.county_fips, d.year
""").df()
con.close()

cra_raw = cra_raw[cra_raw["rssdid"].notna() & (cra_raw["rssdid"] != "0")].copy()
cra_raw["YEAR"]   = cra_raw["year"].astype(int)
cra_raw["rssdid"] = cra_raw["rssdid"].astype(float).astype(int)
cra_raw = cra_raw.groupby(["rssdid","county_fips","YEAR"])["cra_amt"].sum().reset_index()

cra_raw = cra_raw.merge(cert_rssd.rename(columns={"RSSDID":"rssdid"}), on=["rssdid","YEAR"], how="left")
cra_raw = cra_raw[cra_raw["CERT"].notna()].copy()
cra_raw["CERT"] = cra_raw["CERT"].astype(int)
cra_bcy = cra_raw.groupby(["CERT","county_fips","YEAR"])["cra_amt"].sum().reset_index()
cra_bcy = cra_bcy.rename(columns={"county_fips":"county"})
print(f"  CRA rows: {len(cra_bcy):,}")

cra_bcy = build_growth(cra_bcy, "cra_amt", "cra_growth")

# ── 7. Assemble panel ─────────────────────────────────────────────────────

bcy_grid = dep_bcy[["CERT","county","YEAR"]].drop_duplicates()

panel = bcy_grid.merge(dep_bcy[["CERT","county","YEAR","dep_growth"]], on=["CERT","county","YEAR"], how="left")
panel = panel.merge(hmda_bcy, on=["CERT","county","YEAR"], how="left")
panel = panel.merge(cra_bcy,  on=["CERT","county","YEAR"], how="left")
panel = panel.merge(cy_controls, on=["county","YEAR"], how="left")

# Winsorize outcomes
for col in ["dep_growth","hmda_growth","cra_growth"]:
    notna = panel[col].notna()
    panel.loc[notna, col] = winsorize(panel.loc[notna, col])

# FE identifiers
panel["bank_county_id"] = panel["CERT"].astype(str) + "_" + panel["county"]
panel["state_yr"]       = panel["county"].str[:2] + panel["YEAR"].astype(str)
panel["bank_yr"]        = panel["CERT"].astype(str) + panel["YEAR"].astype(str)
panel["log1p_dep_lag1"] = np.log1p(dep_bcy.set_index(["CERT","county","YEAR"])["dep_lag1_total"].reindex(pd.MultiIndex.from_frame(panel[["CERT","county","YEAR"]])).values)

# ── 8. Diagnostics & save ─────────────────────────────────────────────────

print(f"\nPanel rows: {len(panel):,}")
print(f"dep_growth  non-NA: {panel['dep_growth'].notna().sum():,}")
print(f"hmda_growth non-NA: {panel['hmda_growth'].notna().sum():,}")
print(f"cra_growth  non-NA: {panel['cra_growth'].notna().sum():,}")

out = f"{DATA_DIR}/lending_panel.parquet"
panel.to_parquet(out, index=False)
print(f"\nSaved: {out}")
