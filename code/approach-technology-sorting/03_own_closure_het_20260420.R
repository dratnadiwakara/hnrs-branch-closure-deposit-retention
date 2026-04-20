rm(list = ls())
library(data.table)
library(fixest)

setFixest_etable(signif.code = c("***"=0.01,"**"=0.05,"*"=0.1), se.below=TRUE)
setFixest_fml(
  ..fixef    = ~ bank_id^YEAR + county^YEAR,
  ..controls = ~ log1p(total_deps_bank_county_t1) +
    log1p(n_remaining_branches) +
    mkt_share_county_t1
)

# ── Load ──────────────────────────────────────────────────────────────────────
reg_files <- list.files("data", pattern="^reg_main_\\d{8}\\.rds$", full.names=TRUE)
if (!length(reg_files)) stop("No reg_main_*.rds found in data/")
reg_main <- setDT(readRDS(reg_files[which.max(file.mtime(reg_files))]))
message("Loaded: ", basename(reg_files[which.max(file.mtime(reg_files))]),
        " — N = ", nrow(reg_main))

# Check variables
cat("sophisticated:", sum(!is.na(reg_main$sophisticated)), "non-NA\n")
cat("perc_hh_wMobileSub:", sum(!is.na(reg_main$perc_hh_wMobileSub)), "non-NA\n")
cat("Years:", min(reg_main$YEAR), "-", max(reg_main$YEAR), "\n")
cat("N by period: pre-2012:", reg_main[YEAR<2012,.N],
    "| 2012-13:", reg_main[YEAR %between% c(2012,2013),.N],
    "| 2014-19:", reg_main[YEAR %between% c(2014,2019),.N],
    "| 2020-24:", reg_main[YEAR %between% c(2020,2024),.N], "\n\n")

# Period subsets
d_pre  <- reg_main[YEAR < 2012]
d_1213 <- reg_main[YEAR %between% c(2012, 2013)]
d_1419 <- reg_main[YEAR %between% c(2014, 2019)]
d_1219 <- reg_main[YEAR %between% c(2012, 2019)]
d_post <- reg_main[YEAR >= 2012]
d_2024 <- reg_main[YEAR %between% c(2020, 2024)]

cat("=== TABLE A: Baseline replication (confirm matches Table 7 in snapshot) ===\n")
r_base <- list(
  "Pre-2012"  = feols(growth_on_total_t1 ~ closure_share + ..controls | ..fixef,
                      data=d_pre, vcov=~bank_id),
  "2012-2024" = feols(growth_on_total_t1 ~ closure_share + ..controls | ..fixef,
                      data=d_post, vcov=~bank_id),
  "2012-2019" = feols(growth_on_total_t1 ~ closure_share + ..controls | ..fixef,
                      data=d_1219, vcov=~bank_id)
)
etable(r_base)

cat("\n=== TABLE B: closure_share x sophisticated ===\n")
cat("NOTE: sophisticated main effect absorbed by county^YEAR FE\n")
cat("Interaction identified from within-county-year bank variation in closure_share\n\n")

r_soph <- list(
  "Pre-2012"  = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:sophisticated + ..controls | ..fixef,
                      data=d_pre, vcov=~bank_id),
  "2012-2024" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:sophisticated + ..controls | ..fixef,
                      data=d_post, vcov=~bank_id),
  "2012-2019" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:sophisticated + ..controls | ..fixef,
                      data=d_1219, vcov=~bank_id),
  "2020-2024" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:sophisticated + ..controls | ..fixef,
                      data=d_2024, vcov=~bank_id)
)
etable(r_soph, order=c("closure_share$","closure_share:soph"))

cat("\n=== TABLE C: closure_share x sophisticated, 2012-13 / 2014-19 split ===\n")
r_soph_split <- list(
  "Pre-2012"  = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:sophisticated + ..controls | ..fixef,
                      data=d_pre, vcov=~bank_id),
  "2012-2013" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:sophisticated + ..controls | ..fixef,
                      data=d_1213, vcov=~bank_id),
  "2014-2019" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:sophisticated + ..controls | ..fixef,
                      data=d_1419, vcov=~bank_id),
  "2020-2024" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:sophisticated + ..controls | ..fixef,
                      data=d_2024, vcov=~bank_id)
)
etable(r_soph_split, order=c("closure_share$","closure_share:soph"))

cat("\n=== TABLE D: closure_share x perc_hh_wMobileSub ===\n")
cat("NOTE: perc_hh_wMobileSub main effect absorbed by county^YEAR FE\n\n")

r_mob <- list(
  "2012-2024" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:perc_hh_wMobileSub + ..controls | ..fixef,
                      data=d_post, vcov=~bank_id),
  "2012-2019" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:perc_hh_wMobileSub + ..controls | ..fixef,
                      data=d_1219, vcov=~bank_id),
  "2020-2024" = feols(growth_on_total_t1 ~ closure_share +
                        closure_share:perc_hh_wMobileSub + ..controls | ..fixef,
                      data=d_2024, vcov=~bank_id)
)
etable(r_mob, order=c("closure_share$","closure_share:perc"))

cat("\n=== TABLE E: combined — bank-type + mobile + sophisticated (2012+) ===\n")
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

cat("\n=== DIAGNOSTICS: variation in sophisticated within county-year ===\n")
# Check how much within-county-year variation in closure_share exists
# conditional on sophisticated — this drives identification
diag <- reg_main[!is.na(sophisticated) & YEAR >= 2012,
                 .(n_banks=.N,
                   sd_closure=sd(closure_share,na.rm=TRUE),
                   mean_closure=mean(closure_share,na.rm=TRUE)),
                 by=.(county,YEAR,sophisticated)]
cat("Mean within-county-year SD of closure_share by sophistication:\n")
print(diag[, .(mean_sd=mean(sd_closure,na.rm=TRUE),
               n_groups=.N), by=sophisticated])

cat("\n=== DIAGNOSTICS: county-year cells with both soph/unsoph banks ===\n")
mixed <- reg_main[!is.na(sophisticated) & YEAR>=2012,
                  .(n_soph=sum(sophisticated==1,na.rm=TRUE),
                    n_unsoph=sum(sophisticated==0,na.rm=TRUE)),
                  by=.(county,YEAR)]
cat("County-years with both soph and unsoph banks:",
    mixed[n_soph>0 & n_unsoph>0, .N], "/", nrow(mixed), "\n")
