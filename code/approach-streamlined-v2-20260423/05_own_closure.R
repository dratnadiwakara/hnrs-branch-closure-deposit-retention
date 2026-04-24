# 05_own_closure.R — v2 section 13.
# Own-closure deposit retention at bank x zip x YEAR.
# Filters are flags on the v2 panel (S3); each spec toggles them explicitly.
# Spec matrix (columns):
#   (1) paper = minimal clean sample
#         drop_extreme == YES, drop_MA_closure == YES, require_clean_control == YES
#   (2) -extreme          (keep top-5%/<1% intensity closures)
#   (3) -cleanctrl        (keep all non-closure obs, not only delta_branches=0)
#   (4) -both             (only drop M&A closures)
#   (5) raw               (no discretionary filters — minimal analysis filter only)
# Period panels (Pre-2012, 2012-19, 2020-22, 2023-24) generated for spec (1).

rm(list = ls())
source("code/approach-streamlined-v2-20260423/00_common.R")

# Source: data/constructed/bank_zip_sample_v2_YYYYMMDD.rds
# Built by:   sample-construction/S3_build_bank_zip_sample.R
# Contents:   bank-zip-year panel; discretionary filters as FLAGS.
BZP <- resolve_latest("data/constructed", "^bank_zip_sample_v2_\\d{8}\\.rds$")
reg <- setDT(load_exact(BZP))

apply_filters <- function(d, drop_extreme = TRUE, drop_MA = TRUE, require_clean_ctrl = TRUE) {
  out <- copy(d)
  if (drop_extreme)
    out <- out[extreme_intensity_pctl == 0L]
  if (drop_MA)
    out <- out[(any_closure_t == 1L & any_closure_prev_owner_other_3y == 0L) |
               any_closure_t == 0L]
  if (require_clean_ctrl)
    out <- out[(any_closure_t == 1L) |
               (any_closure_t == 0L & clean_no_change_if_no_closure == 1L)]
  out
}

run_base <- function(d) feols(
  growth_on_total_t1 ~ closure_share + log1p(total_deps_bank_zip_t1)
    + log1p(n_remaining_branches) + mkt_share_zip_t1
    | bank_id^YEAR + zip^YEAR,
  data = d, vcov = ~bank_id)

# ---- Spec matrix (column headers) ------------------------------------------
specs <- list(
  "(1) paper"       = apply_filters(reg, TRUE,  TRUE,  TRUE),
  "(2) -extreme"    = apply_filters(reg, FALSE, TRUE,  TRUE),
  "(3) -cleanctrl"  = apply_filters(reg, TRUE,  TRUE,  FALSE),
  "(4) -both"       = apply_filters(reg, FALSE, TRUE,  FALSE),
  "(5) raw"         = apply_filters(reg, FALSE, FALSE, FALSE)
)

m <- lapply(specs, run_base)
write_md(etable(m, headers = names(m), tex = FALSE,
                extralines = list(
                  "Mean(growth)"    = sapply(specs, function(d) rnd(mean(d$growth_on_total_t1, na.rm = TRUE))),
                  "SD(closure_share)" = sapply(specs, function(d) rnd(sd(d$closure_share, na.rm = TRUE))),
                  "N_treated"       = sapply(specs, function(d) format(sum(d$any_closure_t == 1L), big.mark=",")),
                  "N_control"       = sapply(specs, function(d) format(sum(d$any_closure_t == 0L), big.mark=","))
                )),
         md_out("T13_own_closure_filter_matrix"))

# ---- Spec (1) across periods -----------------------------------------------
paper <- specs[["(1) paper"]]
dsets <- list(
  "All"      = paper,
  "Pre-2012" = paper[YEAR < 2012],
  "2012-19"  = paper[YEAR %between% c(2012, 2019)],
  "2020-22"  = paper[YEAR %between% c(2020, 2022)],
  "2023-24"  = paper[YEAR %between% c(2023, 2024)]
)
m_p <- lapply(dsets, run_base)
write_md(etable(m_p, headers = names(m_p), tex = FALSE,
                extralines = footer_mean_sd(dsets, "growth_on_total_t1", "closure_share")),
         md_out("T13_own_closure_paper_periods"))

register_outputs(c("T13_own_closure_filter_matrix.md",
                   "T13_own_closure_paper_periods.md"))
cat("Wrote T13 filter-matrix + period panels to tables/\n")
