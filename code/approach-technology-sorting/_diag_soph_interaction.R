rm(list = ls())
library(data.table)
library(fixest)

setFixest_etable(signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below=TRUE)

# ── Load ──────────────────────────────────────────────────────────────────────
sample_files <- list.files("data", pattern="^zip_tech_sample_\\d{8}\\.rds$", full.names=TRUE)
dt <- setDT(readRDS(sample_files[which.max(file.mtime(sample_files))]))

zip_demo_path <- "C:/Users/dimut/OneDrive/data/nrs_branch_closure/zip_demographics_panel.rds"
zip_demo_full <- setDT(readRDS(zip_demo_path))
library(stringr)
zip_demo_full[, zip := str_pad(as.integer(zip), 5, "left", "0")]
zip_demo_full[, YEAR := as.integer(yr)]
# merge extra demo vars not in dt
extra_cols <- c("zip","YEAR","sophisticated_acs_only","median_income",
                "pct_college_educated","capital_gain_frac","dividend_frac")
zip_demo_extra <- zip_demo_full[, ..extra_cols]
dt <- merge(dt, zip_demo_extra, by=c("zip","YEAR"), all.x=TRUE, suffixes=c("",".y"))

# ── Helpers ───────────────────────────────────────────────────────────────────
wins <- function(x, lo, hi) {
  q <- quantile(x, c(lo, hi), na.rm=TRUE)
  pmin(pmax(x, q[1]), q[2])
}

report <- function(label, m) {
  vars <- names(coef(m))
  int_var <- grep("sophisticated|soph|college|income|dividend|capital", vars, value=TRUE)
  int_var <- int_var[grep("share_deps", int_var)]
  if (!length(int_var)) { cat(sprintf("%-55s  [no interaction found]\n", label)); return() }
  iv <- int_var[1]
  b  <- coef(m)[iv]
  se <- se(m)[iv]
  pv <- pvalue(m)[iv]
  stars <- ifelse(pv<0.01,"***",ifelse(pv<0.05,"**",ifelse(pv<0.1,"*","")))
  cat(sprintf("%-55s  coef=%+.4f  se=%.4f  p=%.3f%s  N=%d\n",
              label, b, se, pv, stars, m$nobs))
}

base_controls <- "log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1"
slim_controls <- "log_n_branches + log_n_inc_banks"

cat("\n========== Diagnostics: share_deps_closed x sophisticated, 2012-19 ==========\n\n")

# ── 1. Baseline (current spec) ─────────────────────────────────────────────
d <- dt[YEAR %between% c(2012,2019)]
m <- feols(outcome ~ share_deps_closed + share_deps_closed:sophisticated +
             sophisticated + log_n_branches + log_n_inc_banks +
             log_total_deps + dep_growth_t3t1 | zip + county_yr,
           data=d, vcov=~zip)
report("1. Baseline (current)", m)

# ── 2. Winsorization variations ───────────────────────────────────────────
for (lo_hi in list(c(0.01,0.99), c(0.05,0.95), c(0,1))) {
  d2 <- copy(d)
  d2[, outcome_w := wins(outcome * (total_deps>0), lo_hi[1], lo_hi[2])]
  # recompute raw outcome then rewinsorize
  d2[, outcome_w := wins(
    fifelse(total_deps>0, (inc_tp1-inc_curr)/total_deps, NA_real_),
    lo_hi[1], lo_hi[2])]
  m2 <- feols(outcome_w ~ share_deps_closed + share_deps_closed:sophisticated +
                sophisticated + log_n_branches + log_n_inc_banks +
                log_total_deps + dep_growth_t3t1 | zip + county_yr,
              data=d2, vcov=~zip)
  lbl <- sprintf("2. Wins %.0f/%.0f pct", lo_hi[1]*100, lo_hi[2]*100)
  report(lbl, m2)
}

# ── 3. Slim controls (no log_total_deps, dep_growth) ─────────────────────
m3 <- feols(outcome ~ share_deps_closed + share_deps_closed:sophisticated +
              sophisticated + log_n_branches + log_n_inc_banks | zip + county_yr,
            data=d, vcov=~zip)
report("3. Slim controls (no total_deps/growth)", m3)

# ── 4. Time-invariant soph_zip (majority classification) ─────────────────
d4 <- copy(d)
d4[, soph_zip := mean(sophisticated, na.rm=TRUE) >= 0.5, by=zip]
m4 <- feols(outcome ~ share_deps_closed + share_deps_closed:soph_zip +
              log_n_branches + log_n_inc_banks +
              log_total_deps + dep_growth_t3t1 | zip + county_yr,
            data=d4, vcov=~zip)
report("4. Time-invariant soph_zip (majority)", m4)

# ── 5. Alternative: sophisticated_acs_only (education + income, no investment) ─
m5 <- feols(outcome ~ share_deps_closed + share_deps_closed:sophisticated_acs_only +
              sophisticated_acs_only + log_n_branches + log_n_inc_banks +
              log_total_deps + dep_growth_t3t1 | zip + county_yr,
            data=d, vcov=~zip)
report("5. sophisticated_acs_only (educ+income)", m5)

# ── 6. Continuous: pct_college_educated (standardized) ────────────────────
d6 <- copy(d)
d6[, college_std := (pct_college_educated - mean(pct_college_educated,na.rm=TRUE)) /
     sd(pct_college_educated,na.rm=TRUE), by=YEAR]
m6 <- feols(outcome ~ share_deps_closed + share_deps_closed:college_std +
              college_std + log_n_branches + log_n_inc_banks +
              log_total_deps + dep_growth_t3t1 | zip + county_yr,
            data=d6, vcov=~zip)
report("6. Continuous: pct_college_educated (std, within-yr)", m6)

# ── 7. Continuous: median_income (log, standardized) ─────────────────────
d7 <- copy(d)
d7[, log_medinc := log(median_income)]
d7[, medinc_std := (log_medinc - mean(log_medinc,na.rm=TRUE)) /
     sd(log_medinc,na.rm=TRUE), by=YEAR]
m7 <- feols(outcome ~ share_deps_closed + share_deps_closed:medinc_std +
              medinc_std + log_n_branches + log_n_inc_banks +
              log_total_deps + dep_growth_t3t1 | zip + county_yr,
            data=d7, vcov=~zip)
report("7. Continuous: log(median_income) (std, within-yr)", m7)

# ── 8. Continuous: dividend_frac (standardized) ───────────────────────────
d8 <- copy(d)
d8[, div_std := (dividend_frac - mean(dividend_frac,na.rm=TRUE)) /
     sd(dividend_frac,na.rm=TRUE), by=YEAR]
m8 <- feols(outcome ~ share_deps_closed + share_deps_closed:div_std +
              div_std + log_n_branches + log_n_inc_banks +
              log_total_deps + dep_growth_t3t1 | zip + county_yr,
            data=d8, vcov=~zip)
report("8. Continuous: dividend_frac (std, within-yr)", m8)

# ── 9. Restrict to zips with at least one closure (share_deps_closed > 0) ─
d9 <- d[share_deps_closed > 0]
m9 <- feols(outcome ~ share_deps_closed + share_deps_closed:sophisticated +
              sophisticated + log_n_branches + log_n_inc_banks +
              log_total_deps + dep_growth_t3t1 | zip + county_yr,
            data=d9, vcov=~zip)
report("9. Zips with closures only (share_deps>0)", m9)

# ── 10. Narrower period 2014-2019 (avoid GFC echo) ────────────────────────
d10 <- dt[YEAR %between% c(2014,2019)]
m10 <- feols(outcome ~ share_deps_closed + share_deps_closed:sophisticated +
               sophisticated + log_n_branches + log_n_inc_banks +
               log_total_deps + dep_growth_t3t1 | zip + county_yr,
             data=d10, vcov=~zip)
report("10. Narrower period 2014-2019", m10)

# ── 11. Cluster at county instead of zip ──────────────────────────────────
m11 <- feols(outcome ~ share_deps_closed + share_deps_closed:sophisticated +
               sophisticated + log_n_branches + log_n_inc_banks +
               log_total_deps + dep_growth_t3t1 | zip + county_yr,
             data=d, vcov=~county)
report("11. SE clustered at county (not zip)", m11)

# ── 12. Drop n_inc_banks >= 2 filter (include single-incumbent zips) ──────
dt_raw <- setDT(readRDS(sample_files[which.max(file.mtime(sample_files))]))
dt_raw <- merge(dt_raw, zip_demo_extra, by=c("zip","YEAR"), all.x=TRUE, suffixes=c("",".y"))
d12 <- dt_raw[YEAR %between% c(2012,2019) & !is.na(outcome) & !is.na(county)]
m12 <- feols(outcome ~ share_deps_closed + share_deps_closed:sophisticated +
               sophisticated + log_n_branches + log_n_inc_banks +
               log_total_deps + dep_growth_t3t1 | zip + county_yr,
             data=d12, vcov=~zip)
report("12. Include single-incumbent zips (drop n_inc>=2 filter)", m12)

# ── 13. Winsorize treatment share_deps_closed at 99th pct ─────────────────
d13 <- copy(d)
p99 <- quantile(d13$share_deps_closed, 0.99, na.rm=TRUE)
d13[, share_deps_w := pmin(share_deps_closed, p99)]
m13 <- feols(outcome ~ share_deps_w + share_deps_w:sophisticated +
               sophisticated + log_n_branches + log_n_inc_banks +
               log_total_deps + dep_growth_t3t1 | zip + county_yr,
             data=d13, vcov=~zip)
report("13. Winsorize treatment at 99th pct", m13)

# ── 14. Triple interaction: period split within 2012-19 ───────────────────
d14 <- copy(d)
d14[, post2015 := as.integer(YEAR >= 2015)]
m14a <- feols(outcome ~ share_deps_closed + share_deps_closed:sophisticated +
                sophisticated + log_n_branches + log_n_inc_banks +
                log_total_deps + dep_growth_t3t1 | zip + county_yr,
              data=d14[post2015==0], vcov=~zip)
m14b <- feols(outcome ~ share_deps_closed + share_deps_closed:sophisticated +
                sophisticated + log_n_branches + log_n_inc_banks +
                log_total_deps + dep_growth_t3t1 | zip + county_yr,
              data=d14[post2015==1], vcov=~zip)
report("14a. 2012-2014 subsample", m14a)
report("14b. 2015-2019 subsample", m14b)

cat("\n==========================================================================\n")
