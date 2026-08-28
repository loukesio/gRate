test_that("gr_read parses long data frames and normalises wells", {
  df <- expand.grid(Well = c("A01", "b2", "H12"), Time = c(0, 1, 2),
                    stringsAsFactors = FALSE)
  df$OD600 <- 0.1
  plate <- gr_read(df, format = "long")

  expect_s3_class(plate, "gr_plate")
  expect_setequal(unique(plate$data$well), c("A1", "B2", "H12"))
  expect_equal(sort(unique(plate$data$col)), c(1, 2, 12))
  expect_equal(plate$meta$read_interval, 1)
})

test_that("gr_read parses wide data frames", {
  df <- data.frame(Time = c(0, 0.5, 1), A1 = c(0.05, 0.06, 0.08),
                   B02 = c(0.05, 0.07, 0.10), check.names = FALSE)
  plate <- gr_read(df, format = "wide")

  expect_setequal(unique(plate$data$well), c("A1", "B2"))
  expect_equal(nrow(plate$data), 6)
  expect_equal(
    plate$data$value[plate$data$well == "B2"],
    c(0.05, 0.07, 0.10)
  )
})

test_that("format auto-detection distinguishes wide from long", {
  long <- data.frame(well = "A1", time = 0:2, value = 0.1)
  wide <- data.frame(time = 0:2, A1 = 0.1, A2 = 0.2)
  expect_identical(gr_read(long)$meta$source_format, "long")
  expect_identical(gr_read(wide)$meta$source_format, "wide")

  neither <- data.frame(x = 1, y = 2)
  expect_error(gr_read(neither), "Could not detect")
})

test_that("gr_read reads wide and long CSV files", {
  df <- data.frame(time = c(0, 1), A1 = c(0.05, 0.5), H12 = c(0.05, 0.4))
  wide_path <- withr::local_tempfile(fileext = ".csv")
  write.csv(df, wide_path, row.names = FALSE)

  plate <- gr_read(wide_path)
  expect_equal(dplyr::n_distinct(plate$data$well), 2)
  expect_identical(plate$meta$plate_id, tools::file_path_sans_ext(basename(wide_path)))

  long_df <- tidyr::pivot_longer(df, -time, names_to = "well",
                                 values_to = "od")
  long_path <- withr::local_tempfile(fileext = ".csv")
  write.csv(long_df, long_path, row.names = FALSE)
  plate2 <- gr_read(long_path)
  expect_equal(
    dplyr::arrange(plate2$data, well, time)$value,
    dplyr::arrange(plate$data, well, time)$value
  )
})

test_that("HH:MM:SS times are converted to hours", {
  df <- data.frame(well = "A1", time = c("0:00:00", "0:30:00", "1:15:00"),
                   value = c(0.05, 0.06, 0.07))
  plate <- gr_read(df, format = "long")
  expect_equal(sort(unique(plate$data$time)), c(0, 0.5, 1.25))
})

test_that("instrument formats demand a matching file", {
  # A generic wide CSV has none of the instrument signatures.
  df <- data.frame(time = c(0, 1), A1 = c(0.05, 0.5))
  path <- withr::local_tempfile(fileext = ".csv")
  write.csv(df, path, row.names = FALSE)
  expect_error(gr_read(path, format = "tecan"), "No kinetic data block")
  expect_error(gr_read(path, format = "biotek"), "No kinetic data block")
  expect_error(gr_read("missing.csv", format = "tecan"), "File not found")
})

test_that("invalid input is rejected", {
  expect_error(gr_read(1L), "file path or a data frame")
  expect_error(gr_read("does-not-exist.csv"), "File not found")
  expect_error(
    gr_read(data.frame(well = "Z9", time = 0, value = 1), format = "long"),
    "Invalid well"
  )
  expect_error(
    gr_read(data.frame(well = c("A1", "A1"), time = c(0, 0), value = 1),
            format = "long"),
    "duplicated"
  )
})

test_that("print method summarises the plate", {
  plate <- synthetic_plate()
  expect_output(print(plate), "96 wells x 49 timepoints")
  expect_output(print(plate), "QC: not run")
  plate <- gr_qc(plate)
  expect_output(print(plate), "flagged")
})
