test_that("tidy export joins QC flags", {
  plate <- gr_qc(synthetic_plate())
  out <- gr_export(plate)
  expect_true(all(c("flagged", "reasons") %in% names(out)))
  expect_equal(nrow(out), nrow(plate$data))
  expect_true(all(out$flagged[out$well == "C5"]))
})

test_that("growthcurver export is wide with a time column", {
  plate <- gr_qc(synthetic_plate())
  out <- gr_export(plate, as = "growthcurver")
  expect_s3_class(out, "data.frame")
  expect_identical(names(out)[1], "time")
  expect_equal(ncol(out), 97)  # time + 96 wells
  expect_equal(nrow(out), dplyr::n_distinct(plate$data$time))
  expect_false(is.unsorted(out$time))
})

test_that("drop_flagged removes exactly the flagged wells", {
  plate <- gr_qc(synthetic_plate())
  truth <- attr(plate, "truth")
  out <- gr_export(plate, as = "growthcurver", drop_flagged = TRUE)
  expect_equal(ncol(out), 97 - length(c(truth$dead_wells, truth$spike_wells)))
  expect_false(any(truth$dead_wells %in% names(out)))

  expect_error(gr_export(synthetic_plate(), drop_flagged = TRUE),
               "run gr_qc")
})

test_that("gcplyr export uses gcplyr column names", {
  plate <- synthetic_plate()
  out <- as_gcplyr(plate)
  expect_true(all(c("Well", "Time", "Measurements") %in% names(out)))
  expect_false(any(c("row", "col") %in% names(out)))
})

test_that("converter shorthands match gr_export", {
  plate <- gr_qc(synthetic_plate())
  expect_identical(as_growthcurver(plate),
                   gr_export(plate, as = "growthcurver"))
  expect_identical(as_gcplyr(plate), gr_export(plate, as = "gcplyr"))
})

test_that("export carries layout metadata", {
  plate <- synthetic_plate()
  plate <- gr_layout(plate, data.frame(well = gRate:::gr_all_wells(),
                                       strain = "wt"))
  expect_true("strain" %in% names(gr_export(plate)))
  expect_true("strain" %in% names(as_gcplyr(plate)))
})

test_that("collapse_tech averages technical replicates", {
  plate <- gr_qc(synthetic_plate())
  layout <- data.frame(
    well = gRate:::gr_all_wells(),
    strain = rep(rep(paste0("s", 1:6), each = 2), 8),
    bio_rep = rep(1:8, each = 12),
    tech_rep = rep(1:2, 48)
  )
  plate <- gr_layout(plate, layout)
  out <- gr_export(plate, collapse_tech = TRUE)

  n_times <- dplyr::n_distinct(plate$data$time)
  expect_equal(nrow(out), 6 * 8 * n_times)  # strain x bio_rep x time
  expect_true(all(out$n_wells == 2))
  expect_false("tech_rep" %in% names(out))
  expect_false("well" %in% names(out))

  # The average is really the mean of the two wells (A1 + A2 at time 0).
  a12 <- subset(plate$data, well %in% c("A1", "A2") & time == 0)
  got <- subset(out, strain == "s1" & bio_rep == 1 & time == 0)
  expect_equal(got$value, mean(a12$value))

  # flagged propagates from any contributing well (C5 is dead).
  c5_group <- subset(out, strain == "s3" & bio_rep == 3)
  expect_true(all(c5_group$flagged))
})

test_that("collapse_tech guards its requirements", {
  plate <- gr_qc(synthetic_plate())
  expect_error(gr_export(plate, collapse_tech = TRUE), "tech_rep")
  expect_error(
    gr_export(plate, as = "growthcurver", collapse_tech = TRUE),
    "only applies"
  )
})
