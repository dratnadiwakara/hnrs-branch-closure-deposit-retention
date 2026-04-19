"""
Bank-county-year panel regressions and Sun & Abraham event study.

Replicates sections 1.1 and 1.2 from:
  https://dratnadiwakara.github.io/HNRS-Deposit-Reallocation/results/
  bank_county_year_sunab_and_panel_results_summary_20260306.html

Section 1.1 — Panel regressions
  Source: code/v20260418/result-generation/bank_county_year_regression_20260409.qmd
  Unit:   bank–county–year
  DV:     growth_on_total_t1  (1-yr deposit growth at remaining branches)
  Treat:  closure_share       (own closing deposits / total bank-county deposits)
  FE:     bank_id×YEAR + county×YEAR
  SE:     clustered at bank_id
  Periods: All | Pre-2012 | 2012-2024 | 2012-2019

Section 1.2 — Sun & Abraham event study (consistent branch set)
  Source: code/v20260418/result-generation/bank_county_year_sunab_20260409.qmd
  Unit:   bank–county–year
  DV:     log1p(deps_consistent)
  Method: Sun & Abraham (2021), ref = -1
  FE:     unit_id + YEAR
  SE:     clustered at bank_id
  Periods: Pre-2012 | 2012-2019 | 2020-2024 (superimposed)
"""

import sys, os, glob
sys.path.insert(0, "code/approach-python-baseline")

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import pyfixest as pf
from common import load_rds, stars, OUTPUT_DIR

# ── Config ───────────────────────────────────────────────────────────────────

DATA_PATH    = "data"
SAVE_FIGURES = True
save_dir     = f"{OUTPUT_DIR}/bank_county_year"
os.makedirs(save_dir, exist_ok=True)

PRIMARY_BLUE = "#012169"
PERIOD_COLORS = {
    "Pre 2012":  "#1b9e77",
    "2012-2019": "#d95f02",
    "2020-2024": "#7570b3",
}

# ── Helpers ───────────────────────────────────────────────────────────────────

def latest_file(folder, glob_pat):
    """Return most recently modified file matching glob pattern."""
    files = glob.glob(os.path.join(folder, glob_pat))
    if not files:
        raise FileNotFoundError(f"No file matching '{glob_pat}' in {folder}")
    return max(files, key=os.path.getmtime)


def print_reg_table(models_with_labels, coef_vars, var_labels, title, subtitle=""):
    header_labels = [lbl for lbl, m in models_with_labels if m is not None]
    valid_models  = [m   for lbl, m in models_with_labels if m is not None]
    W, LW = 90, 32
    col_w = max(14, (W - LW) // max(len(valid_models), 1))
    print(f"\n{'=' * W}")
    print(title)
    if subtitle:
        print(subtitle)
    print("=" * W)
    print(f"{'':>{LW}s}" + "".join(f"{h:>{col_w}s}" for h in header_labels))
    print("-" * W)
    for var, lbl in zip(coef_vars, var_labels):
        coef_row = f"{lbl:{LW}s}"
        se_row   = f"{'':>{LW}s}"
        for m in valid_models:
            try:
                c = m.coef()[var]; s = m.se()[var]; p = m.pvalue()[var]
                coef_row += f"{c:>+{col_w-1}.4f}{stars(p):1s}"
                se_row   += f"{'(' + f'{s:.4f}' + ')':>{col_w}s}"
            except KeyError:
                coef_row += f"{'—':>{col_w}s}"; se_row += f"{'':>{col_w}s}"
        print(coef_row)
        print(se_row)
    print("-" * W)
    n_row = f"{'N':{LW}s}"
    for m in valid_models:
        try:    n_row += f"{int(m._N):>{col_w},}"
        except: n_row += f"{'—':>{col_w}s}"
    print(n_row)
    print("=" * W)


def add_ref_point(es_dt, ref=-1):
    """Add the reference period (estimate=0) for each period."""
    refs = []
    for period in es_dt["period"].unique():
        refs.append({"period": period, "event_time": ref, "estimate": 0.0, "se": 0.0})
    return (pd.concat([es_dt, pd.DataFrame(refs)], ignore_index=True)
              .sort_values(["period", "event_time"])
              .reset_index(drop=True))


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1.1 — Panel regressions: closure_share → growth_on_total_t1
# ═══════════════════════════════════════════════════════════════════════════════

print("\n" + "=" * 70)
print("SECTION 1.1 — Bank-County-Year Panel Regressions")
print("=" * 70)

# Load reg_main
reg_path = latest_file(DATA_PATH, "reg_main_*.rds")
print(f"Loading: {os.path.basename(reg_path)}")
reg = load_rds(reg_path)
print(f"  shape: {reg.shape}")
print(f"  columns: {reg.columns.tolist()}")

# Type coercions
reg["bank_id"] = reg["bank_id"].astype(str)
reg["county"]  = reg["county"].astype(str).str.zfill(5)
reg["YEAR"]    = reg["YEAR"].astype(int)

# Log transforms (mirrors R's inline log1p() in formula)
reg["log1p_total_deps_bank_county_t1"] = np.log1p(reg["total_deps_bank_county_t1"])
reg["log1p_n_remaining_branches"]      = np.log1p(reg["n_remaining_branches"])

print(f"\n  YEAR range: {reg['YEAR'].min()} – {reg['YEAR'].max()}")
print(f"  closure_share > 0: {(reg['closure_share'] > 0).mean():.2%} of obs")

# Formula — same spec as R:
#   growth_on_total_t1 ~ closure_share + log1p(total_deps_bank_county_t1)
#                      + log1p(n_remaining_branches) + mkt_share_county_t1
#                      | bank_id^YEAR + county^YEAR
CONTROLS = ("log1p_total_deps_bank_county_t1 + "
            "log1p_n_remaining_branches + "
            "mkt_share_county_t1")
FML_11 = f"growth_on_total_t1 ~ closure_share + {CONTROLS} | bank_id^YEAR + county^YEAR"

COEF_VARS_11 = ["closure_share",
                "log1p_total_deps_bank_county_t1",
                "log1p_n_remaining_branches",
                "mkt_share_county_t1"]
COEF_LBLS_11 = ["closure_share",
                "log1p(total_deps_bank_county_t1)",
                "log1p(n_remaining_branches)",
                "mkt_share_county_t1"]

KEEP_COLS_11 = (["growth_on_total_t1", "closure_share",
                  "log1p_total_deps_bank_county_t1",
                  "log1p_n_remaining_branches", "mkt_share_county_t1",
                  "bank_id", "county", "YEAR"])

period_specs = [
    ("All",       reg),
    ("Pre 2012",  reg[reg["YEAR"] < 2012]),
    ("2012-2024", reg[reg["YEAR"] >= 2012]),
    ("2012-2019", reg[reg["YEAR"].between(2012, 2019)]),
]

models_11 = []
for lbl, df in period_specs:
    sub = df[KEEP_COLS_11].dropna()
    print(f"\nRunning {lbl}  (N={len(sub):,})...")
    try:
        fit = pf.feols(FML_11, data=sub, vcov={"CRV1": "bank_id"},
                       fixef_maxiter=500000, fixef_tol=1e-5)
        models_11.append((lbl, fit))
        c = fit.coef()["closure_share"]
        s = fit.se()["closure_share"]
        p = fit.pvalue()["closure_share"]
        print(f"  closure_share: {c:+.4f}  se={s:.4f}  {stars(p)}")
    except Exception as e:
        print(f"  ERROR: {e}")
        models_11.append((lbl, None))

print_reg_table(
    models_11, COEF_VARS_11, COEF_LBLS_11,
    title  = "Table 1.1 — Closure intensity and deposit growth at remaining branches",
    subtitle = "FE: bank_id×YEAR + county×YEAR | SE clustered at bank_id",
)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1.2 — Sun & Abraham event study (consistent branch set)
# ═══════════════════════════════════════════════════════════════════════════════

print("\n" + "=" * 70)
print("SECTION 1.2 — Sun & Abraham Event Study (Consistent Branch Set)")
print("=" * 70)

# Load sunab_panel_consistent
cons_path = latest_file(DATA_PATH, "sunab_panel_consistent_*.rds")
print(f"Loading: {os.path.basename(cons_path)}")
cons = load_rds(cons_path)
print(f"  shape: {cons.shape}")
print(f"  columns: {cons.columns.tolist()}")

cons["bank_id"] = cons["bank_id"].astype(str)
cons["unit_id"] = cons["unit_id"].astype(str)
cons["YEAR"]    = cons["YEAR"].astype(int)
cons["cohort"]  = cons["cohort"].astype(int)

# Never-treated: R uses cohort=10000; pyfixest needs 0
if (cons["cohort"] == 10000).any():
    cons.loc[cons["cohort"] == 10000, "cohort"] = 0

cons["log1p_deps_consistent"] = np.log1p(cons["deps_consistent"].astype(float))

# Period subsets mirror R: sunab_panel_consistent[YEAR < 2012], etc.
period_subsets = [
    ("Pre 2012",  cons[cons["YEAR"] < 2012]),
    ("2012-2019", cons[cons["YEAR"].between(2012, 2019)]),
    ("2020-2024", cons[cons["YEAR"] >= 2020]),
]

# ── Run Sun & Abraham via pyfixest.event_study (saturated = SA 2021) ─────────
# att=False returns event-time path (leads + lags); aggregate() applies SA weights

es_parts = []
for lbl, df in period_subsets:
    sub = df[["log1p_deps_consistent", "cohort", "YEAR", "unit_id", "bank_id"]].dropna()
    print(f"\nRunning Sun & Abraham: {lbl}  (N={len(sub):,})...")
    try:
        fit = pf.event_study(
            sub,
            yname="log1p_deps_consistent",
            idname="unit_id",
            tname="YEAR",
            gname="cohort",
            cluster="bank_id",
            estimator="saturated",
            att=False,
        )
        agg = fit.aggregate()
        tidy = (agg.reset_index()
                   .rename(columns={"period": "event_time",
                                    "Estimate": "estimate",
                                    "Std. Error": "se"})
                   [["event_time", "estimate", "se"]])
        tidy["event_time"] = tidy["event_time"].astype(float).astype(int)
        tidy["period"] = lbl
        es_parts.append(tidy)
        pre  = tidy[tidy["event_time"] < -1]
        post = tidy[tidy["event_time"] > 0]
        print(f"  Pre-trend periods: {sorted(pre['event_time'].tolist())}  "
              f"max |pre|={pre['estimate'].abs().max():.4f}")
        print(f"  Post-event periods: {sorted(post['event_time'].tolist())}  "
              f"avg coef={post['estimate'].mean():.4f}")
    except Exception as e:
        print(f"  ERROR: {e}")

if not es_parts:
    print("\nNo event-study results to plot.")
    sys.exit(0)

es_cons = pd.concat(es_parts, ignore_index=True)
es_cons = add_ref_point(es_cons, ref=-1)

print("\nEvent-study coefficients (consistent branch set):")
print(es_cons.to_string(index=False))

# ── Plot ──────────────────────────────────────────────────────────────────────

fig, ax = plt.subplots(figsize=(9, 6))
ax.axhline(0, linestyle="--", color="gray", linewidth=0.8)
ax.axvline(-0.5, linestyle=":", color="gray", linewidth=0.6, alpha=0.5)

for period, color in PERIOD_COLORS.items():
    df_p = es_cons[es_cons["period"] == period].sort_values("event_time")
    if df_p.empty:
        continue
    et  = df_p["event_time"].to_numpy(dtype=float)
    est = df_p["estimate"].to_numpy(dtype=float)
    se  = df_p["se"].to_numpy(dtype=float)
    ax.plot(et, est, color=color, linewidth=1.2, label=period,
            marker="o", markersize=4, zorder=3)
    ax.fill_between(et, est - 1.96 * se, est + 1.96 * se,
                    alpha=0.15, color=color)
    ax.errorbar(et, est, yerr=1.96 * se,
                fmt="none", ecolor=color, elinewidth=0.6, capsize=3, alpha=0.6)

ax.set_xlabel("Years Relative to First Closure", fontsize=11)
ax.set_ylabel("Event-time effect (log deposits, consistent branch set)", fontsize=10)
ax.set_title("Figure 1.2 — Sun & Abraham Event Study: Consistent Branch Deposits by Period",
             color=PRIMARY_BLUE, fontweight="bold", fontsize=11)
ax.legend(loc="best", framealpha=0.9, fontsize=10)
ax.grid(True, alpha=0.25, linestyle=":")
fig.tight_layout()

out_fig = os.path.join(save_dir, "sunab_consistent_branch_set.png")
fig.savefig(out_fig, dpi=150, bbox_inches="tight", facecolor="white")
plt.close(fig)
print(f"\nFigure saved: {out_fig}")
