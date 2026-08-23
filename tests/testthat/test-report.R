test_that("gr_report renders a self-contained HTML file via Quarto", {
  skip_on_cran()
  skip_if_not_installed("quarto")
  skip_if(is.null(quarto::quarto_path()), "Quarto CLI not available")

  plate <- gr_spatial(gr_qc(synthetic_plate()))
  out_file <- withr::local_tempfile(fileext = ".html")
  out <- gr_report(plate, file = out_file)

  expect_true(file.exists(out))
  html <- readLines(out, warn = FALSE)
  expect_true(any(grepl("flagged well", html)))
})

test_that("gr_report(interactive = TRUE) renders plotly widgets and a DT table", {
  skip_on_cran()
  skip_if_not_installed("quarto")
  skip_if_not_installed("plotly")
  skip_if_not_installed("DT")
  skip_if(is.null(quarto::quarto_path()), "Quarto CLI not available")

  plate <- gr_fit(gr_qc(synthetic_plate()))
  out_file <- withr::local_tempfile(fileext = ".html")
  out <- gr_report(plate, file = out_file, interactive = TRUE)

  html <- paste(readLines(out, warn = FALSE), collapse = "\n")
  expect_match(html, "plotly")
  expect_match(html, "datatables", ignore.case = TRUE)
})
