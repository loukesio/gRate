# A plate with a genuine group difference: columns 1-6 carry a fast strain
# (r = 0.9), columns 7-12 a slow one (r = 0.6). Rows are 8 biological
# replicates; the 6 columns per strain are technical replicates.
two_strain_plate <- function(seed = 7) {
  set.seed(seed)
  times <- seq(0, 24, by = 0.5)
  wells <- gRate:::gr_all_wells()

  df <- do.call(rbind, lapply(wells, function(w) {
    r <- if (gRate:::gr_well_col(w) <= 6) 0.9 else 0.6
    K <- 1.2 * stats::runif(1, 0.97, 1.03)
    v <- 0.05 + K / (1 + exp(-r * (times - 8))) +
      stats::rnorm(length(times), 0, 0.003)
    data.frame(well = w, time = times, value = v)
  }))

  layout <- data.frame(
    well = wells,
    strain = ifelse(gRate:::gr_well_col(wells) <= 6, "fast", "slow"),
    bio_rep = match(gRate:::gr_well_row(wells), LETTERS),
    tech_rep = (gRate:::gr_well_col(wells) - 1) %% 6 + 1
  )

  gr_read(df, format = "long") |>
    gr_layout(layout) |>
    gr_qc() |>
    gr_fit()
}

test_that("gr_compare detects a true difference at the right unit", {
  cmp <- gr_compare(two_strain_plate(), what = "r", by = "strain")

  # Pseudoreplication check: 8 biological replicates per strain, not 48 wells.
  expect_equal(cmp$groups$n, c(8, 8))
  expect_identical(cmp$unit, "biological replicates")

  expect_identical(cmp$overall$method, "Welch two-sample t-test")
  expect_lt(cmp$overall$p_value, 0.001)

  means <- setNames(cmp$groups$mean, cmp$groups$group)
  expect_lt(abs(means[["fast"]] - 0.9), 0.06)
  expect_lt(abs(means[["slow"]] - 0.6), 0.06)

  expect_equal(nrow(cmp$pairwise), 1)
  expect_lt(cmp$pairwise$p_adj, 0.001)
  expect_gt(abs(cmp$pairwise$diff), 0.2)
})

test_that("gr_compare handles >2 groups and the kruskal method", {
  plate <- synthetic_plate() |>
    gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
    gr_qc() |>
    gr_fit()

  cmp <- gr_compare(plate, what = "r", by = "strain")
  expect_identical(cmp$overall$method, "Welch's ANOVA")
  expect_equal(nrow(cmp$groups), 6)
  expect_equal(nrow(cmp$pairwise), choose(6, 2))

  kw <- gr_compare(plate, what = "K", by = "medium", method = "kruskal")
  expect_identical(kw$overall$method, "Kruskal-Wallis test")
  expect_true(all(kw$pairwise$p_adj >= 0 & kw$pairwise$p_adj <= 1))

  # default by: all metadata except the replicate ids
  cmp_def <- gr_compare(plate)
  expect_setequal(cmp_def$by, c("strain", "medium"))
})

test_that("wells are the unit when no bio_rep is designated", {
  plate <- synthetic_plate() |>
    gr_layout(data.frame(well = gRate:::gr_all_wells(),
                         strain = rep(c("a", "b"), 48))) |>
    gr_qc() |>
    gr_fit()
  cmp <- gr_compare(plate, by = "strain")
  expect_identical(cmp$unit, "wells")
  expect_gt(min(cmp$groups$n), 40)
})

test_that("gr_compare validates its inputs", {
  plate <- two_strain_plate()
  expect_error(gr_compare(plate, by = "nope"), "not in the plate metadata")
  expect_error(gr_compare(gr_qc(synthetic_plate())), "run gr_fit")

  # a constant grouping column -> only one group
  one <- plate
  one$data$batch <- "x"
  expect_error(gr_compare(one, by = "batch"), "at least 2 groups")

  # no metadata at all
  bare <- gr_fit(gr_qc(synthetic_plate()))
  expect_error(gr_compare(bare), "No metadata columns")
})

test_that("print and plot methods work", {
  cmp <- gr_compare(two_strain_plate(), what = "r", by = "strain")
  expect_output(print(cmp), "Welch two-sample t-test")
  expect_output(print(cmp), "biological replicates")

  p <- gr_plot_compare(cmp)
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
  expect_error(gr_plot_compare(mtcars), "gr_compare object")
})
