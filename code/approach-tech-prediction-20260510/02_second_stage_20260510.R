# 02_second_stage_20260510.R
#
# Second stage on incumbent reallocation, restricted to 2012-2019.
# Five columns:
#   col 1: baseline OLS  — outcome ~ share_deps_closed + ctrls
#   col 2: decomp 1      — predicted/residual from FS spec 1 (frac_branches ~ count)
#   col 3: decomp 2      — predicted/residual from FS spec 2 (frac_branches ~ dep)
#   col 4: decomp 3      — predicted/residual from FS spec 3 (share_deps   ~ count)
#   col 5: decomp 4      — predicted/residual from FS spec 4 (share_deps   ~ dep)
# All FE = zip + county_yr; cluster = zip.
#
# Baseline runs on full 2012-2019 sample (replicates approach-streamlined
# T1 panelB col 3, N = 89,954). Decomp columns run on rows where first-stage
# predictions are available (drops mobile-NA rows).

rm(list = ls())
gc()

source("code/approach-tech-prediction-20260510/00_common.R")

# Source: code/approach-tech-prediction-20260510/data/zip_tech_with_pred_resid_<YYYYMMDD>.rds
# Built by:   code/approach-tech-prediction-20260510/01_first_stage_20260510.R
# Contents:   zip-year sample with predicted_/residual_ pairs for 4 first-stage specs.
dt <- setDT(load_latest(data_path, "^zip_tech_with_pred_resid_\\d{8}\\.rds$"))

d_full   <- dt[YEAR %between% c(2012L, 2019L)]
d_decomp <- d_full[!is.na(predicted_count_count) & !is.na(predicted_count_dep) &
                   !is.na(predicted_share_count) & !is.na(predicted_share_dep)]

cat("=== Sample sizes (2012-2019) ===\n")
cat("baseline (full):", nrow(d_full),   "\n")
cat("decomp  (predicted available):", nrow(d_decomp), "\n\n")

ctrls <- "log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1"
fe    <- "zip + county_yr"

run <- function(d, rhs) feols(
  as.formula(paste0("outcome ~ ", rhs, " + ", ctrls, " | ", fe)),
  data = d, vcov = ~zip)

m_base <- run(d_full, "share_deps_closed")

# Helper: rename predicted_/residual_<suffix> to "predicted"/"residual"
# so the etable output stacks rows neatly.
rename_terms <- function(m, suffix) {
  pred_old  <- paste0("predicted_", suffix)
  resid_old <- paste0("residual_",  suffix)
  nm <- names(coef(m))
  nm[nm == pred_old]  <- "predicted"
  nm[nm == resid_old] <- "residual"
  names(m$coefficients) <- nm
  rownames(m$coeftable) <- nm
  if (!is.null(m$cov.scaled)) {
    rownames(m$cov.scaled) <- colnames(m$cov.scaled) <- nm
  }
  m
}

fit_decomp <- function(suffix) {
  m <- run(d_decomp, paste0("predicted_", suffix, " + residual_", suffix))
  rename_terms(m, suffix)
}

m_d1 <- fit_decomp("count_count")  # frac_branches ~ count
m_d2 <- fit_decomp("count_dep")    # frac_branches ~ dep
m_d3 <- fit_decomp("share_count")  # share_deps   ~ count
m_d4 <- fit_decomp("share_dep")    # share_deps   ~ dep

wald_pval <- function(m) {
  if (!all(c("predicted", "residual") %in% names(coef(m)))) return(NA_real_)
  V    <- vcov(m)
  diff <- coef(m)[["predicted"]] - coef(m)[["residual"]]
  v    <- V["predicted", "predicted"] + V["residual", "residual"] - 2 * V["predicted", "residual"]
  if (!is.finite(v) || v <= 0) return(NA_real_)
  pchisq(diff^2 / v, df = 1, lower.tail = FALSE)
}

p_d1 <- wald_pval(m_d1)
p_d2 <- wald_pval(m_d2)
p_d3 <- wald_pval(m_d3)
p_d4 <- wald_pval(m_d4)

models  <- list(m_base, m_d1, m_d2, m_d3, m_d4)
headers <- c(
  "baseline",
  "frac_branches ~ count",
  "frac_branches ~ dep",
  "share_deps ~ count",
  "share_deps ~ dep"
)

# SD(predicted) per decomp column for footer
sd_pred <- sapply(c("count_count", "count_dep", "share_count", "share_dep"),
                  function(s) rnd(sd(d_decomp[[paste0("predicted_", s)]], na.rm = TRUE)))

footer <- list(
  "Mean(outcome)"    = c(rnd(mean(d_full$outcome,   na.rm = TRUE)),
                         rep(rnd(mean(d_decomp$outcome, na.rm = TRUE)), 4)),
  "SD(treatment)"    = c(rnd(sd(d_full$share_deps_closed, na.rm = TRUE)),
                         sd_pred),
  "p(beta_p=beta_r)" = c("",
                         rnd(p_d1), rnd(p_d2), rnd(p_d3), rnd(p_d4))
)

write_md(etable(models, headers = headers, tex = FALSE, extralines = footer),
         md_out("T1_decomp"))

cat("=== T1 (2012-2019: baseline + 4 decomps) ===\n")
print(etable(models, headers = headers, tex = FALSE))

cat("\n## Key coefficients\n\n")
cat("| Column | Term | Coef | SE | Sig | N | p(b_p=b_r) |\n")
cat("|---|---|---|---|---|---|---|\n")
pvals <- c(NA_real_, p_d1, p_d2, p_d3, p_d4)
for (i in seq_along(models)) {
  m <- models[[i]]; ct <- coeftable(m); pv <- pvals[[i]]
  pv_s <- ifelse(is.na(pv), "", sprintf("%.3f", pv))
  treat_terms <- intersect(rownames(ct),
    c("share_deps_closed", "predicted", "residual"))
  for (term in treat_terms) {
    co <- ct[term, "Estimate"]; se <- ct[term, "Std. Error"]
    pp <- ct[term, "Pr(>|t|)"]
    sig <- ifelse(pp < 0.01, "***", ifelse(pp < 0.05, "**", ifelse(pp < 0.1, "*", "")))
    cat(sprintf("| %s | %s | %.3f | %.3f | %s | %d | %s |\n",
                headers[i], term, co, se, sig, m$nobs, pv_s))
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Option A — clean decomp using predictions from controls-stripped 1st stage
# ─────────────────────────────────────────────────────────────────────────────
d_decomp_c <- d_full[!is.na(predicted_clean_count_count) &
                     !is.na(predicted_clean_count_dep) &
                     !is.na(predicted_clean_share_count) &
                     !is.na(predicted_clean_share_dep)]

cat("\n=== Option A clean: decomp sample size ===\n")
cat("rows:", nrow(d_decomp_c), "\n\n")

fit_decomp_c <- function(suffix) {
  m <- feols(as.formula(paste0(
    "outcome ~ predicted_clean_", suffix, " + residual_clean_", suffix,
    " + ", ctrls, " | ", fe)),
    data = d_decomp_c, vcov = ~zip)
  rename_pair <- function(m, p_old, r_old) {
    nm <- names(coef(m))
    nm[nm == p_old] <- "predicted"
    nm[nm == r_old] <- "residual"
    names(m$coefficients) <- nm
    rownames(m$coeftable) <- nm
    if (!is.null(m$cov.scaled)) rownames(m$cov.scaled) <- colnames(m$cov.scaled) <- nm
    m
  }
  rename_pair(m, paste0("predicted_clean_", suffix), paste0("residual_clean_", suffix))
}

m_c1 <- fit_decomp_c("count_count")
m_c2 <- fit_decomp_c("count_dep")
m_c3 <- fit_decomp_c("share_count")
m_c4 <- fit_decomp_c("share_dep")

p_c1 <- wald_pval(m_c1)
p_c2 <- wald_pval(m_c2)
p_c3 <- wald_pval(m_c3)
p_c4 <- wald_pval(m_c4)

models_c  <- list(m_base, m_c1, m_c2, m_c3, m_c4)
sd_pred_c <- sapply(c("count_count", "count_dep", "share_count", "share_dep"),
                    function(s) rnd(sd(d_decomp_c[[paste0("predicted_clean_", s)]], na.rm = TRUE)))
footer_c <- list(
  "Mean(outcome)"    = c(rnd(mean(d_full$outcome,     na.rm = TRUE)),
                         rep(rnd(mean(d_decomp_c$outcome, na.rm = TRUE)), 4)),
  "SD(treatment)"    = c(rnd(sd(d_full$share_deps_closed, na.rm = TRUE)),
                         sd_pred_c),
  "p(beta_p=beta_r)" = c("",
                         rnd(p_c1), rnd(p_c2), rnd(p_c3), rnd(p_c4))
)

write_md(etable(models_c, headers = headers, tex = FALSE, extralines = footer_c),
         md_out("T1_decomp_clean"))

cat("\n=== T1 CLEAN decomp (Option A: no 1st-stage controls) ===\n")
print(etable(models_c, headers = headers, tex = FALSE))

cat("\n## Key coefficients (clean)\n\n")
cat("| Column | Term | Coef | SE | Sig | N | p(b_p=b_r) |\n")
cat("|---|---|---|---|---|---|---|\n")
pvals_c <- c(NA_real_, p_c1, p_c2, p_c3, p_c4)
for (i in seq_along(models_c)) {
  m <- models_c[[i]]; ct <- coeftable(m); pv <- pvals_c[[i]]
  pv_s <- ifelse(is.na(pv), "", sprintf("%.3f", pv))
  treat_terms <- intersect(rownames(ct),
    c("share_deps_closed", "predicted", "residual"))
  for (term in treat_terms) {
    co <- ct[term, "Estimate"]; se <- ct[term, "Std. Error"]
    pp <- ct[term, "Pr(>|t|)"]
    sig <- ifelse(pp < 0.01, "***", ifelse(pp < 0.05, "**", ifelse(pp < 0.1, "*", "")))
    cat(sprintf("| %s | %s | %.3f | %.3f | %s | %d | %s |\n",
                headers[i], term, co, se, sig, m$nobs, pv_s))
  }
}
