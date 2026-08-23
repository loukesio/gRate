test_that("gr_qc recovers the injected dead and spike wells exactly", {
  plate <- gr_qc(synthetic_plate())
  truth <- attr(plate, "truth")
  qc <- plate$qc

  expect_setequal(qc$well[qc$no_growth], truth$dead_wells)
  expect_setequal(qc$well[qc$spike], truth$spike_wells)

  # No well is flagged for anything else.
  expect_setequal(qc$well[qc$flagged],
                  c(truth$dead_wells, truth$spike_wells))
})

test_that("a clean plate produces no flags", {
  plate <- gr_qc(clean_plate())
  expect_false(any(plate$qc$flagged))
})

test_that("reasons list the failed checks", {
  plate <- gr_qc(synthetic_plate())
  qc <- plate$qc
  expect_identical(qc$reasons[qc$well == "C5"], "no_growth")
  expect_identical(qc$reasons[qc$well == "B3"], "spike")
  expect_identical(unique(qc$reasons[!qc$flagged]), "")
})

test_that("drift is detected on linear ramps but not on sigmoids", {
  plate <- clean_plate()
  # Replace A5 (interior of row A... actually edge; use C3, interior) with a
  # linear ramp of the same magnitude as real growth.
  ramp <- plate$data$well == "C3"
  plate$data$value[ramp] <- 0.05 + 0.02 * plate$data$time[ramp] +
    rnorm(sum(ramp), 0, 0.002)

  plate <- gr_qc(plate)
  expect_true(plate$qc$drift[plate$qc$well == "C3"])
  expect_identical(plate$qc$well[plate$qc$drift], "C3")
})

test_that("late jumps are detected", {
  plate <- clean_plate()
  jump <- plate$data$well == "D7"
  t <- plate$data$time[jump]
  plate$data$value[jump] <- 0.05 + rnorm(sum(jump), 0, 0.002) +
    ifelse(t > 0.85 * max(t), 0.3, 0)

  plate <- gr_qc(plate)
  expect_true(plate$qc$late_jump[plate$qc$well == "D7"])
  # A late jump implies no early growth; other wells stay clean.
  expect_setequal(plate$qc$well[plate$qc$flagged], "D7")
})

test_that("noisy wells are detected", {
  plate <- clean_plate()
  noisy <- plate$data$well == "E4"
  plate$data$value[noisy] <- plate$data$value[noisy] +
    rnorm(sum(noisy), 0, 0.05)

  plate <- gr_qc(plate, checks = c("no_growth", "noisy"))
  expect_true(plate$qc$noisy[plate$qc$well == "E4"])
  expect_setequal(plate$qc$well[plate$qc$flagged], "E4")
})

test_that("checks argument limits which flags run", {
  plate <- gr_qc(synthetic_plate(), checks = c("no_growth", "spike"))
  expect_named(
    plate$qc,
    c("well", "row", "col", "no_growth", "spike", "flagged", "reasons")
  )
})

test_that("thresholds are tunable and recorded", {
  plate <- synthetic_plate()
  strict <- gr_qc(plate, no_growth_delta = 2)  # nothing rises 2 OD
  expect_true(all(strict$qc$no_growth))

  th <- attr(gr_qc(plate, spike_delta = 0.2)$qc, "thresholds")
  expect_equal(th$spike_delta, 0.2)
})

test_that("flags never delete data", {
  plate <- synthetic_plate()
  before <- nrow(plate$data)
  plate <- gr_qc(plate)
  expect_equal(nrow(plate$data), before)
})
