# The bundled files mimic real exports the parsers were validated against:
# a Gen5 kinetic export from a Synergy H1 and a Tecan i-control kinetic
# export. Both carry the standard synthetic plate, so the whole pipeline's
# ground truth applies downstream.

gen5_path <- system.file("extdata", "biotek_gen5.csv", package = "gRate")
tecan_path <- system.file("extdata", "tecan_icontrol.csv", package = "gRate")

test_that("BioTek Gen5 exports parse, with auto-detection", {
  plate <- gr_read(gen5_path)  # format = "auto" sniffs the Gen5 signature
  expect_identical(plate$meta$source_format, "biotek")
  expect_identical(plate$meta$instrument, "BioTek Gen5")
  expect_identical(plate$meta$read, "OD:600")
  expect_equal(dplyr::n_distinct(plate$data$well), 96)
  expect_equal(dplyr::n_distinct(plate$data$time), 49)
  # Day-fractions became hours: 30-minute interval over 24 h.
  expect_equal(plate$meta$read_interval, 0.5, tolerance = 1e-6)
  expect_equal(max(plate$data$time), 24, tolerance = 1e-6)
  expect_equal(plate$meta$temperature, 30)
})

test_that("Tecan i-control exports parse, with auto-detection", {
  plate <- gr_read(tecan_path)
  expect_identical(plate$meta$source_format, "tecan")
  expect_identical(plate$meta$instrument, "Tecan i-control")
  expect_equal(dplyr::n_distinct(plate$data$well), 96)
  expect_equal(dplyr::n_distinct(plate$data$time), 49)
  # Seconds became hours via the Time [s] header.
  expect_equal(plate$meta$read_interval, 0.5, tolerance = 1e-6)
  expect_equal(plate$meta$temperature, 30)
})

test_that("both instrument files carry identical, pipeline-ready data", {
  gen5 <- gr_read(gen5_path)
  tecan <- gr_read(tecan_path)
  expect_equal(
    dplyr::arrange(gen5$data, well, time)$value,
    dplyr::arrange(tecan$data, well, time)$value
  )
  # The known artifacts survive the round trip into the pipeline.
  qc <- gr_qc(gen5)$qc
  expect_setequal(qc$well[qc$no_growth], c("C5", "F8"))
  expect_setequal(qc$well[qc$spike], c("B3", "D10", "G6"))
})

test_that("multi-read files list reads and allow selection", {
  # Append a second kinetic block to the Gen5 example. The read name
  # contains a comma, so its CSV fields must be quoted - as Gen5 does.
  lines <- readLines(gen5_path)
  extra <- c("", "\"GFP:485,528\"", "",
             sub("T\u00b0 OD:600", "\"T\u00b0 GFP:485,528\"",
                 lines[grep("^,Time", lines)[1]], fixed = TRUE),
             lines[grep("^,\\d", lines)])
  two <- withr::local_tempfile(fileext = ".csv")
  writeLines(c(lines[seq_len(length(lines) - 2)], extra), two)

  expect_message(plate <- gr_read(two), "2 kinetic reads")
  expect_identical(plate$meta$read, "OD:600")
  expect_identical(plate$meta$reads, c("OD:600", "GFP:485,528"))

  gfp_plate <- gr_read(two, read = "GFP")
  expect_identical(gfp_plate$meta$read, "GFP:485,528")

  expect_error(gr_read(two, read = "nope"), "No kinetic read matching")
})

test_that("384-well and malformed instrument files fail informatively", {
  # 384-well Tecan: rows beyond H.
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("Cycle Nr.,1,2", "Time [s],0,600",
               "A1,0.1,0.2", "I3,0.1,0.2"), f)
  expect_error(gr_read(f, format = "tecan"), "384-well")

  # Instrument format forced on a data frame.
  expect_error(gr_read(data.frame(x = 1), format = "tecan"),
               "file path")

  # A Gen5-flavoured file with no kinetic block.
  g <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("Software Version,3.08.01", "Plate Number,Plate 1"), g)
  expect_error(gr_read(g, format = "biotek"), "No kinetic data block")
})

test_that("time_unit override is respected", {
  plate <- gr_read(tecan_path, time_unit = "minutes")
  # 1800 "minutes" -> 30 h interval instead of 0.5 h.
  expect_equal(plate$meta$read_interval, 30, tolerance = 1e-6)
})
