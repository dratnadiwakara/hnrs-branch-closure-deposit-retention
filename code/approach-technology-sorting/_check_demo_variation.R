library(data.table)
dt <- setDT(readRDS("C:/Users/dimut/OneDrive/data/nrs_branch_closure/zip_demographics_panel.rds"))

# Check within-zip variation (after zip FE, only time variation matters)
vars <- c("median_income", "median_age", "pct_college_educated",
          "capital_gain_frac", "dividend_frac")

dt[, zip := as.character(zip)]

for (v in vars) {
  within_sd <- dt[, .(sd = sd(get(v), na.rm = TRUE)), by = zip][, mean(sd, na.rm = TRUE)]
  overall_sd <- sd(dt[[v]], na.rm = TRUE)
  pct_missing <- mean(is.na(dt[[v]]))
  cat(sprintf("%-25s within_sd=%6.4f  overall_sd=%6.4f  pct_missing=%.3f\n",
              v, within_sd, overall_sd, pct_missing))
}

# Year coverage check
cat("\nYear range per variable:\n")
for (v in vars) {
  yrs <- dt[!is.na(get(v)), range(yr)]
  cat(sprintf("%-25s %d - %d\n", v, yrs[1], yrs[2]))
}
