"""
County-year incumbent deposits + HMDA mortgages + CRA SBL regressions.
Also re-runs zip-year deposit regression (from 05) for side-by-side reference.

Unit:      county-year (deposit, HMDA, CRA) | zip-year (deposit only)
Treatment: share_deps_closed = sum(closed_branch dep_lag1) / total dep_lag1 in unit
Outcomes:
  dep_outcome:   incumbent deposit growth — own baseline normalized (t-1 to t+1)
  hmda_growth:   incumbent-bank mortgage origination growth (county aggregate, 2yr window)
  cra_growth:    incumbent-bank SBL growth (county aggregate, 2yr window)
Controls:  log(n_branches), log(n_banks)
FE:        county + state_yr  (county regressions)
           zip + county_yr    (zip regression)
SE:        clustered at county / zip respectively
Incumbent: banks with NO closed branch in this [county|zip]-year

Periods: pre-2012 | 2012-2019 | 2020-2024
"""

import sys, os
sys.path.insert(0, "code/approach-python-baseline")

import numpy as np
import pandas as pd
import duckdb
import pyfixest as pf
from common import load_rds, winsorize, stars, CLOSURE_PANEL, HMDA_DB, CRA_DB, OUTPUT_DIR

# ── helpers ───────────────────────────────────────────────────────────────

def print_text_table(title, fe_note, se_note, coef_vars, var_labels,
                     header_labels, valid_models, width=72):
    print(f"\n{'=' * width}")
    print(title)
    print(f"FE: {fe_note}  |  SE: {se_note}")
    print("=" * width)
    print(f"{'':28s}" + "".join(f"{h:>14s}" for h in header_labels))
    print("-" * width)
    for var, lbl in zip(coef_vars, var_labels):
        coef_row = f"{lbl:28s}"
        se_row   = f"{'':28s}"
        for m in valid_models:
            try:
                c = m.coef()[var]; s = m.se()[var]; p = m.pvalue()[var]
                coef_row += f"{c:>+13.4f}{stars(p):1s}"
                se_row   += f"{'(' + f'{s:.4f}' + ')':>14s}"
            except KeyError:
                coef_row += f"{'—':>14s}"; se_row += f"{'':>14s}"
        print(coef_row)
        print(se_row)
    print("-" * width)
    n_row = f"{'N':28s}"
    for m in valid_models:
        try:    n_row += f"{int(m._N):>14,}"
        except: n_row += f"{'—':>14s}"
    print(n_row)
    print("=" * width)


def summary_stats(df, unit_col, key_vars, period_col="YEAR"):
    """Print per-period summary stats for key variables."""
    periods = [("Pre-2012",  df[period_col] < 2012),
               ("2012-2019", df[period_col].between(2012,2019)),
               ("2020-2024", df[period_col].between(2020,2024))]
    hdr = f"{'Variable':28s}" + "".join(f"{lbl:>20s}" for lbl, _ in periods)
    print(hdr)
    print("-" * (28 + 20 * len(periods)))
    for var in key_vars:
        if var not in df.columns: continue
        row = f"{var:28s}"
        for lbl, mask in periods:
            s = df.loc[mask, var].dropna()
            if len(s) == 0:
                row += f"{'—':>20s}"
            else:
                row += f"  mean={s.mean():+.4f} p50={s.median():+.4f}"
        print(row)
    # N row
    row = f"{'N':28s}"
    for lbl, mask in periods:
        row += f"{mask.sum():>20,}"
    print(row)
    print()


def run_models(panel, outcome_col, fml, needed_base, period_specs, vcov_cluster):
    results = {}
    for lbl, df in period_specs.items():
        needed = needed_base + [outcome_col]
        sub = df[needed].dropna(subset=needed)
        print(f"  {lbl}  N={len(sub):,}")
        if len(sub) < 50:
            print("    skipping — too few obs")
            results[lbl] = None
            continue
        try:
            fit = pf.feols(fml.format(outcome=outcome_col), data=sub,
                           vcov={vcov_cluster[0]: vcov_cluster[1]},
                           fixef_maxiter=500000, fixef_tol=1e-5)
            results[lbl] = fit
            c = fit.coef()["share_deps_closed"]
            s = fit.se()["share_deps_closed"]
            p = fit.pvalue()["share_deps_closed"]
            print(f"    share_deps_closed: {c:+.4f}  se={s:.4f}  p={p:.3f}  {stars(p)}")
        except Exception as e:
            print(f"    ERROR: {e}")
            results[lbl] = None
    return results


# ── 1. Load raw closure panel ─────────────────────────────────────────────

print("Loading closure panel...")
raw = load_rds(CLOSURE_PANEL)
print(f"  shape: {raw.shape}")

raw["county"]     = raw["STCNTYBR"].astype(str).str.zfill(5)
raw["zip"]        = raw["ZIPBR"].astype(str).str.zfill(5)
raw["YEAR"]       = raw["YEAR"].astype(int)
raw["closed"]     = raw["closed"].fillna(0).astype(int)

# ── 2. Branch-level lags and leads ────────────────────────────────────────

raw = raw.sort_values(["UNINUMBR", "YEAR"]).copy()
raw["dep_lag1"]   = raw.groupby("UNINUMBR")["DEPSUMBR"].shift(1)
raw["year_lag1"]  = raw.groupby("UNINUMBR")["YEAR"].shift(1)
raw["dep_lead1"]  = raw.groupby("UNINUMBR")["DEPSUMBR"].shift(-1)
raw["year_lead1"] = raw.groupby("UNINUMBR")["YEAR"].shift(-1)

raw["dep_lag1_aligned"]  = np.where(raw["year_lag1"]  == raw["YEAR"] - 1, raw["dep_lag1"],  np.nan)
raw["dep_lead1_aligned"] = np.where(raw["year_lead1"] == raw["YEAR"] + 1, raw["dep_lead1"], np.nan)

# ── 3. Incumbent flag (shared across zip and county) ──────────────────────

# Incumbents at county-year level: bank has NO closed branch in county-year
county_closers = raw[raw["closed"] == 1][["county","YEAR","CERT"]].drop_duplicates()
county_closers["not_inc_county"] = True

# Incumbents at zip-year level: bank has NO closed branch in zip-year
zip_closers = raw[raw["closed"] == 1][["zip","YEAR","CERT"]].drop_duplicates()
zip_closers["not_inc_zip"] = True

raw = (raw
       .merge(county_closers, on=["county","YEAR","CERT"], how="left")
       .merge(zip_closers,    on=["zip","YEAR","CERT"],    how="left"))
raw["not_inc_county"] = raw["not_inc_county"].fillna(False).astype(bool)
raw["not_inc_zip"]    = raw["not_inc_zip"].fillna(False).astype(bool)

inc_county = raw[~raw["not_inc_county"]].copy()
inc_zip    = raw[~raw["not_inc_zip"]].copy()

# ── 4a. ZIP-YEAR deposit panel (mirrors 05) ───────────────────────────────

print("\nBuilding zip-year panel...")

zip_total = (
    raw[raw["dep_lag1_aligned"].notna() & (raw["dep_lag1_aligned"] > 0)]
    .groupby(["zip","YEAR"])
    .agg(total_deps_t1=("dep_lag1_aligned","sum"),
         n_branches_t1=("UNINUMBR","nunique"),
         n_banks_t1   =("CERT","nunique"))
    .reset_index()
)
zip_closed_deps = (
    raw[(raw["closed"] == 1) & raw["dep_lag1_aligned"].notna() & (raw["dep_lag1_aligned"] > 0)]
    .groupby(["zip","YEAR"])
    .agg(closed_deps_t1=("dep_lag1_aligned","sum"))
    .reset_index()
)
inc_both_zip = inc_zip[
    inc_zip["dep_lag1_aligned"].notna() & (inc_zip["dep_lag1_aligned"] > 0) &
    inc_zip["dep_lead1_aligned"].notna()
].copy()
zip_inc_tm1 = inc_both_zip.groupby(["zip","YEAR"])["dep_lag1_aligned"].sum().reset_index(name="inc_deps_tm1")
zip_inc_tp1 = inc_both_zip.groupby(["zip","YEAR"])["dep_lead1_aligned"].sum().reset_index(name="inc_deps_tp1")
zip_inc = zip_inc_tm1.merge(zip_inc_tp1, on=["zip","YEAR"], how="inner")

zip_panel = zip_total.merge(zip_closed_deps, on=["zip","YEAR"], how="left")
zip_panel = zip_panel.merge(zip_inc, on=["zip","YEAR"], how="left")
zip_panel["closed_deps_t1"]     = zip_panel["closed_deps_t1"].fillna(0)
zip_panel["share_deps_closed"]  = zip_panel["closed_deps_t1"] / zip_panel["total_deps_t1"].clip(lower=1)
zip_panel["log_n_branches"]     = np.log1p(zip_panel["n_branches_t1"])
zip_panel["log_n_banks"]        = np.log1p(zip_panel["n_banks_t1"])
zip_panel["dep_outcome"] = np.where(
    zip_panel["inc_deps_tm1"] > 0,
    (zip_panel["inc_deps_tp1"] - zip_panel["inc_deps_tm1"]) / zip_panel["inc_deps_tm1"],
    np.nan,
)
zip_county = raw[["zip","county"]].drop_duplicates("zip")
zip_panel = zip_panel.merge(zip_county, on="zip", how="left")
zip_panel["county_yr"] = zip_panel["county"] + "_" + zip_panel["YEAR"].astype(str)
notna = zip_panel["dep_outcome"].notna()
zip_panel.loc[notna, "dep_outcome"] = winsorize(zip_panel.loc[notna, "dep_outcome"])
zip_panel = zip_panel[
    zip_panel["YEAR"].between(2000, 2024) &
    (zip_panel["n_banks_t1"] >= 2) &
    (zip_panel["n_branches_t1"] >= 2) &
    zip_panel["dep_outcome"].notna() &
    zip_panel["county"].notna()
]
print(f"  zip-year rows: {len(zip_panel):,}  |  zips: {zip_panel['zip'].nunique():,}")
print("\nZip-year summary stats:")
summary_stats(zip_panel, "zip", ["share_deps_closed","dep_outcome","log_n_branches","log_n_banks"])

# ── 4b. COUNTY-YEAR deposit panel ─────────────────────────────────────────

print("\nBuilding county-year panel...")

county_total = (
    raw[raw["dep_lag1_aligned"].notna() & (raw["dep_lag1_aligned"] > 0)]
    .groupby(["county","YEAR"])
    .agg(total_deps_t1=("dep_lag1_aligned","sum"),
         n_branches_t1=("UNINUMBR","nunique"),
         n_banks_t1   =("CERT","nunique"))
    .reset_index()
)
county_closed_deps = (
    raw[(raw["closed"] == 1) & raw["dep_lag1_aligned"].notna() & (raw["dep_lag1_aligned"] > 0)]
    .groupby(["county","YEAR"])
    .agg(closed_deps_t1=("dep_lag1_aligned","sum"))
    .reset_index()
)
inc_both_county = inc_county[
    inc_county["dep_lag1_aligned"].notna() & (inc_county["dep_lag1_aligned"] > 0) &
    inc_county["dep_lead1_aligned"].notna()
].copy()
county_inc_tm1 = inc_both_county.groupby(["county","YEAR"])["dep_lag1_aligned"].sum().reset_index(name="inc_deps_tm1")
county_inc_tp1 = inc_both_county.groupby(["county","YEAR"])["dep_lead1_aligned"].sum().reset_index(name="inc_deps_tp1")
county_inc = county_inc_tm1.merge(county_inc_tp1, on=["county","YEAR"], how="inner")

county_panel = county_total.merge(county_closed_deps, on=["county","YEAR"], how="left")
county_panel = county_panel.merge(county_inc, on=["county","YEAR"], how="left")
county_panel["closed_deps_t1"]    = county_panel["closed_deps_t1"].fillna(0)
county_panel["share_deps_closed"] = county_panel["closed_deps_t1"] / county_panel["total_deps_t1"].clip(lower=1)
county_panel["log_n_branches"]    = np.log1p(county_panel["n_branches_t1"])
county_panel["log_n_banks"]       = np.log1p(county_panel["n_banks_t1"])
county_panel["dep_outcome"] = np.where(
    county_panel["inc_deps_tm1"] > 0,
    (county_panel["inc_deps_tp1"] - county_panel["inc_deps_tm1"]) / county_panel["inc_deps_tm1"],
    np.nan,
)
county_panel["state_yr"] = county_panel["county"].str[:2] + "_" + county_panel["YEAR"].astype(str)
notna = county_panel["dep_outcome"].notna()
county_panel.loc[notna, "dep_outcome"] = winsorize(county_panel.loc[notna, "dep_outcome"])
county_panel = county_panel[
    county_panel["YEAR"].between(2000, 2024) &
    (county_panel["n_banks_t1"] >= 2) &
    (county_panel["n_branches_t1"] >= 2) &
    county_panel["dep_outcome"].notna() &
    county_panel["county"].notna()
]
print(f"  county-year rows: {len(county_panel):,}  |  counties: {county_panel['county'].nunique():,}")
print("\nCounty-year (deposits) summary stats:")
summary_stats(county_panel, "county", ["share_deps_closed","dep_outcome","log_n_branches","log_n_banks"])

# ── 5. CERT-RSSDID crosswalk (from closure panel) ────────────────────────

cert_rssd = (
    raw[raw["RSSDID"].notna() & (raw["RSSDID"] != 0)]
    .groupby(["CERT","YEAR"])["RSSDID"]
    .agg(lambda x: x.value_counts().index[0])
    .reset_index()
)
cert_rssd["RSSDID"] = cert_rssd["RSSDID"].astype(int)

# Incumbent set at county-year level: CERT with no closures in (county, YEAR)
inc_cert_county = (
    raw[~raw["not_inc_county"]][["CERT","county","YEAR"]]
    .drop_duplicates()
)

def build_inc_county_growth(bcy_df, amt_col, growth_col):
    """
    Given bank×county×year amounts for incumbent banks:
    compute 2-year (t-1 to t+1) growth at county level.
    - For each (CERT, county): compute lag1 and lead1 amounts (year-aligned)
    - Filter to rows where both endpoints exist
    - Aggregate to county-year by summing lag1 and lead1 amounts
    - Growth = (sum_lead1 - sum_lag1) / sum_lag1
    """
    df = bcy_df.sort_values(["CERT","county","YEAR"]).copy()
    df["amt_lag1"]  = df.groupby(["CERT","county"])[amt_col].shift(1)
    df["yr_lag1"]   = df.groupby(["CERT","county"])["YEAR"].shift(1)
    df["amt_lead1"] = df.groupby(["CERT","county"])[amt_col].shift(-1)
    df["yr_lead1"]  = df.groupby(["CERT","county"])["YEAR"].shift(-1)
    df["amt_lag1"]  = np.where(df["yr_lag1"]  == df["YEAR"]-1, df["amt_lag1"],  np.nan)
    df["amt_lead1"] = np.where(df["yr_lead1"] == df["YEAR"]+1, df["amt_lead1"], np.nan)
    # only use observations where both endpoints present
    df = df[df["amt_lag1"].notna() & (df["amt_lag1"] > 0) & df["amt_lead1"].notna()].copy()
    cy = (df.groupby(["county","YEAR"])
            .agg(sum_lag1=("amt_lag1","sum"), sum_lead1=("amt_lead1","sum"))
            .reset_index())
    cy[growth_col] = (cy["sum_lead1"] - cy["sum_lag1"]) / cy["sum_lag1"]
    return cy[["county","YEAR", growth_col]]

# ── 6. HMDA — incumbent banks, county-year ────────────────────────────────

print("\nQuerying HMDA (bank×county level)...")
con = duckdb.connect(HMDA_DB, read_only=True)

hmda_pre = con.execute("""
    SELECT CAST(a.rssd_id AS VARCHAR) AS rssdid,
           LEFT(l.census_tract, 5)    AS county,
           l.year                     AS YEAR,
           SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM lar_panel l
    JOIN avery_crosswalk a
      ON  l.respondent_id = a.respondent_id
      AND CAST(l.agency_code AS INTEGER) = CAST(a.agency_code AS INTEGER)
      AND l.year = a.activity_year
    WHERE l.action_taken = '1' AND l.year < 2018 AND LENGTH(l.census_tract) >= 5
    GROUP BY rssdid, county, l.year
""").df()

hmda_post = con.execute("""
    SELECT CAST(a.rssd_id AS VARCHAR) AS rssdid,
           LEFT(l.census_tract, 5)    AS county,
           l.year                     AS YEAR,
           SUM(CAST(l.loan_amount AS DOUBLE)) AS hmda_amt
    FROM lar_panel l
    JOIN avery_crosswalk a
      ON  l.lei = a.lei AND l.year = a.activity_year
    WHERE l.action_taken = '1' AND l.year >= 2018 AND LENGTH(l.census_tract) >= 5
    GROUP BY rssdid, county, l.year
""").df()
con.close()

hmda_bcy = pd.concat([hmda_pre, hmda_post], ignore_index=True)
hmda_bcy = hmda_bcy[hmda_bcy["rssdid"].notna() & (hmda_bcy["rssdid"] != "0")]
hmda_bcy["YEAR"]   = hmda_bcy["YEAR"].astype(int)
hmda_bcy["rssdid"] = hmda_bcy["rssdid"].astype(float).astype(int)
hmda_bcy = hmda_bcy[hmda_bcy["county"].notna() & (hmda_bcy["county"].str.len() == 5)]
hmda_bcy = hmda_bcy.groupby(["rssdid","county","YEAR"])["hmda_amt"].sum().reset_index()
# map RSSDID → CERT
hmda_bcy = hmda_bcy.merge(cert_rssd.rename(columns={"RSSDID":"rssdid"}),
                           on=["rssdid","YEAR"], how="left")
hmda_bcy = hmda_bcy[hmda_bcy["CERT"].notna()].copy()
hmda_bcy["CERT"] = hmda_bcy["CERT"].astype(int)
# collapse to CERT-county (in case multiple RSSDIDs map to same CERT)
hmda_bcy = hmda_bcy.groupby(["CERT","county","YEAR"])["hmda_amt"].sum().reset_index()
print(f"  HMDA bank-county-year rows (all): {len(hmda_bcy):,}")
# filter to incumbent banks
hmda_inc = hmda_bcy.merge(inc_cert_county, on=["CERT","county","YEAR"], how="inner")
print(f"  HMDA bank-county-year rows (incumbent): {len(hmda_inc):,}")
# aggregate to county-year via 2-year window on amounts
hmda_cy = build_inc_county_growth(hmda_inc, "hmda_amt", "hmda_growth")
print(f"  HMDA county-year rows after 2yr window: {len(hmda_cy):,}")

# ── 7. CRA — incumbent banks, county-year ─────────────────────────────────

print("\nQuerying CRA (bank×county level)...")
con = duckdb.connect(CRA_DB, read_only=True)

cra_raw = con.execute("""
    SELECT CAST(t.rssdid AS VARCHAR) AS rssdid,
           d.county_fips              AS county,
           d.year                     AS YEAR,
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
    WHERE TRIM(d.table_id) = 'D1-1' AND TRIM(d.report_level) = '040'
      AND CAST(d.action_taken AS INTEGER) = 1 AND d.county_fips IS NOT NULL
    GROUP BY rssdid, d.county_fips, d.year
""").df()
con.close()

cra_bcy = cra_raw[cra_raw["rssdid"].notna() & (cra_raw["rssdid"] != "0")].copy()
cra_bcy["YEAR"]   = cra_bcy["YEAR"].astype(int)
cra_bcy["rssdid"] = cra_bcy["rssdid"].astype(float).astype(int)
cra_bcy = cra_bcy.groupby(["rssdid","county","YEAR"])["cra_amt"].sum().reset_index()
cra_bcy = cra_bcy.merge(cert_rssd.rename(columns={"RSSDID":"rssdid"}),
                         on=["rssdid","YEAR"], how="left")
cra_bcy = cra_bcy[cra_bcy["CERT"].notna()].copy()
cra_bcy["CERT"] = cra_bcy["CERT"].astype(int)
cra_bcy = cra_bcy.groupby(["CERT","county","YEAR"])["cra_amt"].sum().reset_index()
print(f"  CRA bank-county-year rows (all): {len(cra_bcy):,}")
cra_inc = cra_bcy.merge(inc_cert_county, on=["CERT","county","YEAR"], how="inner")
print(f"  CRA bank-county-year rows (incumbent): {len(cra_inc):,}")
cra_cy = build_inc_county_growth(cra_inc, "cra_amt", "cra_growth")
print(f"  CRA county-year rows after 2yr window: {len(cra_cy):,}")

# ── 8. Merge HMDA + CRA into county panel ────────────────────────────────

county_panel = county_panel.merge(hmda_cy, on=["county","YEAR"], how="left")
county_panel = county_panel.merge(cra_cy,  on=["county","YEAR"], how="left")

for col in ["hmda_growth","cra_growth"]:
    notna = county_panel[col].notna()
    if notna.sum() > 100:
        county_panel.loc[notna, col] = winsorize(county_panel.loc[notna, col])

print(f"\nCounty panel after merge: {len(county_panel):,} rows")
print(f"  dep_outcome  non-NA: {county_panel['dep_outcome'].notna().sum():,}")
print(f"  hmda_growth  non-NA: {county_panel['hmda_growth'].notna().sum():,}")
print(f"  cra_growth   non-NA: {county_panel['cra_growth'].notna().sum():,}")
print("\nCounty-year (full panel) summary stats:")
summary_stats(county_panel, "county",
              ["share_deps_closed","dep_outcome","hmda_growth","cra_growth"])

# ── 9. Period specs ───────────────────────────────────────────────────────

zip_periods    = {"Pre-2012":  zip_panel[zip_panel["YEAR"] < 2012],
                  "2012-2019": zip_panel[zip_panel["YEAR"].between(2012, 2019)],
                  "2020-2024": zip_panel[zip_panel["YEAR"].between(2020, 2024)]}

county_periods = {"Pre-2012":  county_panel[county_panel["YEAR"] < 2012],
                  "2012-2019": county_panel[county_panel["YEAR"].between(2012, 2019)],
                  "2020-2024": county_panel[county_panel["YEAR"].between(2020, 2024)]}

coef_vars  = ["share_deps_closed", "log_n_branches", "log_n_banks"]
var_labels = ["share_deps_closed", "log(N branches)", "log(N banks)"]

period_labels = list(zip_periods.keys())

# ── 9a. Zip-year deposit regressions ─────────────────────────────────────

print("\n--- Zip-year deposit regressions ---")
zip_needed = ["dep_outcome","share_deps_closed","log_n_branches","log_n_banks","zip","county_yr","YEAR"]
zip_results = run_models(
    zip_panel, "dep_outcome",
    "{outcome} ~ share_deps_closed + log_n_branches + log_n_banks | zip + county_yr",
    ["share_deps_closed","log_n_branches","log_n_banks","zip","county_yr"],
    zip_periods, ("CRV1","zip")
)

# ── 9b. County-year deposit regressions ───────────────────────────────────

print("\n--- County-year deposit regressions ---")
county_dep_results = run_models(
    county_panel, "dep_outcome",
    "{outcome} ~ share_deps_closed + log_n_branches + log_n_banks | county + state_yr",
    ["share_deps_closed","log_n_branches","log_n_banks","county","state_yr"],
    county_periods, ("CRV1","county")
)

# ── 9c. County-year HMDA regressions ──────────────────────────────────────

print("\n--- County-year HMDA regressions ---")
hmda_results = run_models(
    county_panel, "hmda_growth",
    "{outcome} ~ share_deps_closed + log_n_branches + log_n_banks | county + state_yr",
    ["share_deps_closed","log_n_branches","log_n_banks","county","state_yr"],
    county_periods, ("CRV1","county")
)

# ── 9d. County-year CRA regressions ───────────────────────────────────────

print("\n--- County-year CRA regressions ---")
cra_results = run_models(
    county_panel, "cra_growth",
    "{outcome} ~ share_deps_closed + log_n_branches + log_n_banks | county + state_yr",
    ["share_deps_closed","log_n_branches","log_n_banks","county","state_yr"],
    county_periods, ("CRV1","county")
)

# ── 10. Print text tables ──────────────────────────────────────────────────

def extract_models(results_dict):
    hdrs   = [pl for pl in period_labels if results_dict.get(pl) is not None]
    models = [results_dict[pl] for pl in period_labels if results_dict.get(pl) is not None]
    return hdrs, models

for title, fe_note, se_note, results_dict in [
    ("Incumbent Deposit Growth — Zip-Year",
     "zip + county×year", "clustered at zip", zip_results),
    ("Incumbent Deposit Growth — County-Year",
     "county + state×year", "clustered at county", county_dep_results),
    ("HMDA Mortgage Growth — County-Year (incumbent banks)",
     "county + state×year", "clustered at county", hmda_results),
    ("CRA Small-Business Lending Growth — County-Year (incumbent banks)",
     "county + state×year", "clustered at county", cra_results),
]:
    hdrs, models = extract_models(results_dict)
    if not models:
        print(f"\n[{title}]: no results")
        continue
    print_text_table(title, fe_note, se_note, coef_vars, var_labels, hdrs, models)
