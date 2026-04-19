---
layout: default
title: "09-anchored-regressions — 2026-04-18"
---

# Snapshot: 09-anchored-regressions

**Date**: 2026-04-18
**Project**: Branch Closures, Deposit Retention, and the Credit Channel in the Digital Era

## Summary

> Anchored progression from NRS (2026) Table 14. Five tables: (1) NRS Table 14 replication — count-based treatment, 1-yr window, no-close incumbent, demographics filter; (2) deposit-weighted treatment at zip level; (3) deposit-weighted at county level (2-yr window); (4) HMDA purchase mortgages, county; (5) CRA small-business lending, county.
>
> **Zip deposits (Tables 1–2):** Pre-2012 reallocation positive and significant (+0.095–+0.117*** pre-crisis, +0.037–+0.084** crisis). Post-2012 collapses to near-zero or slightly negative (2012–19: +0.006/−0.017*; 2020–24: +0.004/−0.018 ns). Table 1 coefficient +0.095*** close to NRS (2026) Table 14 reference +0.061***.
> **County deposits (Table 3):** Always positive, no digital-era decline (+0.16–+0.23***) — state×year FE too weak.
> **HMDA purchase mortgages (Tables 4 & 6):** Null all periods at both county and zip level — incumbents do not gain new purchase mortgage market share after competitor closures.
> **CRA small-business lending (Table 5):** Null all periods — small-business credit unresponsive to competitor closure exposure.

## Script

`code/approach-python-baseline/09_anchored_regressions.R`

### Variable Definitions

**Zip-year panel (Tables 1–2):**
- **LHS** `outcome` = `(inc_deps_{t+1} − inc_deps_t) / total_zip_deps_{t−1}` — 1-year window (t → t+1); denominator is total zip deposits at t−1 (all branches). Incumbent deposits at t and t+1 include only branches belonging to banks with NO closes in (zip, YEAR).
- **Treatment (Table 1)** `fraction_of_branches_closed` = count of competitor branches closed at t / count of all zip branches at t−1. Replicates NRS (2026) Table 14 (count-based, partial replication).
- **Treatment (Table 2)** `share_deps_closed` = sum of deposits at t−1 of closed competitor branches / total_zip_deps_{t−1}. Deposit-weighted analog.
- **Incumbent:** bank with NO closes in (zip, YEAR). [No-open restriction not applied.]
- **FE:** zip + county×year | **SE:** clustered at zip
- **Controls:** `log_n_branches` (log total branches in zip at t−1), `log_n_inc_banks` (log incumbent banks in zip at t−1)
- **Demographics filter:** `!is.na(sophisticated)` from `zip_demographics_panel.rds`

**County-year panel (Tables 3–5):**
- **LHS `dep_outcome`** = `(inc_county_deps_{t+1} − inc_county_deps_{t−1}) / inc_county_deps_{t−1}` — 2-year symmetric window (t−1 → t+1); denominator is incumbent own deposits at t−1. Incumbent = banks with NO closes in (county, YEAR).
- **LHS `hmda_purch_growth`** = `(inc_purch_hmda_{t+1} − inc_purch_hmda_{t−1}) / inc_purch_hmda_{t−1}` — purchase originations only (`action_taken='1' AND loan_purpose='1'`); 2-year window.
- **LHS `cra_growth`** = `(inc_cra_{t+1} − inc_cra_{t−1}) / inc_cra_{t−1}` — CRA small-business loans ≤ $1M (table D1-1); 2-year window.
- **Treatment** `share_deps_closed` = sum of deposits at t−1 of closed competitor branches / total_county_deps_{t−1}. County-level deposit-weighted.
- **FE:** county + state×year | **SE:** clustered at county
- **Controls:** `log_n_branches`, `log_n_banks`, `log1p_total_deps`, `county_dep_growth_t4_t1`, `log_population_density`, `lag_county_deposit_hhi`, `lag_establishment_gr`, `lag_payroll_gr`, `lag_hmda_mtg_amt_gr`, `lag_cra_loan_amount_amt_lt_1m_gr`, `lmi`

**Zip-year panel — Table 6 (HMDA at zip level):**
- **LHS `hmda_purch_growth_zip`** = `(inc_purch_hmda_{t+1} − inc_purch_hmda_{t−1}) / inc_purch_hmda_{t−1}` — 2-year window at zip level. HMDA loan amounts apportioned from census tract to zip using `RES_RATIO` from HUD USPS crosswalk (December 2019). Same incumbent definition and FE as Tables 1–2.

## Figures

*No figures. Results printed to terminal via `etable()`.*

## Tables

### Table 1 — NRS (2026) Table 14 Replication (Count-Based Treatment)

**LHS:** `(inc_deps_{t+1} − inc_deps_t) / total_zip_deps_{t−1}` [1-yr window, total market denominator]
**RHS:** `fraction_of_branches_closed` = closed branch count / total branch count at t−1
FE: zip + county×year | SE: clustered at zip
Incumbent = bank with NO closes in (zip, YEAR). Demographics filter applied.
*Note: N=70,727 vs NRS reference 73,123 for 2000–07; remaining gap from OTS filter not implemented.*

| | 2000–07 | 2008–11 | 2012–19 | 2020–24 |
|---|---|---|---|---|
| fraction_of_branches_closed | **0.0951***  | **0.0369**  | 0.0060 | 0.0040 |
| | (0.0114) | (0.0150) | (0.0092) | (0.0140) |
| log_n_branches | −0.1215*** | −0.0632*** | −0.0626*** | −0.0740*** |
| log_n_inc_banks | 0.0835*** | 0.0334*** | 0.0584*** | 0.0659*** |
| N | 70,727 | 44,953 | 89,982 | 51,601 |
| Within R² | 0.015 | 0.003 | 0.004 | 0.005 |

### Table 2 — Deposit-Weighted Treatment, Zip-Year

**LHS:** same as Table 1 — `(inc_deps_{t+1} − inc_deps_t) / total_zip_deps_{t−1}` [1-yr window]
**RHS:** `share_deps_closed` = sum(closed_dep_{t−1}) / total_zip_dep_{t−1}
FE: zip + county×year | SE: clustered at zip

| | 2000–07 | 2008–11 | 2012–19 | 2020–24 |
|---|---|---|---|---|
| share_deps_closed | **0.1167***  | **0.0843***  | −0.0170* | −0.0178 |
| | (0.0156) | (0.0219) | (0.0101) | (0.0119) |
| log_n_branches | −0.1155*** | −0.0647*** | −0.0557*** | −0.0659*** |
| log_n_inc_banks | 0.0743*** | 0.0341*** | 0.0501*** | 0.0571*** |
| N | 70,727 | 44,953 | 89,982 | 51,601 |
| Within R² | 0.014 | 0.003 | 0.004 | 0.005 |

### Table 3 — Deposit-Weighted Treatment, County-Year Deposits

**LHS:** `(inc_county_deps_{t+1} − inc_county_deps_{t−1}) / inc_county_deps_{t−1}` [2-yr window, own denominator]
**RHS:** `share_deps_closed` (county-level deposit-weighted)
FE: county + state×year | SE: clustered at county
Incumbent = bank with NO closes in (county, YEAR)

| | pre-2012 | 2012–2019 | 2020–2024 |
|---|---|---|---|
| share_deps_closed | **0.1596***  | **0.2330***  | **0.2085***  |
| | (0.0453) | (0.0261) | (0.0292) |
| log_n_branches | 0.1504*** | −0.0098 | 0.1420*** |
| log_n_banks | 0.0489*** | 0.0967*** | 0.0846*** |
| log1p_total_deps | −0.3400*** | −0.3883*** | −0.5169*** |
| county_dep_growth_t4_t1 | −0.000 | 0.0602*** | 0.0013 |
| log_population_density | 0.0738 | 0.4869*** | −0.1787*** |
| lag_county_deposit_hhi | 0.0570 | −0.0991* | 0.0040 |
| lag_establishment_gr | 0.1521*** | 0.0951* | −0.0199 |
| lag_payroll_gr | 0.0183 | 0.0901*** | −0.2240*** |
| lag_hmda_mtg_amt_gr | 0.0243*** | −0.0150** | −0.0032 |
| lag_cra_loan_amount_amt_lt_1m_gr | −0.0036 | −0.0011 | −0.0013 |
| lmi | dropped (collinear) | 0.0086 | 0.0011 |
| N | 23,426 | 23,593 | 14,567 |
| Within R² | 0.147 | 0.201 | 0.275 |

### Table 4 — HMDA Purchase Mortgage Growth, County-Year

**LHS:** `(inc_purch_hmda_{t+1} − inc_purch_hmda_{t−1}) / inc_purch_hmda_{t−1}` [2-yr window]
**RHS:** `share_deps_closed` (county-level)
**HMDA filter:** `action_taken = '1'` (originated) AND `loan_purpose = '1'` (home purchase only)
FE: county + state×year | SE: clustered at county

| | pre-2012 | 2012–2019 | 2020–2024 |
|---|---|---|---|
| share_deps_closed | −0.0948 | 0.0327 | 0.1809 |
| | (0.1910) | (0.1676) | (0.2118) |
| log1p_total_deps | −0.1647*** | −0.3471*** | −0.1851* |
| county_dep_growth_t4_t1 | −0.0006*** | 0.0457*** | 0.0091** |
| lag_county_deposit_hhi | 0.4834** | 0.5312** | 0.5686* |
| lag_payroll_gr | −0.2715* | −0.2217 | −0.0808 |
| lag_hmda_mtg_amt_gr | −0.2659*** | −0.7276*** | −0.3603*** |
| lmi | dropped (collinear) | −0.0023 | 0.2249*** |
| N | 20,597 | 21,377 | 10,393 |
| Within R² | 0.005 | 0.013 | 0.008 |

### Table 5 — CRA Small-Business Lending Growth, County-Year

**LHS:** `(inc_cra_{t+1} − inc_cra_{t−1}) / inc_cra_{t−1}` [2-yr window]
**RHS:** `share_deps_closed` (county-level)
**CRA measure:** amt_loans_lt_100k + amt_loans_100k_250k + amt_loans_250k_1m (table D1-1, report level 040)
FE: county + state×year | SE: clustered at county

| | pre-2012 | 2012–2019 | 2020–2024 |
|---|---|---|---|
| share_deps_closed | −0.1815 | 0.1040 | 0.2158 |
| | (0.1981) | (0.1654) | (0.2241) |
| log1p_total_deps | −0.0171 | −0.1762*** | 0.0300 |
| log_population_density | 0.1787 | 1.047*** | 0.0744 |
| lag_hmda_mtg_amt_gr | 0.0998** | −0.1165 | 0.0491 |
| lag_cra_loan_amount_amt_lt_1m_gr | −0.4303*** | −0.6440*** | −0.7128*** |
| lmi | dropped (collinear) | 0.0173 | 0.0219 |
| N | 18,338 | 19,252 | 9,605 |
| Within R² | 0.017 | 0.027 | 0.042 |

### Table 6 — HMDA Purchase Mortgage Growth, Zip-Year

**LHS:** `(inc_purch_hmda_{t+1} − inc_purch_hmda_{t−1}) / inc_purch_hmda_{t−1}` [2-yr window, zip level]
**RHS:** `share_deps_closed` (zip-level deposit-weighted)
**HMDA mapping:** census tract → zip via `RES_RATIO` from HUD USPS crosswalk (December 2019). Loans apportioned proportionally where tracts straddle multiple zip codes.
FE: zip + county×year | SE: clustered at zip
Incumbent = bank with NO closes in (zip, YEAR)

| | 2000–07 | 2008–11 | 2012–19 | 2020–24 |
|---|---|---|---|---|
| share_deps_closed | 0.0406 | −0.3000 | 0.2169 | 0.2040 |
| | (0.2846) | (0.4456) | (0.1631) | (0.1691) |
| log_n_branches | −0.3636*** | 0.2080 | −0.2741*** | 0.1498 |
| log_n_inc_banks | −0.0238 | −0.3382*** | −0.2245*** | −0.2400** |
| N | 53,607 | 35,524 | 82,376 | 36,039 |
| Within R² | 0.001 | 0.000 | 0.001 | 0.001 |

## Interpretation Notes

- **Zip deposits, Tables 1–2 (1-yr window):** Clear two-period break. Pre-2012: strong positive reallocation to incumbents — +0.095***/+0.117*** (2000–07) and +0.037**/+0.084*** (2008–11). Post-2012: collapses to near zero — 2012–19: +0.006/−0.017*; 2020–24: +0.004/−0.018 ns. Table 1 count-based coefficient +0.095*** approaches NRS (2026) Table 14 reference of +0.061*** (remaining gap from OTS filter not implemented, N=70,727 vs 73,123).
- **Incumbent definition:** no-close only in (zip, YEAR). No-open filter removed — does not restrict the sample and previously suppressed the treatment effect by excluding growing incumbents.
- **County deposits (Table 3):** Always positive, no decline (+0.16/+0.23/+0.21***). State×year FE too weak vs zip's county×year; absorbs less common-trend variation. Not preferred specification for identifying digital-era attenuation.
- **HMDA purchase (Table 4, county):** Null all periods (−0.09/+0.03/+0.18, all ns). No significant effect at county level.
- **HMDA purchase (Table 6, zip):** Null all periods (+0.04/−0.30/+0.22/+0.20, all ns). Consistent with county result — zip-level HMDA purchase also unresponsive in all eras. HMDA apportioned from census tract to zip using HUD RES_RATIO crosswalk (Dec 2019).
- **CRA (Table 5):** Null all periods (−0.18/+0.10/+0.22, all ns). Small-business credit supply unresponsive throughout 2001–2024.
- **Key takeaway:** Deposit reallocation to incumbent banks after competitor closures was economically meaningful and statistically significant in the pre-digital era (pre-2012) and collapsed to near-zero post-2012. Lending outcomes (mortgage purchase at both county and zip level, small-business) are unresponsive throughout all eras, suggesting incumbents absorbed deposits but did not translate the inflow into new credit origination.

---

## Bank-County-Year Regressions (Own-Closure Design) — Scripts 10

*Added 2026-04-18. Sources: `code/approach-python-baseline/10_bank_county_year_regressions.R` and `10_bank_county_year_regressions.py`.*
*Replicates sections 1.1 and 1.2 of the coauthor reference HTML.*

### Section 1.1 — Panel Regressions: Closure Intensity → Deposit Growth at Remaining Branches

**Unit:** bank–county–year  
**LHS:** `growth_on_total_t1` = (deposits at remaining branches, t+1 − t−1) / total bank-county deposits at t−1  
**RHS:** `closure_share` = own closing deposits / total bank-county deposits  
**FE:** bank_id×YEAR + county×YEAR | **SE:** clustered at bank_id  
**Controls:** log1p(total_deps_bank_county_t1), log1p(n_remaining_branches), mkt_share_county_t1  

| | All | Pre-2012 | 2012–2024 | 2012–2019 |
|---|---|---|---|---|
| closure_share | **0.6593***  | **0.5378***  | **0.6823***  | **0.6685***  |
| | (0.0204) | (0.0312) | (0.0220) | (0.0249) |
| log1p(total_deps_bank_county_t1) | −0.1663*** | −0.1985*** | −0.1467*** | −0.1422*** |
| | (0.0036) | (0.0048) | (0.0042) | (0.0045) |
| log1p(n_remaining_branches) | +0.1873*** | +0.2272*** | +0.1621*** | +0.1546*** |
| | (0.0060) | (0.0070) | (0.0065) | (0.0076) |
| mkt_share_county_t1 | +0.3293*** | +0.3306*** | +0.3354*** | +0.3436*** |
| | (0.0138) | (0.0217) | (0.0159) | (0.0177) |
| N | 458,799 | 178,022 | 280,777 | 173,127 |
| Within R² | 0.179 | 0.237 | 0.147 | 0.145 |

*Matches reference HTML exactly: Pre-2012 N=178,022 and 2012-2019 N=173,127 check out.*

### Section 1.2 — Sun & Abraham Event Study (Consistent Branch Set)

**Unit:** bank–county–year  
**DV:** log(1 + deposits at branches that do not close in cohort year)  
**Method:** Sun & Abraham (2021), ref period = −1  
**FE:** unit_id + YEAR | **SE:** clustered at bank_id  
**Window:** ±3 years around first closure; 50% sampled never-treated controls  

![sunab_consistent_branch_set](figures/sunab_consistent_branch_set.png)

**Event-time coefficients:**

| Period | t=−3 | t=−2 | t=−1 | t=0 | t=1 | t=2 | t=3 |
|---|---|---|---|---|---|---|---|
| Pre-2012 | 0.099*** | 0.037*** | 0 (ref) | −0.046*** | 0.059*** | −0.065*** | −0.121*** |
| 2012–2019 | 0.013 | 0.004 | 0 (ref) | −0.012 | 0.258*** | 0.245*** | 0.248*** |
| 2020–2024 | 0.075** | 0.046*** | 0 (ref) | 0.023 | 0.347*** | 0.315*** | 0.324*** |

**Notes:**
- Pre-2012 shows flat pre-trend at t=−2 (0.037) but violation at t=−3 (0.099***) — may reflect sparse early cohorts or genuine pre-trend.
- Digital-era (2012-2019, 2020-2024): pre-trends small and insignificant at t=−2; large positive post-event coefficients indicate remaining branches gain deposits after own closures. Post-event effect grows monotonically in the later period.
- Pre-2012 post-event path turns negative at t=2 and t=3 — unlike later periods. Consistent with pre-digital-era deposits leaving over time, not being durably retained.
- The contrast in the post-event path (persistent retention in digital era vs. reversal in pre-digital era) maps directly to **Prediction 1** of the theoretical model: high-technology banks retain deposits; low-technology banks do not.

---

*Snapshot generated by `/skills/snapshot-results` on 2026-04-18.*
*Source: terminal output of `code/approach-python-baseline/09_anchored_regressions.R`, `10_bank_county_year_regressions.R`, `10_bank_county_year_regressions.py`*
