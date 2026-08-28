# Generates inst/extdata example files mimicking real instrument exports:
# - biotek_gen5.csv: BioTek Gen5 kinetic export layout (validated against a
#   real Synergy H1 export) - metadata header, then per-read blocks with
#   Time | T° | A1..H12 columns; time as Excel day-fractions.
# - tecan_icontrol.csv: Tecan i-control kinetic layout (validated against a
#   real export) - transposed: Cycle Nr. / Time [s] / Temp. rows, then one
#   row per well.
# Both carry the same synthetic 96-well growth data as the generic examples.

set.seed(42)
times_h <- seq(0, 24, by = 0.5)
wells <- as.vector(t(outer(LETTERS[1:8], 1:12, paste0)))
edge <- wells[substr(wells, 1, 1) %in% c("A", "H") |
                as.integer(sub("^[A-H]", "", wells)) %in% c(1, 12)]
curve <- function(w) {
  if (w %in% c("C5", "F8")) {
    v <- 0.05 + rnorm(length(times_h), 0, 0.003)
  } else {
    K <- 1.2 * runif(1, 0.95, 1.05)
    v <- 0.05 + K / (1 + exp(-0.6 * (times_h - 8))) +
      rnorm(length(times_h), 0, 0.003)
  }
  if (w %in% c("B3", "D10", "G6")) v[16] <- v[16] + 0.4
  if (w %in% edge) v <- v * 0.85
  round(v, 4)
}
values <- sapply(wells, curve)  # time x wells

# --- BioTek Gen5 layout -----------------------------------------------------
lines <- c(
  "Software Version,3.08.01",
  "",
  "Experiment File Path:,C:\\Experiments\\run1.xpt",
  "Plate Number,Plate 1",
  "Reader Type:,Synergy H1",
  "Reading Type,Reader",
  "",
  "Procedure Details",
  "Plate Type,96 WELL PLATE",
  "Start Kinetic,\"Runtime 24:00:00 (HH:MM:SS), Interval 0:30:00, 49 Reads\"",
  "",
  "OD:600",
  "",
  paste(c("", "Time", "T\u00b0 OD:600", wells), collapse = ",")
)
for (i in seq_along(times_h)) {
  lines <- c(lines, paste(
    c("", format(times_h[i] / 24, digits = 10), "30.0", values[i, ]),
    collapse = ","
  ))
}
lines <- c(lines, "", "Results")
writeLines(lines, "inst/extdata/biotek_gen5.csv", useBytes = TRUE)

# --- Tecan i-control layout -------------------------------------------------
n_cyc <- length(times_h)
lines <- c(
  "Application: Tecan i-control,",
  "Device: infinite 200Pro,",
  "",
  "Label1,",
  paste(c("Cycle Nr.", seq_len(n_cyc)), collapse = ","),
  paste(c("Time [s]", times_h * 3600), collapse = ","),
  paste(c("Temp. [\u00b0C]", rep("30.0", n_cyc)), collapse = ",")
)
for (w in wells) {
  lines <- c(lines, paste(c(w, values[, w]), collapse = ","))
}
lines <- c(lines, "", "Date of measurement: 2026-08-28")
writeLines(lines, "inst/extdata/tecan_icontrol.csv", useBytes = TRUE)

message("Wrote instrument example files.")
