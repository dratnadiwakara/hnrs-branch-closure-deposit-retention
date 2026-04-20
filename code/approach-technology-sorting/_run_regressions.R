## -----------------------------------------------------------------------------
rm(list = ls())

library(data.table)
library(fixest)
library(here)

save_tables <- TRUE
dat_suffix  <- format(Sys.time(), "%Y%m%d_%H%M%S")

setFixest_etable(
  signif.code = c("***" = 0.01, "**" = 0.05, "*" = 0.1),
  se.below = TRUE
)

tex_out <- function(filename) {
  file.path("latex", "tables", paste0(filename, "_", dat_suffix, ".tex"))
}


## -----------------------------------------------------------------------------
sample_files <- list.files("data", pattern = "^zip_tech_sample_\\d{8}\\.rds$",
                           full.names = TRUE)
if (!length(sample_files)) stop("Run 01_build_zip_tech_sample_20260419.R first.")
dt <- setDT(readRDS(sample_files[which.max(file.mtime(sample_files))]))
message("Loaded: ", basename(sample_files[which.max(file.mtime(sample_files))]),
        " — N = ", nrow(dt))


## -----------------------------------------------------------------------------
# Zip-level sophistication: majority-year classification (must precede period splits)
dt[, soph_zip := mean(sophisticated, na.rm = TRUE) >= 0.5, by = zip]

d0007 <- dt[YEAR %between% c(2000, 2007)]
d0811 <- dt[YEAR %between% c(2008, 2011)]
d1213 <- dt[YEAR %between% c(2012, 2013)]
d1419 <- dt[YEAR %between% c(2014, 2019)]
d1219 <- dt[YEAR %between% c(2012, 2019)]
d2024 <- dt[YEAR %between% c(2020, 2024)]

d_pre  <- dt[YEAR < 2012]
d_post <- dt[YEAR >= 2012]


## ----tbl1-baseline------------------------------------------------------------
run_base <- function(data) feols(
  outcome ~ share_deps_closed + log_n_branches + log_n_inc_banks +
    log_total_deps + dep_growth_t3t1 | zip + county_yr,
  data = data, vcov = ~zip
)

r_base <- list(
  "2000–07" = run_base(d0007),
  "2008–11" = run_base(d0811),
  "2012–19" = run_base(d1219),
  "2020–24" = run_base(d2024)
)

etable(r_base, headers = list("Period" = 4))

# Summary stats for snapshot
for (nm in names(r_base)) {
  d <- list(d0007, d0811, d1219, d2024)[[match(nm, names(r_base))]]
  cat(nm, "| Mean(outcome):", round(mean(d$outcome, na.rm=TRUE), 4),
      "| SD(share_deps_closed):", round(sd(d$share_deps_closed, na.rm=TRUE), 4), "\n")
}

if (save_tables) writeLines(etable(r_base, tex=TRUE, headers=list("Period"=4)), tex_out("zip_tech_tbl1_baseline"))


## ----tbl2-size----------------------------------------------------------------
run_size <- function(data) feols(
  outcome ~ share_deps_closed_top4 + share_deps_closed_large + share_deps_closed_small +
    log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1 | zip + county_yr,
  data = data, vcov = ~zip
)

r_size <- list(
  "2000–07" = run_size(d0007),
  "2008–11" = run_size(d0811),
  "2012–19" = run_size(d1219),
  "2020–24" = run_size(d2024)
)

etable(r_size,
  order = c("share_deps_closed_top4", "share_deps_closed_large", "share_deps_closed_small"))

if (save_tables) writeLines(etable(r_size, tex=TRUE, order=c("share_deps_closed_top4","share_deps_closed_large","share_deps_closed_small")), tex_out("zip_tech_tbl2_size"))


## ----tbl3-app-----------------------------------------------------------------
run_app <- function(data) feols(
  outcome ~ share_deps_closed_app + share_deps_closed_noapp +
    log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1 | zip + county_yr,
  data = data, vcov = ~zip
)

r_app <- list(
  "2000–07" = run_app(d0007),
  "2008–11" = run_app(d0811),
  "2012–19" = run_app(d1219),
  "2020–24" = run_app(d2024)
)

etable(r_app,
  order = c("share_deps_closed_app", "share_deps_closed_noapp"))

if (save_tables) writeLines(etable(r_app, tex=TRUE, order=c("share_deps_closed_app","share_deps_closed_noapp")), tex_out("zip_tech_tbl3_app"))


## ----tbl4-mobile--------------------------------------------------------------
run_mob <- function(data) feols(
  outcome ~ share_deps_closed + share_deps_closed:perc_hh_wMobileSub +
    perc_hh_wMobileSub + log_n_branches + log_n_inc_banks +
    log_total_deps + dep_growth_t3t1 | zip + county_yr,
  data = data, vcov = ~zip
)

r_mob <- list(
  "2012–2024" = run_mob(d_post),
  "2012–2019" = run_mob(d1219),
  "2020–2024" = run_mob(d2024)
)

etable(r_mob,
  order = c("share_deps_closed$", "share_deps_closed:perc", "perc_hh"))

if (save_tables) writeLines(etable(r_mob, tex=TRUE, order=c("share_deps_closed$","share_deps_closed:perc","perc_hh")), tex_out("zip_tech_tbl4_mobile"))


## ----tbl5-combined------------------------------------------------------------
r_comb <- list(
  "2012–2024" = feols(
    outcome ~ share_deps_closed_app + share_deps_closed_noapp +
      share_deps_closed_top4 +
      share_deps_closed:perc_hh_wMobileSub +
      perc_hh_wMobileSub +
      log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1 | zip + county_yr,
    data = d_post, vcov = ~zip
  ),
  "2012–2019" = feols(
    outcome ~ share_deps_closed_app + share_deps_closed_noapp +
      share_deps_closed_top4 +
      share_deps_closed:perc_hh_wMobileSub +
      perc_hh_wMobileSub +
      log_n_branches + log_n_inc_banks + log_total_deps + dep_growth_t3t1 | zip + county_yr,
    data = d1219, vcov = ~zip
  )
)

etable(r_comb,
  order = c("share_deps_closed_app", "share_deps_closed_noapp",
            "share_deps_closed_top4", "share_deps_closed:perc", "perc_hh"))

# if (save_tables) writeLines(etable(r_comb, tex=TRUE, order=c("share_deps_closed_app","share_deps_closed_noapp","share_deps_closed_top4","share_deps_closed:perc","perc_hh")), tex_out("zip_tech_tbl5_combined"))


## ----tbl6-soph----------------------------------------------------------------
run_soph_int <- function(data) feols(
  outcome ~ share_deps_closed + share_deps_closed:sophisticated +
    sophisticated + log_n_branches + log_n_inc_banks +
    log_total_deps + dep_growth_t3t1 | zip + county_yr,
  data = data, vcov = ~zip
)

r_soph <- list(
  "2000–07" = run_soph_int(d0007),
  "2008–11" = run_soph_int(d0811),
  "2012–13" = run_soph_int(d1213),
  "2014–19" = run_soph_int(d1419),
  "2020–24" = run_soph_int(d2024)
)

etable(r_soph,
  order = c("share_deps_closed$", "share_deps_closed:soph", "sophisticated$"))

if (save_tables) writeLines(
  etable(r_soph, tex = TRUE,
         order = c("share_deps_closed$", "share_deps_closed:soph", "sophisticated$")),
  tex_out("zip_tech_tbl6_soph")
)

