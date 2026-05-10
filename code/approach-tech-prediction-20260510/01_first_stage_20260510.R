# 01_first_stage_20260510.R
#
# Linear first stage on 2012-2019. Phil's spec: app exposure x mobile.
#
# Four specifications, organized as 2 (LHS) x 2 (frac_apps weighting):
#
#                        |  RHS frac_apps weighting
#                        |  count            |  deposit
#   --------------------- ------------------- -------------------
#   LHS = frac_branches_closed (count)  | spec 1            | spec 2
#   LHS = share_deps_closed   (depwt)   | spec 3            | spec 4
#
# Common RHS form:
#   ~ frac_apps_<w> + frac_apps_<w>:perc_hh_wMobileSub
#     + log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1
#     | zip + county_yr,  cluster = ~zip
#
# Sample:  2012-2019 with non-NA `perc_hh_wMobileSub`. Drops ~19,759 rows
# whose county lacks mobile data — necessary for the interaction.
#
# Each spec produces a (predicted, residual) pair; the four pairs feed
# 02_second_stage as four decomposition columns.

rm(list = ls())
gc()

source("code/approach-tech-prediction-20260510/00_common.R")

# Source: code/approach-tech-prediction-20260510/data/zip_tech_with_frac_apps_<YYYYMMDD>.rds
# Built by:   code/approach-tech-prediction-20260510/sample-construction/B1_build_frac_apps_zip_20260510.R
# Contents:   zip-year sample with frac_apps_zip_count + frac_apps_zip_dep.
dt <- setDT(load_latest(data_path, "^zip_tech_with_frac_apps_\\d{8}\\.rds$"))
dt[, fraction_of_branches_closed := n_closed_zip / pmax(branches_lag1, 1)]

ctrls <- "log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1"
fe    <- "zip + county_yr"

dt_fs <- dt[YEAR %between% c(2012L, 2019L) & !is.na(perc_hh_wMobileSub)]

cat("=== First-stage sample (2012-2019, non-NA mobile) ===\n")
cat("rows:", nrow(dt_fs), "\n\n")

# ── Helper: fit one spec ────────────────────────────────────────────────────
fit_fs <- function(lhs, w) {
  rhs_app <- paste0("frac_apps_zip_", w)
  feols(
    as.formula(paste0(
      lhs, " ~ ", rhs_app, " + ", rhs_app, ":perc_hh_wMobileSub + ",
      ctrls, " | ", fe)),
    data    = dt_fs,
    cluster = ~zip)
}

fs_count_count <- fit_fs("fraction_of_branches_closed", "count")  # spec 1
fs_count_dep   <- fit_fs("fraction_of_branches_closed", "dep")    # spec 2
fs_share_count <- fit_fs("share_deps_closed",           "count")  # spec 3
fs_share_dep   <- fit_fs("share_deps_closed",           "dep")    # spec 4

# ── Project predictions onto FULL panel (2012-2019 with mobile available) ──
project <- function(m, suffix) {
  pred_col <- paste0("predicted_", suffix)
  resid_col <- paste0("residual_",  suffix)
  dt[, (pred_col)  := predict(m, newdata = .SD)]
  outcome_var <- if (grepl("^count_", suffix)) "fraction_of_branches_closed" else "share_deps_closed"
  dt[, (resid_col) := get(outcome_var) - get(pred_col)]
  invisible(NULL)
}
project(fs_count_count, "count_count")
project(fs_count_dep,   "count_dep")
project(fs_share_count, "share_count")
project(fs_share_dep,   "share_dep")

# ── Combined first-stage table (4 columns) ──────────────────────────────────
fs_models  <- list(fs_count_count, fs_count_dep, fs_share_count, fs_share_dep)
fs_headers <- c(
  "frac_branches ~ count",
  "frac_branches ~ dep",
  "share_deps ~ count",
  "share_deps ~ dep"
)
# Footer: rename the LHS-specific moments per column
fs_footer <- list(
  "Mean(LHS)" = c(rnd(mean(dt_fs$fraction_of_branches_closed, na.rm = TRUE)),
                  rnd(mean(dt_fs$fraction_of_branches_closed, na.rm = TRUE)),
                  rnd(mean(dt_fs$share_deps_closed,           na.rm = TRUE)),
                  rnd(mean(dt_fs$share_deps_closed,           na.rm = TRUE))),
  "SD(frac_apps)" = c(rnd(sd(dt_fs$frac_apps_zip_count, na.rm = TRUE)),
                      rnd(sd(dt_fs$frac_apps_zip_dep,   na.rm = TRUE)),
                      rnd(sd(dt_fs$frac_apps_zip_count, na.rm = TRUE)),
                      rnd(sd(dt_fs$frac_apps_zip_dep,   na.rm = TRUE)))
)

write_md(etable(fs_models, headers = fs_headers, tex = FALSE,
                extralines = fs_footer),
         md_out("T0_first_stage"))

cat("\n=== T0 first stage (4 specs) ===\n")
print(etable(fs_models, headers = fs_headers, tex = FALSE))

# ── Option A: clean first stage (no mechanical controls) ────────────────────
# Strips log_n_branches / log_n_inc_banks / log_total_deps / dep_growth_t3t1
# from 1st-stage RHS so predicted is driven by the tech driver only
# (and zip + county_yr FE).  Apply controls in 2nd stage where they belong.
fit_fs_clean <- function(lhs, w) {
  rhs_app <- paste0("frac_apps_zip_", w)
  feols(
    as.formula(paste0(
      lhs, " ~ ", rhs_app, " + ", rhs_app, ":perc_hh_wMobileSub | ", fe)),
    data    = dt_fs,
    cluster = ~zip)
}

fs_count_count_c <- fit_fs_clean("fraction_of_branches_closed", "count")
fs_count_dep_c   <- fit_fs_clean("fraction_of_branches_closed", "dep")
fs_share_count_c <- fit_fs_clean("share_deps_closed",           "count")
fs_share_dep_c   <- fit_fs_clean("share_deps_closed",           "dep")

project_clean <- function(m, suffix) {
  pred_col  <- paste0("predicted_clean_", suffix)
  resid_col <- paste0("residual_clean_",  suffix)
  dt[, (pred_col)  := predict(m, newdata = .SD)]
  outcome_var <- if (grepl("^count_", suffix)) "fraction_of_branches_closed" else "share_deps_closed"
  dt[, (resid_col) := get(outcome_var) - get(pred_col)]
  invisible(NULL)
}
project_clean(fs_count_count_c, "count_count")
project_clean(fs_count_dep_c,   "count_dep")
project_clean(fs_share_count_c, "share_count")
project_clean(fs_share_dep_c,   "share_dep")

# F-stat for joint significance of (frac_apps + interaction).
joint_F <- function(m, w) {
  V <- vcov(m); cf <- coef(m)
  terms <- c(paste0("frac_apps_zip_", w),
             paste0("frac_apps_zip_", w, ":perc_hh_wMobileSub"))
  terms <- intersect(terms, names(cf))
  if (length(terms) < 1) return(NA_real_)
  b  <- cf[terms]
  Vs <- V[terms, terms, drop = FALSE]
  q  <- length(terms)
  as.numeric(t(b) %*% solve(Vs) %*% b) / q
}
F_count_count <- joint_F(fs_count_count_c, "count")
F_count_dep   <- joint_F(fs_count_dep_c,   "dep")
F_share_count <- joint_F(fs_share_count_c, "count")
F_share_dep   <- joint_F(fs_share_dep_c,   "dep")

fs_models_c  <- list(fs_count_count_c, fs_count_dep_c, fs_share_count_c, fs_share_dep_c)
fs_footer_c <- list(
  "Mean(LHS)"     = c(rnd(mean(dt_fs$fraction_of_branches_closed, na.rm = TRUE)),
                      rnd(mean(dt_fs$fraction_of_branches_closed, na.rm = TRUE)),
                      rnd(mean(dt_fs$share_deps_closed,           na.rm = TRUE)),
                      rnd(mean(dt_fs$share_deps_closed,           na.rm = TRUE))),
  "SD(frac_apps)" = c(rnd(sd(dt_fs$frac_apps_zip_count, na.rm = TRUE)),
                      rnd(sd(dt_fs$frac_apps_zip_dep,   na.rm = TRUE)),
                      rnd(sd(dt_fs$frac_apps_zip_count, na.rm = TRUE)),
                      rnd(sd(dt_fs$frac_apps_zip_dep,   na.rm = TRUE))),
  "Joint F (tech)" = c(rnd(F_count_count, 2), rnd(F_count_dep, 2),
                       rnd(F_share_count, 2), rnd(F_share_dep, 2))
)

write_md(etable(fs_models_c, headers = fs_headers, tex = FALSE,
                extralines = fs_footer_c),
         md_out("T0_first_stage_clean"))

cat("\n=== T0 first stage CLEAN (4 specs, no mechanical controls) ===\n")
print(etable(fs_models_c, headers = fs_headers, tex = FALSE))

cat("\n=== Joint F-stats (tech terms) ===\n")
cat("frac_branches ~ count :", round(F_count_count, 2), "\n")
cat("frac_branches ~ dep   :", round(F_count_dep,   2), "\n")
cat("share_deps    ~ count :", round(F_share_count, 2), "\n")
cat("share_deps    ~ dep   :", round(F_share_dep,   2), "\n")

# ── Save enriched panel ─────────────────────────────────────────────────────
out_path <- file.path(data_path, paste0("zip_tech_with_pred_resid_", dat_suffix, ".rds"))
saveRDS(dt, out_path)
cat("\nSaved:", out_path, "\n")
cat("Rows:", nrow(dt), "\n")

# ── Key results summary ─────────────────────────────────────────────────────
cat("\n## Key first-stage coefficients\n\n")
cat("| Spec | Term | Coef | SE | Sig | N |\n")
cat("|---|---|---|---|---|---|\n")
print_row <- function(m, label, term) {
  ct <- coeftable(m)
  if (term %in% rownames(ct)) {
    co <- ct[term, "Estimate"]; se <- ct[term, "Std. Error"]; p <- ct[term, "Pr(>|t|)"]
    sig <- ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
    cat(sprintf("| %s | %s | %.3f | %.3f | %s | %d |\n",
                label, term, co, se, sig, m$nobs))
  }
}
print_row(fs_count_count, "frac_branches ~ count", "frac_apps_zip_count")
print_row(fs_count_count, "frac_branches ~ count", "frac_apps_zip_count:perc_hh_wMobileSub")
print_row(fs_count_dep,   "frac_branches ~ dep",   "frac_apps_zip_dep")
print_row(fs_count_dep,   "frac_branches ~ dep",   "frac_apps_zip_dep:perc_hh_wMobileSub")
print_row(fs_share_count, "share_deps ~ count",    "frac_apps_zip_count")
print_row(fs_share_count, "share_deps ~ count",    "frac_apps_zip_count:perc_hh_wMobileSub")
print_row(fs_share_dep,   "share_deps ~ dep",      "frac_apps_zip_dep")
print_row(fs_share_dep,   "share_deps ~ dep",      "frac_apps_zip_dep:perc_hh_wMobileSub")
