---
layout: default
title: "approach-tech-prediction-20260510 — 2026-05-10"
---

# Snapshot: approach-tech-prediction-20260510

---

## 1. First Stage — Without Controls

**Unit:** zip-year
**LHS:** `fraction_of_branches_closed` (count) or `share_deps_closed` (depwt)
**Treatment:** `frac_apps_zip_<w>` + `frac_apps_zip_<w> × perc_hh_wMobileSub`, where `<w>` ∈ {count, dep}
**FE:** zip + county_yr | **SE:** clustered at zip
**Sample:** 2012-2019 with non-NA `perc_hh_wMobileSub` (N = 70,195 fits, 70,223 input rows)
**Controls:** none — strips `log_n_branches`, `log_n_inc_banks`, `log_total_deps`, `dep_growth_t3t1` to isolate the tech driver
*Note: weak-instrument warning — joint F < 4 in all four specs*

```
|                                          | (1) frac_branches ~ count | (2) frac_branches ~ dep | (3) share_deps ~ count | (4) share_deps ~ dep |
|------------------------------------------|---------------------------|-------------------------|------------------------|----------------------|
| frac_apps_zip_count                      | −0.0084*                  |                         | −0.0030                |                      |
|                                          | (0.0046)                  |                         | (0.0034)               |                      |
| frac_apps_zip_count × perc_hh_wMobileSub | 0.0182**                  |                         | 0.0130*                |                      |
|                                          | (0.0091)                  |                         | (0.0068)               |                      |
| frac_apps_zip_dep                        |                           | −0.0103**               |                        | −0.0038              |
|                                          |                           | (0.0040)                |                        | (0.0031)             |
| frac_apps_zip_dep × perc_hh_wMobileSub   |                           | 0.0207***               |                        | 0.0112*              |
|                                          |                           | (0.0079)                |                        | (0.0063)             |
| N                                        | 70,223                    | 70,223                  | 70,223                 | 70,223               |
| Zip FE                                   | Yes                       | Yes                     | Yes                    | Yes                  |
| County×Year FE                           | Yes                       | Yes                     | Yes                    | Yes                  |
| SE                                       | Zip                       | Zip                     | Zip                    | Zip                  |
| Mean(LHS)                                | 0.024                     | 0.024                   | 0.013                  | 0.013                |
| SD(frac_apps)                            | 0.233                     | 0.253                   | 0.233                  | 0.253                |
| Joint F (tech terms)                     | 2.07                      | 3.65                    | 2.58                   | 1.65                 |
| Within R²                                | 7.4e-5                    | 0.00013                 | 9.3e-5                 | 6.1e-5               |
```

*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 2. First Stage — With Controls

**Unit:** zip-year
**LHS:** `fraction_of_branches_closed` (count) or `share_deps_closed` (depwt)
**Treatment:** `frac_apps_zip_<w>` + `frac_apps_zip_<w> × perc_hh_wMobileSub`
**FE:** zip + county_yr | **SE:** clustered at zip
**Sample:** 2012-2019 with non-NA `perc_hh_wMobileSub` (N = 70,195)
**Controls:** `log_n_branches`, `log_n_inc_banks`, `log_total_deps`, `dep_growth_t3t1`
*Note: tech-term coefs shrink dramatically once mechanical controls are added — bank-density controls absorb most of the explanatory variation*

```
|                                          | (1) frac_branches ~ count | (2) frac_branches ~ dep | (3) share_deps ~ count | (4) share_deps ~ dep |
|------------------------------------------|---------------------------|-------------------------|------------------------|----------------------|
| frac_apps_zip_count                      | −0.0110***                |                         | −0.0034                |                      |
|                                          | (0.0041)                  |                         | (0.0032)               |                      |
| frac_apps_zip_count × perc_hh_wMobileSub | 0.0078                    |                         | 0.0049                 |                      |
|                                          | (0.0080)                  |                         | (0.0062)               |                      |
| frac_apps_zip_dep                        |                           | −0.0098***              |                        | −0.0025              |
|                                          |                           | (0.0036)                |                        | (0.0030)             |
| frac_apps_zip_dep × perc_hh_wMobileSub   |                           | 0.0129*                 |                        | 0.0053               |
|                                          |                           | (0.0070)                |                        | (0.0060)             |
| log_n_branches                           | 0.4227***                 | 0.4227***               | 0.2468***              | 0.2468***            |
|                                          | (0.0052)                  | (0.0052)                | (0.0046)               | (0.0046)             |
| log_n_inc_banks                          | −0.5139***                | −0.5137***              | −0.3126***             | −0.3126***           |
|                                          | (0.0043)                  | (0.0043)                | (0.0049)               | (0.0049)             |
| log_total_deps                           | 0.0054***                 | 0.0054***               | 0.0181***              | 0.0181***            |
|                                          | (0.0019)                  | (0.0019)                | (0.0026)               | (0.0026)             |
| dep_growth_t3t1                          | −0.0029**                 | −0.0030**               | −0.0032**              | −0.0032**            |
|                                          | (0.0012)                  | (0.0012)                | (0.0013)               | (0.0013)             |
| N                                        | 70,195                    | 70,195                  | 70,195                 | 70,195               |
| Zip FE                                   | Yes                       | Yes                     | Yes                    | Yes                  |
| County×Year FE                           | Yes                       | Yes                     | Yes                    | Yes                  |
| SE                                       | Zip                       | Zip                     | Zip                    | Zip                  |
| Mean(LHS)                                | 0.024                     | 0.024                   | 0.013                  | 0.013                |
| SD(frac_apps)                            | 0.233                     | 0.253                   | 0.233                  | 0.253                |
| Within R²                                | 0.518                     | 0.518                   | 0.297                  | 0.297                |
```

*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 3. Second Stage — Matching Section 1 (no controls in first stage)

**Unit:** zip-year
**LHS:** `outcome` = (Σ inc_deps_{t+1} − Σ inc_deps_t) / total_zip_deps_{t−1} — 1-year incumbent reallocation
**Treatment:** `predicted_clean_<spec>` and `residual_clean_<spec>` from Section 1 first stages; col (1) = baseline OLS using raw `share_deps_closed`
**FE:** zip + county_yr | **SE:** clustered at zip
**Sample:** col (1) = full 2012-2019 (N = 89,954, replicates `approach-streamlined-20260423` T1 panelB col 3); cols (2)-(5) = decomp subsample (N = 70,195)
**Controls:** `log_n_branches`, `log_n_inc_banks`, `log_total_deps`, `dep_growth_t3t1` (all in 2nd stage)
*Note: weak-instrument warning from Section 1 means predicted-coefficient inference in cols (2)-(5) is unreliable*

```
|                   | (1) baseline | (2) frac_branches ~ count | (3) frac_branches ~ dep | (4) share_deps ~ count | (5) share_deps ~ dep |
|-------------------|--------------|---------------------------|-------------------------|------------------------|----------------------|
| share_deps_closed | 0.0098       |                           |                         |                        |                      |
|                   | (0.0100)     |                           |                         |                        |                      |
| predicted         |              | 1.715**                   | 1.852***                | 1.526*                 | 3.733***             |
|                   |              | (0.747)                   | (0.628)                 | (0.849)                | (1.201)              |
| residual          |              | 0.0066                    | 0.0061                  | 0.0009                 | 0.0008               |
|                   |              | (0.0094)                  | (0.0094)                | (0.0102)               | (0.0102)             |
| N                 | 89,954       | 70,195                    | 70,195                  | 70,195                 | 70,195               |
| Zip FE            | Yes          | Yes                       | Yes                     | Yes                    | Yes                  |
| County×Year FE    | Yes          | Yes                       | Yes                     | Yes                    | Yes                  |
| SE                | Zip          | Zip                       | Zip                     | Zip                    | Zip                  |
| Mean(outcome)     | 0.062        | 0.071                     | 0.071                   | 0.071                  | 0.071                |
| SD(treatment)     | 0.047        | —                         | —                       | —                      | —                    |
| p(β_pred = β_res) | —            | 0.022                     | 0.003                   | 0.072                  | 0.002                |
| Within R²         | 0.043        | 0.043                     | 0.043                   | 0.043                  | 0.043                |
```

*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

## 4. Second Stage — Matching Section 2 (controls in first stage)

**Unit:** zip-year
**LHS:** `outcome` = 1-year incumbent reallocation (same as Section 3)
**Treatment:** `predicted_<spec>` and `residual_<spec>` from Section 2 first stages
**FE:** zip + county_yr | **SE:** clustered at zip
**Sample:** col (1) = full 2012-2019 (N = 89,954); cols (2)-(5) = decomp subsample (N = 70,195)
**Controls:** `log_n_branches`, `log_n_inc_banks`, `log_total_deps`, `dep_growth_t3t1`
*Note: residual β ≈ baseline β by construction — when first-stage controls are mechanical, predicted carries the controls' fit and residual is what's left*

```
|                   | (1) baseline | (2) frac_branches ~ count | (3) frac_branches ~ dep | (4) share_deps ~ count | (5) share_deps ~ dep |
|-------------------|--------------|---------------------------|-------------------------|------------------------|----------------------|
| share_deps_closed | 0.0098       |                           |                         |                        |                      |
|                   | (0.0100)     |                           |                         |                        |                      |
| predicted         |              | 0.276                     | 0.931                   | 3.406*                 | 7.731***             |
|                   |              | (0.436)                   | (0.613)                 | (1.904)                | (2.536)              |
| residual          |              | 0.0066                    | 0.0065                  | 0.0008                 | 0.0008               |
|                   |              | (0.0094)                  | (0.0094)                | (0.0102)               | (0.0102)             |
| N                 | 89,954       | 70,195                    | 70,195                  | 70,195                 | 70,195               |
| Zip FE            | Yes          | Yes                       | Yes                     | Yes                    | Yes                  |
| County×Year FE    | Yes          | Yes                       | Yes                     | Yes                    | Yes                  |
| SE                | Zip          | Zip                       | Zip                     | Zip                    | Zip                  |
| Mean(outcome)     | 0.062        | 0.071                     | 0.071                   | 0.071                  | 0.071                |
| SD(treatment)     | 0.047        | 0.050                     | 0.050                   | 0.035                  | 0.035                |
| p(β_pred = β_res) | —            | 0.537                     | 0.132                   | 0.074                  | 0.002                |
| Within R²         | 0.043        | 0.043                     | 0.043                   | 0.043                  | 0.043                |
```

*Note: \*\*\* p<0.01, \*\* p<0.05, \* p<0.10*

---

*Sources: `code/approach-tech-prediction-20260510/sample-construction/B1_build_frac_apps_zip_20260510.R`, `code/approach-tech-prediction-20260510/01_first_stage_20260510.R`, `code/approach-tech-prediction-20260510/02_second_stage_20260510.R`*
