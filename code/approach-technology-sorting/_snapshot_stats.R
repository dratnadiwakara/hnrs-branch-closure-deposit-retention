rm(list = ls())
library(data.table)

sample_files <- list.files("data", pattern = "^zip_tech_sample_\\d{8}\\.rds$", full.names = TRUE)
dt <- setDT(readRDS(sample_files[which.max(file.mtime(sample_files))]))
dt[, soph_zip := mean(sophisticated, na.rm = TRUE) >= 0.5, by = zip]

d0007 <- dt[YEAR %between% c(2000, 2007)]
d0811 <- dt[YEAR %between% c(2008, 2011)]
d1219 <- dt[YEAR %between% c(2012, 2019)]
d2024 <- dt[YEAR %between% c(2020, 2024)]
d_post <- dt[YEAR >= 2012]

# Regression sample: drop NAs in all RHS vars used across tables
base_vars   <- c("outcome","share_deps_closed","log_n_branches","log_n_inc_banks",
                 "log_total_deps","dep_growth_t3t1","zip","county_yr")
mob_vars    <- c(base_vars, "perc_hh_wMobileSub")
soph_vars   <- c(base_vars, "sophisticated")

reg_sample <- function(data, vars) data[complete.cases(data[, ..vars])]

stats <- function(data, vars, treat) {
  s <- reg_sample(data, vars)
  cat(sprintf("  N=%d  Mean(outcome)=%.4f  SD(%s)=%.4f\n",
              nrow(s), mean(s$outcome, na.rm=TRUE),
              treat, sd(s[[treat]], na.rm=TRUE)))
}

cat("\n=== Tables 1, 2, 3, 6 (base_vars or soph_vars) ===\n")
for (nm in c("2000-07","2008-11","2012-19","2020-24")) {
  d <- list(d0007,d0811,d1219,d2024)[[match(nm,c("2000-07","2008-11","2012-19","2020-24"))]]
  cat(nm, "(base):\n"); stats(d, base_vars, "share_deps_closed")
  cat(nm, "(soph):\n"); stats(d, soph_vars, "share_deps_closed")
}

cat("\n=== Table 4 mobile ===\n")
cat("2012-24:\n"); stats(d_post, mob_vars, "share_deps_closed")
cat("2012-19:\n"); stats(d1219,  mob_vars, "share_deps_closed")
cat("2020-24:\n"); stats(d2024,  mob_vars, "share_deps_closed")

cat("\n=== Table 5 combined ===\n")
comb_vars <- c(base_vars, "share_deps_closed_app","share_deps_closed_noapp",
               "share_deps_closed_top4","perc_hh_wMobileSub")
cat("2012-24:\n"); stats(d_post, comb_vars, "share_deps_closed")
cat("2012-19:\n"); stats(d1219,  comb_vars, "share_deps_closed")
