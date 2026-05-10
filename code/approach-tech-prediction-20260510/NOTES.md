# approach-tech-prediction-20260510 — Notes

## Goal

Implement Phil's May 5 2026, 1:33 PM email: build a predicted zip-year
closure variable directly. Driver = `frac_apps_zip × perc_hh_wMobileSub`
plus standard controls. Decompose closures into predicted (tech-driven)
+ residual (non-tech). Test β_predicted vs β_residual.

## Design

- **Sample window:** 2012-2019 only. Pre-2012: no app data. 2020+:
  saturation (mean frac_apps = 0.94) makes predicted uninterpretable.
- **frac_apps_zip (two weightings):**
  - `frac_apps_zip_count` = #branches in zip with app / #branches
  - `frac_apps_zip_dep`   = deposits at app-bank branches / total deposits
- **First stage (4 specs, 2 LHS x 2 RHS weightings):** linear OLS on
  2012-2019 with non-NA mobile (N = 70,195), FE = `zip + county_yr`,
  cluster = zip. RHS includes `frac_apps × perc_hh_wMobileSub`
  (Phil's spec).
- **Second stage:** baseline OLS on full sample (N = 89,954) +
  4 decomposition columns matching first-stage specs (N = 70,195).
- **Outcome:** zip incumbent reallocation only.

## Pipeline

1. `sample-construction/B1_build_frac_apps_zip_20260510.R`
   - Builds `frac_apps_zip` at (zip, YEAR) from SOD branch panel + CH app panel.
   - Saves `data/zip_tech_with_frac_apps_<YYYYMMDD>.rds`.
2. `01_first_stage_20260510.R`
   - 2012-2019 first stage; predicts on same window; saves enriched rds + T0.
3. `02_second_stage_20260510.R`
   - Single 2012-2019 table with count + depwt columns.

## Run log

### Option A — clean first stage (no mechanical controls)

**T0_first_stage_clean.md** (4 specs, RHS = `frac_apps + frac_apps×mobile`
only; FE = `zip + county_yr`):

| Spec | frac_apps β | × mobile β | **Joint F** |
|---|---|---|---|
| frac_branches ~ count | -0.008* | +0.018**  | **2.07** |
| frac_branches ~ dep   | -0.010** | +0.021*** | **3.65** |
| share_deps    ~ count | -0.003   | +0.013*   | **2.58** |
| share_deps    ~ dep   | -0.004   | +0.011*   | **1.65** |

- Removing mechanical controls **strengthens the interaction** (was n.s.
  with controls, now significant in 3 of 4 specs).
- Joint F-stat on tech terms = **1.6 - 3.7** in all specs. **Below the
  conventional weak-instrument cutoff of 10.** The tech driver alone
  doesn't predict closures with enough power.
- Within R² collapses to ~0.0001 (vs 0.30 - 0.52 with controls). Confirms
  the controls were doing nearly all the explanatory work in the original
  spec.

**T1_decomp_clean.md** (5 cols: baseline + 4 clean decomps, all controls
+ FE in 2nd stage):

| Column | predicted β | Sig | Wald p |
|---|---|---|---|
| baseline (share_deps_closed) | 0.0098 |   |   |
| frac_branches ~ count | 1.72 | **  | 0.022 |
| frac_branches ~ dep   | 1.85 | *** | 0.003 |
| share_deps    ~ count | 1.53 | *   | 0.072 |
| share_deps    ~ dep   | 3.73 | *** | 0.002 |

Predicted is significant in all 4 specs (was only sig in share_deps specs
with controls). Wald rejects equality in 3 of 4.

**Caveat — weak instrument warning.** Joint F < 10 across all specs means
predicted variation is small and 2nd-stage β estimates are biased
(toward OLS) and inference unreliable. The "significance" of predicted
in the 2nd stage is largely a finite-sample / weak-instrument artifact:
small predicted variance → small SE → spurious significance.

**Reading:**
- Phil's tech driver (`frac_apps × mobile`) is **directionally consistent**
  with hypothesis (positive interaction in all 4 specs) but **too weak
  numerically** to support a credible decomposition.
- Both control-included AND clean specifications produce β_predicted that
  is opposite Phil's expected sign (β_pred > β_resid, not <). With clean
  specs the gap is stronger but the F-stat warning means we can't trust
  the 2nd-stage signs.
- **Recommendation:** the orthogonal `share_deps_closed_app` vs
  `share_deps_closed_noapp` panel decomposition (already in
  `zip_tech_sample`) avoids the weak-instrument problem entirely —
  closures are physically labeled, not projected.

---


### 2026-05-10

**B1 builder:**
- 284,708 zip-year rows; 63.8% with non-zero `frac_apps_zip`.
- Mean by year: 0.42 (2012) → 0.88 (2019).

**First stage (2012-2019, N = 70,195, T0_first_stage.md, 4 specs):**

| Spec | frac_apps β | × mobile β |
|---|---|---|
| frac_branches ~ count | -0.011*** | +0.008 |
| frac_branches ~ dep   | -0.010*** | +0.013* |
| share_deps    ~ count | -0.003    | +0.005 |
| share_deps    ~ dep   | -0.002    | +0.005 |

- `frac_apps × mobile` interaction sign POSITIVE in all 4 specs (Phil's
  hypothesised direction).
- Significance only in `frac_branches ~ dep` spec (interaction p < 0.10).
- LHS = `share_deps_closed` (depwt) yields weaker first-stage signal
  than LHS = `frac_branches_closed` (count).

**Second stage (2012-2019, T1_decomp.md, 5 columns):**

| Column | Treatment | β | SE | Sig | N | p(β_p = β_r) |
|---|---|---|---|---|---|---|
| baseline              | share_deps_closed | 0.010 | 0.010 |     | 89,954 |   |
| frac_branches ~ count | predicted         | 0.276 | 0.436 |     | 70,195 | 0.537 |
| frac_branches ~ count | residual          | 0.007 | 0.009 |     | 70,195 |   |
| frac_branches ~ dep   | predicted         | 0.931 | 0.613 |     | 70,195 | 0.132 |
| frac_branches ~ dep   | residual          | 0.006 | 0.009 |     | 70,195 |   |
| share_deps ~ count    | predicted         | 3.41  | 1.90  | *   | 70,195 | 0.074 |
| share_deps ~ count    | residual          | 0.001 | 0.010 |     | 70,195 |   |
| share_deps ~ dep      | predicted         | 7.73  | 2.54  | *** | 70,195 | 0.002 |
| share_deps ~ dep      | residual          | 0.001 | 0.010 |     | 70,195 |   |

Baseline column matches `approach-streamlined-20260423` T1 panelB col 3
exactly: β = 0.0098, N = 89,954.

**Pattern across the 4 decomps:** predicted coefficient grows with both
LHS depwt-ness and RHS depwt-ness; residual coefficient stays stable
(~0.001 - 0.007). Wald test rejects equality progressively more strongly:

| Spec  | predicted β | Wald p |
|---|---|---|
| frac_branches ~ count |  0.28  | 0.537 |
| frac_branches ~ dep   |  0.93  | 0.132 |
| share_deps    ~ count |  3.41  | 0.074 |
| share_deps    ~ dep   |  7.73  | 0.002 |

**Sign opposite Phil's hypothesis** (β_predicted > β_residual; theory
predicted β_predicted < β_residual because tech-driven closures should
retain deposits and produce LESS spillover).

**Caveat:** predicted has small variance after FE absorption
(SD(predicted) = 0.035 in share_deps decomps, 0.050 in frac_branches
decomps). Standardized 1-SD effects: 7.73 × 0.035 ≈ 0.27. Plausible
magnitude in absolute terms but reflects narrow predicted range
amplifying the coefficient — same scaling concern as before.

- **Count column:** both null. Cannot reject equality. No spillover from
  either tech-driven or non-tech closures.
- **Depwt column:** predicted β = 3.41* (marginally significant, p<0.10);
  residual β = 0.001 (null). Wald p = 0.074 — rejects equality at 10%.
  Predicted has a positive spillover, but the sign is **opposite** to
  Phil's hypothesis (which predicted β_predicted < β_residual: tech-driven
  closures retain deposits and produce LESS spillover).
- Standardized effect (depwt): β × SD(predicted) = 3.41 × 0.034 ≈ 0.12.
  Plausible magnitude, but interpretation conflicts with theory.

**Caveats:**

- Predicted has small variance after FE absorption (SD(predicted)=0.034 vs
  SD(residual)=0.037). Similar magnitudes — better than 2020+ case but
  still a partial scaling concern.
- Decomposition is mechanical: "predicted" absorbs zip FE + county_yr FE
  + controls + 2 frac_apps terms in the first stage; second stage
  re-absorbs zip + county_yr.
- Cleaner alternative (deferred): `share_deps_closed_app` vs
  `share_deps_closed_noapp` already in `zip_tech_sample` — orthogonal
  decomposition without projection or scaling artifact.
