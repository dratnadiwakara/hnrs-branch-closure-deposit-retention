rm(list = ls())
library(data.table)
sample_files <- list.files("data", pattern="^zip_tech_sample_\\d{8}\\.rds$", full.names=TRUE)
dt <- setDT(readRDS(sample_files[which.max(file.mtime(sample_files))]))

vars <- c("outcome","share_deps_closed","log_n_branches","log_n_inc_banks",
          "log_total_deps","dep_growth_t3t1","sophisticated","zip","county_yr")

for (nm in list(c("2012-13",2012,2013), c("2014-19",2014,2019))) {
  d <- dt[YEAR %between% c(nm[[2]], nm[[3]])]
  s <- d[complete.cases(d[, ..vars])]
  cat(sprintf("%s: N=%d  Mean(outcome)=%.4f  SD(share_deps_closed)=%.4f\n",
              nm[[1]], nrow(s), mean(s$outcome,na.rm=TRUE), sd(s$share_deps_closed,na.rm=TRUE)))
}
