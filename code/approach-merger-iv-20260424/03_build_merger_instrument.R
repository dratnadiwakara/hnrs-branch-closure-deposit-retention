# 03_build_merger_instrument.R
# Build Nguyen (2019) merger-overlap instrument: ZIP-year pairs where both
# merger-party banks had branches in the ZIP the year before a large merger.
#
# Logic: for each (SUCC_RSSD, PRED_RSSD, Merger_Year) with TRNSFM_CD='1' and
# both parties having >= $10B assets in Ref_Year = Merger_Year-1, find ZIPs
# where both parties had SOD branches at Ref_Year.  Event_Year = Merger_Year.

rm(list = ls())
source("code/approach-merger-iv-20260424/00_common.R")

# ---- 1. Mergers from NIC transformations ----

nic <- open_nic()
mergers <- setDT(dbGetQuery(nic, '
  SELECT CAST("#ID_RSSD_PREDECESSOR" AS BIGINT) AS PRED_RSSD,
         ID_RSSD_SUCCESSOR                     AS SUCC_RSSD,
         DT_TRANS,
         CAST(SUBSTR(DT_TRANS,1,4) AS INT)     AS Merger_Year
  FROM transformations
  WHERE TRNSFM_CD = \'1\'
    AND CAST(SUBSTR(DT_TRANS,1,4) AS INT) BETWEEN 2001 AND 2024
'))
dbDisconnect(nic, shutdown = TRUE)

mergers <- mergers[!is.na(PRED_RSSD) & !is.na(SUCC_RSSD) & PRED_RSSD != SUCC_RSSD]
mergers[, Ref_Year := Merger_Year - 1]
mergers[, TRANSNUM := paste(DT_TRANS, PRED_RSSD, SUCC_RSSD, sep = "_")]

n_all <- nrow(mergers)
cat("NIC TRNSFM_CD='1' 2001-2024:", n_all, "rows\n")

# ---- 2. Large-merger filter ($10B, both sides) ----

sod <- open_sod()
on.exit(dbDisconnect(sod, shutdown = TRUE), add = TRUE)

bank_assets <- setDT(dbGetQuery(sod, "
  SELECT RSSDID AS rssd, YEAR AS yr, MAX(ASSET) AS asset_max
  FROM sod
  WHERE YEAR BETWEEN 2000 AND 2024
  GROUP BY RSSDID, YEAR
"))

mergers <- merge(mergers, bank_assets, by.x = c("SUCC_RSSD", "Ref_Year"),
                 by.y = c("rssd", "yr"), all.x = TRUE)
setnames(mergers, "asset_max", "Buyer_Assets")
mergers <- merge(mergers, bank_assets, by.x = c("PRED_RSSD", "Ref_Year"),
                 by.y = c("rssd", "yr"), all.x = TRUE)
setnames(mergers, "asset_max", "Target_Assets")

large <- mergers[Buyer_Assets >= 1e7 & Target_Assets >= 1e7]
large <- unique(large, by = c("SUCC_RSSD", "PRED_RSSD", "Ref_Year"))
n_large <- nrow(large)
cat("After $10B filter (SOD asset in $000s -> cutoff 1e7):", n_large, "mergers\n")

# ---- 3. Branch locations at Ref_Year (both parties) ----

# Pull SOD ZIPs for (RSSDID, YEAR) pairs appearing as buyer or target at Ref_Year.
ref_rssds <- unique(c(large$SUCC_RSSD, large$PRED_RSSD))
ref_years <- unique(large$Ref_Year)
sod_sub <- setDT(dbGetQuery(sod, sprintf("
  SELECT RSSDID AS rssd, YEAR AS yr, ZIPBR
  FROM sod
  WHERE YEAR IN (%s)
    AND RSSDID IN (%s)
", paste(ref_years, collapse = ","),
   paste(ref_rssds, collapse = ","))))
sod_sub[, ZIPBR := str_pad(ZIPBR, 5, "left", "0")]
sod_sub <- unique(sod_sub, by = c("rssd", "yr", "ZIPBR"))

buyer_locs <- merge(large[, .(SUCC_RSSD, PRED_RSSD, Ref_Year, TRANSNUM, Merger_Year)],
                    sod_sub, by.x = c("SUCC_RSSD", "Ref_Year"),
                    by.y = c("rssd", "yr"), allow.cartesian = TRUE)
setnames(buyer_locs, "ZIPBR", "Buyer_Zip")

target_locs <- merge(large[, .(SUCC_RSSD, PRED_RSSD, Ref_Year, TRANSNUM, Merger_Year)],
                     sod_sub, by.x = c("PRED_RSSD", "Ref_Year"),
                     by.y = c("rssd", "yr"), allow.cartesian = TRUE)
setnames(target_locs, "ZIPBR", "Target_Zip")

# ---- 4. Overlap = inner join on (TRANSNUM, ZIP) ----

overlap <- merge(buyer_locs[, .(TRANSNUM, Merger_Year, SUCC_RSSD, PRED_RSSD, ZIPBR = Buyer_Zip)],
                 target_locs[, .(TRANSNUM, ZIPBR = Target_Zip)],
                 by = c("TRANSNUM", "ZIPBR"))

final_instrument <- unique(overlap[, .(ZIPBR,
                                       Event_Year = Merger_Year,
                                       Merger_TransNum = TRANSNUM,
                                       Buyer_RSSD = SUCC_RSSD,
                                       Target_RSSD = PRED_RSSD)])

saveRDS(final_instrument, dat_out("nguyen_instrument_zips_20260424"))

cat("Treated ZIP-merger rows:", nrow(final_instrument), "\n")
cat("Distinct treated (ZIP, Event_Year):",
    nrow(unique(final_instrument, by = c("ZIPBR", "Event_Year"))), "\n")

evt_hist <- final_instrument[, .N, by = Event_Year][order(Event_Year)]
evt_hist_all <- final_instrument[, .(event_yr = Event_Year)][,
   .N, by = .(bucket = cut(event_yr, breaks = c(1999,2004,2009,2014,2019,2025),
                           labels = c("2000-04","2005-09","2010-14","2015-19","2020-24"),
                           include.lowest = TRUE))][order(bucket)]

md <- c(
  paste0("# Instrument build (", format(Sys.time(), "%Y-%m-%d"), ")"),
  "",
  paste0("- NIC TRNSFM_CD='1' mergers 2001-2024: ", n_all),
  paste0("- After $10B asset filter (both sides): ", n_large),
  paste0("- Treated (ZIP, Event_Year, TRANSNUM) rows: ", nrow(final_instrument)),
  paste0("- Distinct treated (ZIP, Event_Year): ",
         nrow(unique(final_instrument, by = c("ZIPBR", "Event_Year")))),
  "",
  "## Treated rows by Event_Year",
  "",
  knitr::kable(evt_hist, format = "pipe"),
  "",
  "## 5-year Event_Year buckets",
  "",
  knitr::kable(evt_hist_all, format = "pipe")
)
writeLines(md, log_out("instrument_build_20260424"))

cat("\nEvent_Year buckets:\n"); print(evt_hist_all)
