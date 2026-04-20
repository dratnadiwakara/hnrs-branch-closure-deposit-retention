rm(list = ls())
library(data.table); library(fixest)
setFixest_etable(signif.code=c("***"=0.01,"**"=0.05,"*"=0.1), se.below=TRUE)
setFixest_fml(
  ..fixef    = ~ bank_id^YEAR + county^YEAR,
  ..controls = ~ log1p(total_deps_bank_county_t1) +
    log1p(n_remaining_branches) + mkt_share_county_t1
)
reg_files <- list.files("data", pattern="^reg_main_\\d{8}\\.rds$", full.names=TRUE)
reg_main  <- setDT(readRDS(reg_files[which.max(file.mtime(reg_files))]))

d_post <- reg_main[YEAR >= 2012]
d_1219 <- reg_main[YEAR %between% c(2012,2019)]
d_1419 <- reg_main[YEAR %between% c(2014,2019)]

cat("=== TABLE E: combined — bank-type + mobile + sophisticated (2012+) ===\n")
r_comb <- list(
  "2012-2024" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:top4_bank +
                        closure_share:large_bank +
                        closure_share:perc_hh_wMobileSub +
                        closure_share:sophisticated + ..controls | ..fixef,
                      data=d_post, vcov=~bank_id),
  "2012-2019" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:top4_bank +
                        closure_share:large_bank +
                        closure_share:perc_hh_wMobileSub +
                        closure_share:sophisticated + ..controls | ..fixef,
                      data=d_1219, vcov=~bank_id),
  "2014-2019" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:top4_bank +
                        closure_share:large_bank +
                        closure_share:perc_hh_wMobileSub +
                        closure_share:sophisticated + ..controls | ..fixef,
                      data=d_1419, vcov=~bank_id)
)
etable(r_comb,
  order=c("closure_share$","closure_share:top4","closure_share:large",
          "closure_share:perc","closure_share:soph"))
