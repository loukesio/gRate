test_that("gr_spatial recovers the injected edge effect", {
  plate <- gr_qc(synthetic_plate())
  truth <- attr(plate, "truth")
  plate <- gr_spatial(plate)
  sp <- plate$spatial

  # Edge rows/cols should have effects clearly below 1, interior near 1.
  expect_lt(sp$row_effects[["A"]], 0.95)
  expect_lt(sp$row_effects[["H"]], 0.95)
  expect_lt(sp$col_effects[["1"]], 0.95)
  expect_lt(sp$col_effects[["12"]], 0.95)
  interior_rows <- sp$row_effects[c("B", "C", "D", "E", "F", "G")]
  expect_true(all(abs(interior_rows - 1) < 0.05))

  # Non-corner edge wells: estimated factor close to the injected 0.85.
  factors <- sp$factors
  side_edge <- factors$row %in% c("A", "H") & !factors$col %in% c(1, 12)
  expect_equal(mean(factors$factor[side_edge]), truth$edge_factor,
               tolerance = 0.03)
})

test_that("correction shrinks the edge bias in max OD", {
  plate <- gr_qc(synthetic_plate())
  truth <- attr(plate, "truth")

  bias <- function(p) {
    s <- gr_summarise(p)
    ok <- !s$well %in% c(truth$dead_wells, truth$spike_wells)
    s <- s[ok, ]
    edge <- s$well %in% truth$edge_wells
    abs(mean(s$max_od[edge]) / mean(s$max_od[!edge]) - 1)
  }

  before <- bias(plate)
  plate <- gr_spatial(plate)
  after <- bias(plate)

  expect_gt(before, 0.1)          # the artifact is really there
  expect_lt(after, before / 3)    # and correction removes most of it
  expect_true("value_raw" %in% names(plate$data))
})

test_that("correct = FALSE estimates but leaves data untouched", {
  plate <- gr_qc(synthetic_plate())
  before <- plate$data$value
  plate <- gr_spatial(plate, correct = FALSE)
  expect_identical(plate$data$value, before)
  expect_false(is.null(plate$spatial))
  expect_false(plate$spatial$corrected)
  expect_false("value_raw" %in% names(plate$data))
})

test_that("flagged wells are excluded from estimation but still corrected", {
  plate <- gr_qc(synthetic_plate())
  plate <- gr_spatial(plate)
  # Dead well C5 still got a correction factor applied.
  c5 <- plate$data[plate$data$well == "C5", ]
  expect_false(identical(c5$value, c5$value_raw))
})

test_that("auc works as the spatial statistic", {
  plate <- gr_qc(synthetic_plate())
  plate <- gr_spatial(plate, stat = "auc")
  expect_identical(plate$spatial$stat, "auc")
  expect_lt(plate$spatial$row_effects[["A"]], 0.95)
})

test_that("double correction is refused", {
  plate <- gr_spatial(gr_qc(synthetic_plate()))
  expect_error(gr_spatial(plate), "already been spatially corrected")
})

test_that("a clean plate gets effects near 1", {
  plate <- gr_spatial(gr_qc(clean_plate()))
  expect_true(all(abs(plate$spatial$factors$factor - 1) < 0.05))
})
