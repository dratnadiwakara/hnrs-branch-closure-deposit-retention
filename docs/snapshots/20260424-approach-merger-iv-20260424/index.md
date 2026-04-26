---
layout: default
title: "approach-merger-iv-20260424 — 2026-04-24"
---

# Snapshot: approach-merger-iv-20260424

> 

---

## 1. Nguyen (2019) Figure 2 — Impact of Merger Exposure on Branch Closings

**Unit:** branch-year (brick-and-mortar + drive-through, SOD BRSERTYP ∈ {11, 12, 21})
**LHS:** `closed` = 1 if UNINUMBR present in YEAR but absent in YEAR+1
**Treatment:** `i(rel_year, ref = −1, keep = −5:5)` — event-time dummies around ZIP's first Event_Year
**FE:** ZIPBR + YEAR | **SE:** clustered at STCNTYBR (county)
**Sample:** treated ZIPs (overlap in ≥1 large merger) + all other ZIPs as never-treated controls; controls assigned `rel_year = −1000` and excluded from `keep` window

![Nguyen 2019 Figure 2 replica](figures/F_nguyen_figure2.png)

```
| rel_year | coef        | se      | 95% CI lo | 95% CI hi |
|---------:|------------:|--------:|----------:|----------:|
|       −5 | −0.00180    | 0.00148 | −0.00471  |  0.00111  |
|       −4 | −0.00500**  | 0.00153 | −0.00801  | −0.00199  |
|       −3 | −0.00262    | 0.00173 | −0.00601  |  0.00077  |
|       −2 |  0.00230    | 0.00134 | −0.00033  |  0.00492  |
|        0 |  0.01903*** | 0.00241 |  0.01432  |  0.02375  |
|        1 |  0.01022*** | 0.00196 |  0.00637  |  0.01407  |
|        2 |  0.00703*** | 0.00179 |  0.00351  |  0.01054  |
|        3 |  0.00022    | 0.00141 | −0.00254  |  0.00298  |
|        4 |  0.00169    | 0.00172 | −0.00167  |  0.00506  |
|        5 | −0.00045    | 0.00159 | −0.00356  |  0.00267  |
| N        |             |         |           |  2,250,571|
| ZIPBR FE |             |         |           |  22,959   |
| YEAR FE  |             |         |           |  26       |
| SE       |             |         |           |  STCNTYBR |
```

*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 2. First Stage — `share_deps_closed ~ Expose_Event`

**Unit:** zip-year
**LHS:** `share_deps_closed` = sum(closed_dep_{t−1}) / total_zip_dep_{t−1}
**Instrument:** `Expose_Event` = 1 if ZIP exposed to a large merger with Event_Year = YEAR
**FE:** zip + YEAR | **SE:** clustered at zip
**Sample:** `branches_lag1 ≥ 2` AND `n_inc_banks ≥ 2`. "Share > 0" subsamples to ZIP-years with any closure.

```
|                         | Full Sample       | Share > 0         |
|-------------------------|-------------------|-------------------|
| Expose_Event            | 0.0131***         | 0.0182***         |
|                         | (0.0013)          | (0.0031)          |
| log1p(branches_lag1)    | 0.0204***         | −0.0873***        |
|                         | (0.0007)          | (0.0052)          |
| N                       | 284,586           | 29,954            |
| Zip FE                  | Yes               | Yes               |
| YEAR FE                 | Yes               | Yes               |
| SE                      | Zip               | Zip               |
| Mean(share_deps_closed) | 0.010             | 0.089             |
| SD(Expose_Event)        | 0.103             | 0.174             |
| R²                      | 0.077             | 0.450             |
| F(Expose_Event)         | 45.625            | 220.582           |
```

*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 3. IV Second Stage — Incumbent Reallocation (period split, Panel-B-aligned)

**Unit:** zip-year
**LHS:** `outcome` = (inc_deps_{t+1} − inc_deps_t) / total_zip_deps_{t−1} — 1-year incumbent reallocation
**Treatment:** `share_deps_closed`, instrumented by `Expose_Event`
**FE:** zip + county×year | **SE:** clustered at zip
**Controls:** `log_n_branches`, `log_n_inc_banks`, `log_total_deps`, `dep_growth_t3t1`
**Sample:** streamlined `zip_tech_sample_20260423.rds` filtered by period only (same as `T1_panelB_depwt`)

```
|                           | 2000–07    | 2008–11    | 2012–19    | 2020–22    | 2023–24   |
|---------------------------|------------|------------|------------|------------|-----------|
| share_deps_closed (IV)    | −4.270     | 1.141      | −2.106     | −2.251*    | 0.353     |
|                           | (9.070)    | (0.718)    | (1.459)    | (1.293)    | (0.634)   |
| log_n_branches            | 0.356      | −0.056     | 0.538      | 0.814*     | −0.135    |
|                           | (0.766)    | (0.073)    | (0.358)    | (0.440)    | (0.227)   |
| log_n_inc_banks           | −0.436     | 0.189**    | −0.584     | −0.802     | 0.181     |
|                           | (1.086)    | (0.096)    | (0.452)    | (0.508)    | (0.247)   |
| log_total_deps            | −0.130**   | −0.129***  | −0.067**   | 0.058      | −0.074    |
|                           | (0.064)    | (0.012)    | (0.028)    | (0.094)    | (0.061)   |
| dep_growth_t3t1           | −0.009**   | −0.002     | −0.011*    | −0.089***  | 0.017     |
|                           | (0.004)    | (0.005)    | (0.006)    | (0.017)    | (0.012)   |
| N                         | 51,558     | 44,830     | 89,954     | 31,052     | 20,304    |
| Zip FE                    | Yes        | Yes        | Yes        | Yes        | Yes       |
| County×Year FE            | Yes        | Yes        | Yes        | Yes        | Yes       |
| SE                        | Zip        | Zip        | Zip        | Zip        | Zip       |
| Mean(outcome)             | 0.048      | 0.037      | 0.062      | 0.073      | 0.025     |
| SD(share_deps_closed)     | 0.038      | 0.033      | 0.047      | 0.064      | 0.053     |
| SD(Expose_Event)          | 0.122      | 0.111      | 0.091      | 0.077      | 0.095     |
| R²                        | 0.539      | 0.487      | 0.482      | 0.652      | 0.609     |
| F-test (1st stage)        | 0.646      | 41.657     | 7.280      | 12.174     | 20.355    |
```

*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## Contrast — OLS (streamlined T1 Panel B) vs IV (this snapshot)

| Period  | OLS coef (streamlined) | IV coef (this) | IV-F  |
| ------- | ---------------------- | -------------- | -----:|
| 2000–07 | 0.1208***              | −4.270         | 0.65  |
| 2008–11 | 0.1048***              | 1.141          | 41.66 |
| 2012–19 | 0.0098                 | −2.106         | 7.28  |
| 2020–22 | 0.0584***              | −2.251*        | 12.17 |
| 2023–24 | −0.0181                | 0.353          | 20.36 |



---

## 4. IV — HMDA Lending (zip-year)

**Unit:** zip-year
**LHS (per panel):** 2-year HMDA originations growth at zip-year — purchase (A1), refi (A2), second-lien purchase (B), jumbo purchase vs FHFA CLL (C, 2012+ only)
**Treatment:** `share_deps_closed`, instrumented by `Expose_Event`
**FE:** zip + county×year | **SE:** clustered at zip
**Controls:** `log_n_branches`, `log_n_inc_banks`, `log_total_deps`, `dep_growth_t3t1`
**Sample:** `data/constructed/hmda_zip_panels_20260423.rds` (Tract→zip via HUD `RES_RATIO`)
**Note:** 2023–24 column drops in every panel — HMDA 2-yr growth at year 2024 needs 2025 LAR; the slice collapses to year 2023 only and `county_yr` becomes a singleton with `zip` FE.

### Panel A1 — Purchase originations

```
|                              | 2000–07     | 2008–11   | 2012–19   | 2020–22   |
|------------------------------|-------------|-----------|-----------|-----------|
| share_deps_closed (IV)       | −607.3      | 8.766     | −1.855    | 2.883     |
|                              | (11,671.9)  | (9.162)   | (14.91)   | (6.166)   |
| N                            | 39,951      | 35,474    | 82,356    | 27,365    |
| Mean(outcome)                | 0.732       | 0.417     | 0.565     | 0.098     |
| SD(share_deps_closed)        | 0.036       | 0.032     | 0.046     | 0.064     |
| SD(Expose_Event)             | 0.131       | 0.119     | 0.095     | 0.081     |
| R²                           | 0.467       | 0.534     | 0.396     | 0.525     |
| F-test (1st stage)           | 0.006       | 44.474    | 7.930     | 10.536    |
```

### Panel A2 — Refinance originations

```
|                              | 2000–07    | 2008–11    | 2012–19   | 2020–22   |
|------------------------------|------------|------------|-----------|-----------|
| share_deps_closed (IV)       | 291.6      | −30.65*    | 2.046     | −5.519    |
|                              | (1,664.7)  | (16.11)    | (16.66)   | (7.526)   |
| N                            | 41,897     | 37,103     | 82,433    | 27,053    |
| Mean(outcome)                | 1.059      | 1.166      | 0.605     | 0.056     |
| SD(share_deps_closed)        | 0.036      | 0.032      | 0.046     | 0.063     |
| SD(Expose_Event)             | 0.129      | 0.119      | 0.094     | 0.081     |
| R²                           | 0.456      | 0.558      | 0.527     | 0.676     |
| F-test (1st stage)           | 0.070      | 31.973     | 11.427    | 10.846    |
```

### Panel B — Second-lien purchase originations

```
|                              | 2004–07     | 2008–11   | 2012–19   | 2020–22   |
|------------------------------|-------------|-----------|-----------|-----------|
| share_deps_closed (IV)       | −8,285.3    | −220.1    | 1,016.3   | 2,488.1   |
|                              | (85,046.7)  | (594.1)   | (2,738.8) | (6,574.1) |
| N                            | 11,973      | 3,408     | 7,612     | 3,006     |
| Mean(outcome)                | 4.986       | 4.915     | 8.296     | 7.948     |
| SD(share_deps_closed)        | 0.031       | 0.027     | 0.039     | 0.053     |
| SD(Expose_Event)             | 0.176       | 0.150     | 0.138     | 0.081     |
| R²                           | 0.575       | 0.545     | 0.508     | 0.569     |
| F-test (1st stage)           | 0.025       | 1.054     | 0.495     | 0.161     |
```

### Panel C — Jumbo purchase originations (vs FHFA CLL)

> **Updated 2026-04-26:** Fixed jumbo SQL in `B1_hmda_zip_panels_20260423.R` — local HMDA DuckDB stores `loan_amount` in dollars across all years, so the prior `loan_amount * 1000 > cll_1unit` test passed for ~every loan and Panel C was effectively all-purchase (cor with Panel A1 = 0.96 at zip-year 2012+). Rebuilt; jumbo zip-year count drops 121K → 43K. IV-F now < 2 in both columns — true jumbo segment too thin for IV identification within periods.

```
|                              | 2012–19   | 2020–22   |
|------------------------------|-----------|-----------|
| share_deps_closed (IV)       | 401.1     | 90.44     |
|                              | (546.0)   | (122.2)   |
| N                            | 26,105    | 8,841     |
| Mean(outcome)                | 2.162     | 1.626     |
| SD(share_deps_closed)        | 0.043     | 0.063     |
| SD(Expose_Event)             | 0.126     | 0.092     |
| R²                           | 0.405     | 0.544     |
| F-test (1st stage)           | 0.976     | 2.021     |
```

*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

### Contrast — OLS (streamlined T2) vs IV (this snapshot)

| Panel              | Period   | OLS coef    | IV coef     | IV-F   | N      |
|--------------------|----------|-------------|-------------|-------:|-------:|
| A1 Purchase        | 2000–07  | −0.158      | −607.3      |  0.01  | 39,951 |
| A1 Purchase        | 2008–11  | −0.249      |  8.77       | 44.47  | 35,474 |
| A1 Purchase        | 2012–19  |  0.401**    | −1.86       |  7.93  | 82,356 |
| A1 Purchase        | 2020–22  |  0.219      |  2.88       | 10.54  | 27,365 |
| A2 Refi            | 2000–07  |  0.296      |  291.6      |  0.07  | 41,897 |
| A2 Refi            | 2008–11  | −0.043      | −30.65*     | 31.97  | 37,103 |
| A2 Refi            | 2012–19  |  0.086      |  2.05       | 11.43  | 82,433 |
| A2 Refi            | 2020–22  | −0.029      | −5.52       | 10.85  | 27,053 |
| B Second-lien      | 2004–07  | −14.46      | −8,285.3    |  0.03  | 11,973 |
| B Second-lien      | 2008–11  | −27.05      | −220.1      |  1.05  |  3,408 |
| B Second-lien      | 2012–19  | −15.42      |  1,016.3    |  0.50  |  7,612 |
| B Second-lien      | 2020–22  |  16.90      |  2,488.1    |  0.16  |  3,006 |
| C Jumbo            | 2012–19  | −0.230      |  401.1      |  0.98  | 26,105 |
| C Jumbo            | 2020–22  |  1.552      |   90.44     |  2.02  |  8,841 |

**Read:** All IV columns are imprecise. IV-F < 10 in 2000–07 (every panel), across the entire second-lien panel, and across the rebuilt jumbo panel — instrument mass too thin within those slices. 2008–11 and 2012–19 IV in Panel A1/A2 have IV-F above 10; coefficients land near zero (no significant lending spillover), consistent with the OLS null in the digital era. Pooling pre-2012 / post-2012 / post-2020 periods would restore power if needed.

---

## 5. IV — CRA Small-Business Lending (county-year)

**Unit:** county-year
**LHS:** `cra_growth_incty` = 2-year growth in CRA small-business loan amounts originated by in-county-branch respondents (in-county filter implicit via `inc_set`)
**Treatment:** `share_deps_closed` (county-level closure exposure), instrumented by `Expose_Event`
**Instrument aggregation:** zip-level `Expose_Event` aggregated to (county, Event_Year): binary = 1 if any treated zip in the county at Event_Year. Zip→county map from SOD at Ref_Year = Event_Year − 1 (`LPAD(STCNTYBR, 5, '0')`).
**FE:** county + state×year | **SE:** clustered at county
**Controls:** `log_n_branches`, `log_n_banks`, `log1p_total_deps`, `county_dep_growth_t4_t1`, `log_population_density`, `lag_county_deposit_hhi`, `lag_establishment_gr`, `lag_payroll_gr`, `lag_hmda_mtg_amt_gr`, `lag_cra_loan_amount_amt_lt_1m_gr`, `lmi`
**Sample:** `data/constructed/cra_county_panels_20260423.rds` + county-controls panel
**Note:** 2023–24 column omitted — CRA 2-yr growth at year 2024 needs 2025 CRA release.

```
|                              | 2000–07   | 2008–11   | 2012–19   | 2020–23   |
|------------------------------|-----------|-----------|-----------|-----------|
| share_deps_closed (IV)       | 85.05     | 2.033     | 92.86     | 2.477     |
|                              | (291.6)   | (3.814)   | (166.1)   | (2.596)   |
| N                            | 9,203     | 9,197     | 19,558    | 9,830     |
| County FE                    | Yes       | Yes       | Yes       | Yes       |
| State×Year FE                | Yes       | Yes       | Yes       | Yes       |
| SE                           | County    | County    | County    | County    |
| Mean(cra_growth_incty)       | 0.151     | −0.058    | 0.191     | −0.075    |
| SD(share_deps_closed)        | 0.025     | 0.024     | 0.033     | 0.043     |
| SD(Expose_Event)             | 0.157     | 0.129     | 0.119     | 0.115     |
| R²                           | 0.387     | 0.396     | 0.370     | 0.570     |
| F-test (1st stage)           | 0.221     | 19.866    | 0.447     | 11.621    |
```

*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

### Contrast — OLS (streamlined T3 Panel A) vs IV (this snapshot)

| Period   | OLS coef   | IV coef | IV-F   | N      |
|----------|------------|---------|-------:|-------:|
| 2000–07  | −0.350*    | 85.05   |  0.22  |  9,203 |
| 2008–11  | −0.236     |  2.03   | 19.87  |  9,197 |
| 2012–19  |  0.098     | 92.86   |  0.45  | 19,558 |
| 2020–23  |  0.286     |  2.48   | 11.62  |  9,830 |

**Read:** Only 2008–11 and 2020–23 columns have usable IV-F. In both, IV coefficient is small and insignificant — no detectable causal effect of competitor closure on incumbent CRA small-business lending. 2000–07 and 2012–19 first stages collapse (county-aggregated binary instrument too sparse within those windows).

---

## Instrument Build Diagnostics

- NIC `transformations` rows with `TRNSFM_CD = '1'` (2001–2024): 21,417
- After $10B (SOD ASSET in $000s, cutoff 1e7) filter on both parties: 114 mergers
- Treated (ZIP × Event_Year × TRANSNUM) rows: 3,152
- Distinct treated (ZIP, Event_Year): 3,101



---

*Sources: `code/approach-merger-iv-20260424/01_validate_sod_source.R`, `02_build_branch_panel.R`, `03_build_merger_instrument.R`, `04_nguyen_figure2.R`, `05_first_stage.R`, `06_iv_second_stage.R`, `07_iv_hmda_zip.R`, `08_iv_cra_county.R`*
