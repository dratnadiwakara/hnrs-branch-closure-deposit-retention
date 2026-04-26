# 08_iv_cra_county.R
# IV version of approach-streamlined-20260423/04_cra_county.R.
# Same county-year panel construction, controls, FE, cluster; share_deps_closed
# instrumented by Expose_Event aggregated zip→county at Ref_Year (=Event_Year-1).

rm(list = ls())
source("code/approach-merger-iv-20260424/00_common.R")

# External raw sources (OneDrive, not in repo):
#   CLOSURE_PANEL = SOD branch-level panel with `closed` indicator. Origin:
#                   ~/OneDrive/data/closure_opening_data_simple.rds
#   COUNTY_CTRL   = county-year control variables (HHI, payroll, HMDA/CRA lag
#                   growth, LMI). Origin:
#                   ~/OneDrive/data/nrs_branch_closure/county_controls_panel.rds
CLOSURE_PANEL <- "C:/Users/dimut/OneDrive/data/closure_opening_data_simple.rds"
COUNTY_CTRL   <- "C:/Users/dimut/OneDrive/data/nrs_branch_closure/county_controls_panel.rds"

# Source: data/constructed/cra_county_panels_YYYYMMDD.rds
# Built by:   code/approach-streamlined-20260423/sample-construction/B3_cra_county_panel_20260423.R
cra <- setDT(load_latest("data/constructed", "^cra_county_panels_\\d{8}\\.rds$"))

# ---- 1. County-year panel (same as streamlined 04_cra_county.R:27-72) ----
raw <- setDT(readRDS(CLOSURE_PANEL))
raw[, `:=`(county = str_pad(as.integer(STCNTYBR), 5, "left", "0"),
           YEAR = as.integer(YEAR),
           closed = as.integer(fifelse(is.na(closed), 0L, closed)),
           DEPSUMBR = as.numeric(DEPSUMBR))]
setorder(raw, UNINUMBR, YEAR)
raw[, dep_lag1 := shift(DEPSUMBR, 1L, type = "lag"), by = UNINUMBR]
raw[, yr_lag1  := shift(YEAR,     1L, type = "lag"), by = UNINUMBR]
raw[, dep_lag1 := fifelse(yr_lag1 == YEAR - 1L, dep_lag1, NA_real_)]

ct <- raw[!is.na(dep_lag1) & dep_lag1 > 0, .(
  total_deps = sum(dep_lag1), n_branches = uniqueN(UNINUMBR), n_banks = uniqueN(CERT)
), by = .(county, YEAR)]
cc_dep <- raw[closed == 1 & !is.na(dep_lag1) & dep_lag1 > 0,
  .(closed_deps = sum(dep_lag1)), by = .(county, YEAR)]
cty <- merge(ct, cc_dep, by = c("county", "YEAR"), all.x = TRUE)
cty[is.na(closed_deps), closed_deps := 0]
cty[, `:=`(share_deps_closed = closed_deps / pmax(total_deps, 1),
           log_n_branches    = log1p(n_branches),
           log_n_banks       = log1p(n_banks),
           log1p_total_deps  = log1p(total_deps),
           state_yr          = paste0(substr(county, 1, 2), "_", YEAR))]

cty_yr <- raw[!is.na(DEPSUMBR) & DEPSUMBR > 0, .(total_dep_county = sum(DEPSUMBR)),
              by = .(county, YEAR)]
setorder(cty_yr, county, YEAR)
cty_yr[, dep_lag4 := shift(total_dep_county, 4L, type = "lag"), by = county]
cty_yr[, yr_lag4  := shift(YEAR, 4L, type = "lag"), by = county]
cty_yr[, county_dep_growth_t4_t1 := fifelse(
  yr_lag4 == YEAR - 4 & dep_lag4 > 0,
  (total_dep_county - dep_lag4) / dep_lag4, NA_real_)]
cty <- merge(cty, cty_yr[, .(county, YEAR, county_dep_growth_t4_t1)],
             by = c("county", "YEAR"), all.x = TRUE)

cc <- setDT(readRDS(COUNTY_CTRL))
if (!"county" %in% names(cc) && "county_code" %in% names(cc)) setnames(cc, "county_code", "county")
if (!"YEAR"   %in% names(cc) && "year"        %in% names(cc)) setnames(cc, "year", "YEAR")
cc[, `:=`(county = str_pad(as.integer(county), 5, "left", "0"),
          YEAR   = as.integer(YEAR))]
ctrls_vars <- intersect(c("log_population_density", "lag_county_deposit_hhi",
                          "lag_establishment_gr", "lag_payroll_gr",
                          "lag_hmda_mtg_amt_gr", "lag_cra_loan_amount_amt_lt_1m_gr", "lmi"),
                        names(cc))
cty <- merge(cty, unique(cc[, c("county", "YEAR", ctrls_vars), with = FALSE]),
             by = c("county", "YEAR"), all.x = TRUE)
cty <- merge(cty, cra, by = c("county", "YEAR"), all.x = TRUE)

# ---- 2. County-level Nguyen instrument (zip→county at Ref_Year) ----
# Source: code/approach-merger-iv-20260424/data/nguyen_instrument_zips_20260424.rds
# Built by:   code/approach-merger-iv-20260424/03_build_merger_instrument.R
inst <- setDT(readRDS(dat_out("nguyen_instrument_zips_20260424")))
inst[, Ref_Year := Event_Year - 1L]

# Pull SOD ZIP→county at relevant Ref_Years from sod.duckdb.
ref_years <- unique(inst$Ref_Year)
sod <- open_sod()
zip_county <- setDT(dbGetQuery(sod, sprintf("
  SELECT DISTINCT ZIPBR,
         LPAD(CAST(STCNTYBR AS VARCHAR), 5, '0') AS county,
         YEAR AS yr
  FROM sod
  WHERE YEAR IN (%s)
", paste(ref_years, collapse = ","))))
dbDisconnect(sod, shutdown = TRUE)
zip_county[, ZIPBR := str_pad(ZIPBR, 5, "left", "0")]

inst_c <- merge(inst, zip_county,
                by.x = c("ZIPBR", "Ref_Year"),
                by.y = c("ZIPBR", "yr"),
                allow.cartesian = TRUE)
# Binary at county-year: any merger overlap zip in county that Event_Year.
inst_cy <- unique(inst_c[, .(county, YEAR = Event_Year, Expose_Event = 1L)])

cty <- merge(cty, inst_cy, by = c("county", "YEAR"), all.x = TRUE)
cty[is.na(Expose_Event), Expose_Event := 0L]

# ---- 3. IV second stage ----
ctrl <- ~ log_n_branches + log_n_banks + log1p_total_deps + county_dep_growth_t4_t1 +
          log_population_density + lag_county_deposit_hhi + lag_establishment_gr +
          lag_payroll_gr + lag_hmda_mtg_amt_gr + lag_cra_loan_amount_amt_lt_1m_gr + lmi

period_filter <- function(dt, p) switch(p,
  "2000-07" = dt[YEAR %between% c(2000, 2007)],
  "2008-11" = dt[YEAR %between% c(2008, 2011)],
  "2012-19" = dt[YEAR %between% c(2012, 2019)],
  "2020-23" = dt[YEAR %between% c(2020, 2023)])

periods <- c("2000-07", "2008-11", "2012-19", "2020-23")
dsets   <- setNames(lapply(periods, period_filter, dt = cty), periods)
dsets   <- lapply(dsets, function(d) d[!is.na(cra_growth_incty)])

run_iv <- function(d) tryCatch(feols(
  cra_growth_incty ~ .[ctrl] | county + state_yr | share_deps_closed ~ Expose_Event,
  data = d, vcov = ~county),
  error = function(e) { cat("  !", conditionMessage(e), "\n"); NULL })

mIV <- Filter(Negate(is.null), lapply(dsets, run_iv))
dsets_kept <- dsets[names(mIV)]

et <- etable(mIV, headers = names(mIV), tex = FALSE,
             fitstat = c("n", "r2", "ivf"),
             extralines = c(
               footer_mean_sd(dsets_kept, "cra_growth_incty", "share_deps_closed"),
               list("SD(Expose_Event)" =
                      sapply(dsets_kept, function(d) rnd(sd(d$Expose_Event, na.rm = TRUE))))
             ))
write_md(et, md_out("T_iv_cra_county"))
cat("Wrote T_iv_cra_county.md\n")

cat("\n### CRA county IV — outcome: cra_growth_incty\n\n")
cat("| Period | Coef (share_deps_closed) | SE | Sig | N | IV-F |\n",
    "|---|---|---|---|---|---|\n", sep = "")
for (p in names(mIV)) {
  m <- mIV[[p]]
  b <- coef(m)["fit_share_deps_closed"]; s <- se(m)["fit_share_deps_closed"]
  pv <- pvalue(m)["fit_share_deps_closed"]
  sig <- ifelse(pv < 0.01, "***", ifelse(pv < 0.05, "**", ifelse(pv < 0.1, "*", "")))
  f <- tryCatch(fitstat(m, "ivf")$ivf1$stat, error = function(e) NA_real_)
  cat(sprintf("| %s | %s | %s | %s | %s | %s |\n",
              p, rnd(b), rnd(s), sig,
              format(nobs(m), big.mark = ","),
              rnd(f, 1)))
}
