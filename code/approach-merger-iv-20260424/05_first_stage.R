# 05_first_stage.R
# First stage: share_deps_closed ~ Expose_Event + controls | zip + YEAR.
# Mirrors Nguyen_instrument_v1.1.qmd lines 306-320.

rm(list = ls())
source("code/approach-merger-iv-20260424/00_common.R")

# Source: data/zip_tech_sample_YYYYMMDD.rds
# Built by:   code/approach-technology-sorting/01_build_zip_tech_sample_20260419.R
# Contents:   zip-year panel with incumbent `outcome`, `share_deps_closed`,
#             `branches_lag1`, `n_inc_banks`, `sophisticated`, `county_yr`.
dt <- setDT(load_latest("data", "^zip_tech_sample_\\d{8}\\.rds$"))
dt[, zip := str_pad(as.character(zip), 5, "left", "0")]

# Source: code/approach-merger-iv-20260424/data/nguyen_instrument_zips_20260424.rds
# Built by:   code/approach-merger-iv-20260424/03_build_merger_instrument.R
inst <- setDT(readRDS(dat_out("nguyen_instrument_zips_20260424")))
inst_zy <- unique(inst[, .(zip = ZIPBR, YEAR = Event_Year, Expose_Event = 1L)])

dt <- merge(dt, inst_zy, by = c("zip", "YEAR"), all.x = TRUE)
dt[is.na(Expose_Event), Expose_Event := 0L]

# Sample: at least 2 branches lag1, at least 2 incumbent banks (Nguyen qmd filter).
smp <- dt[branches_lag1 >= 2 & n_inc_banks >= 2]

fs <- list()
fs[["Full"]]      <- feols(share_deps_closed ~ Expose_Event + log1p(branches_lag1) |
                             zip + YEAR, cluster = ~zip, data = smp)
fs[["Share > 0"]] <- feols(share_deps_closed ~ Expose_Event + log1p(branches_lag1) |
                             zip + YEAR, cluster = ~zip,
                           data = smp[share_deps_closed > 0])

et <- etable(fs, fitstat = c("n", "r2", "f"),
             headers = c("Full Sample", "Share > 0"),
             tex = FALSE,
             extralines = list(
               "Mean(share_deps_closed)" = c(rnd(mean(smp$share_deps_closed, na.rm = TRUE)),
                                             rnd(mean(smp[share_deps_closed > 0]$share_deps_closed, na.rm = TRUE))),
               "SD(Expose_Event)"        = c(rnd(sd(smp$Expose_Event, na.rm = TRUE)),
                                             rnd(sd(smp[share_deps_closed > 0]$Expose_Event, na.rm = TRUE)))
             ))
write_md(et, md_out("T_first_stage"))

# Chat summary
cat("\n### First-stage key coefficients\n\n")
cat("| Outcome | Coef | SE | Sig | N |\n|---|---|---|---|---|\n")
for (nm in names(fs)) {
  m <- fs[[nm]]
  b <- coef(m)["Expose_Event"]; s <- se(m)["Expose_Event"]
  p <- pvalue(m)["Expose_Event"]
  sig <- ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", "")))
  cat(sprintf("| share_deps_closed (%s) | %s | %s | %s | %s |\n",
              nm, rnd(b), rnd(s), sig, format(nobs(m), big.mark=",")))
}
cat("\nF(Expose_Event) full sample:",
    rnd(fitstat(fs[["Full"]], "f")$f$stat),
    "| share>0:",
    rnd(fitstat(fs[["Share > 0"]], "f")$f$stat), "\n")
