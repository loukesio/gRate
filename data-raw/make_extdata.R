# Generates the small example files bundled in inst/extdata/.
# Run from the package root: source("data-raw/make_extdata.R")
#
# The data are a synthetic 96-well OD600 run with realistic artifacts:
# 2 dead wells (C5, F8), 3 spike wells (B3, D10, G6), and a 0.85x edge effect,
# so the vignette and examples have something for gr_qc()/gr_spatial() to find.

set.seed(42)

times <- seq(0, 24, by = 0.5)
wells <- as.vector(t(outer(LETTERS[1:8], 1:12, paste0)))
edge <- wells[substr(wells, 1, 1) %in% c("A", "H") |
                as.integer(sub("^[A-H]", "", wells)) %in% c(1, 12)]
dead <- c("C5", "F8")
spiked <- c("B3", "D10", "G6")

curve <- function(well) {
  if (well %in% dead) {
    v <- 0.05 + rnorm(length(times), 0, 0.003)
  } else {
    K <- 1.2 * runif(1, 0.95, 1.05)
    v <- 0.05 + K / (1 + exp(-0.6 * (times - 8))) + rnorm(length(times), 0, 0.003)
  }
  if (well %in% spiked) v[16] <- v[16] + 0.4
  if (well %in% edge) v <- v * 0.85
  round(v, 4)
}

values <- sapply(wells, curve)

dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)

# Wide: time + one column per well.
wide <- data.frame(time = times, values, check.names = FALSE)
write.csv(wide, "inst/extdata/growth_wide.csv", row.names = FALSE)

# Long: well, time, value.
long <- data.frame(
  well = rep(wells, each = length(times)),
  time = rep(times, times = length(wells)),
  value = as.vector(values)
)
write.csv(long, "inst/extdata/growth_long.csv", row.names = FALSE)

# Long layout: strains in column pairs, media split top/bottom halves.
# Within each strain x medium block of 8 wells: the 4 rows are biological
# replicates and the 2 columns of the pair are technical replicates.
well_row <- substr(wells, 1, 1)
well_col <- as.integer(sub("^[A-H]", "", wells))
layout_long <- data.frame(
  well = wells,
  strain = paste0("strain_", ceiling(well_col / 2)),
  medium = ifelse(well_row %in% LETTERS[1:4], "LB", "M9"),
  bio_rep = ifelse(well_row %in% LETTERS[1:4],
                   match(well_row, LETTERS[1:4]),
                   match(well_row, LETTERS[5:8])),
  tech_rep = 2 - well_col %% 2
)
write.csv(layout_long, "inst/extdata/layout_long.csv", row.names = FALSE)

# Grid layout: 8x12 with a leading row-letter column.
grid <- data.frame(
  row = LETTERS[1:8],
  matrix(paste0("strain_", rep(1:6, each = 2)), nrow = 8, ncol = 12,
         byrow = TRUE),
  check.names = FALSE
)
names(grid) <- c("row", as.character(1:12))
write.csv(grid, "inst/extdata/layout_grid.csv", row.names = FALSE)

message("Wrote ", length(list.files("inst/extdata")), " files to inst/extdata/")
