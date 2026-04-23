# 05_own_closure.R — snapshot §12 (own-closure deposit retention, bank-zip-year).
# Baseline spec: growth_on_total_t1 ~ closure_share + controls | bank×YEAR + zip×YEAR.
# Periods: All, Pre-2012, 2012-19, 2020-22, 2023-24.

rm(list = ls())
source("code/approach-streamlined-20260423/00_common.R")

# Source: data/reg_main_zip_YYYYMMDD.rds
# Built by:   code/approach-technology-sorting/04_build_bank_zip_year_sample_20260420.R
# Contents:   bank-zip-year panel for own-closure design. Key cols:
#             growth_on_total_t1 (LHS), closure_share (treatment),
#             total_deps_bank_zip_t1, n_remaining_branches, mkt_share_zip_t1,
#             top4_bank, large_bank, perc_hh_wMobileSub. M&A-related closures
#             excluded; top-5% extreme intensity winsorized upstream.
reg <- setDT(load_latest("data", "^reg_main_zip_\\d{8}\\.rds$"))

dsets <- list(
  "All"      = reg,
  "Pre-2012" = reg[YEAR < 2012],
  "2012-19"  = reg[YEAR %between% c(2012, 2019)],
  "2020-22"  = reg[YEAR %between% c(2020, 2022)],
  "2023-24"  = reg[YEAR %between% c(2023, 2024)]
)

run <- function(d) feols(
  growth_on_total_t1 ~ closure_share + log1p(total_deps_bank_zip_t1)
  + log1p(n_remaining_branches) + mkt_share_zip_t1
  | bank_id^YEAR + zip^YEAR,
  data = d, vcov = ~bank_id)

m <- lapply(dsets, run)
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = footer_mean_sd(dsets, "growth_on_total_t1", "closure_share")),
         md_out("T4_own_closure_baseline"))

cat("=== §12 Own-closure ===\n"); etable(m, headers = names(m))
