test_that("gr_plot_plate returns a ggplot for stats, flags, and metadata", {
  plate <- gr_qc(synthetic_plate())
  plate <- gr_layout(plate, data.frame(well = gRate:::gr_all_wells(),
                                       strain = rep(c("wt", "mut"), 48)))

  for (fill in c("max_od", "auc", "flagged", "spike", "strain")) {
    p <- gr_plot_plate(plate, fill)
    expect_s3_class(p, "ggplot")
    expect_no_error(ggplot2::ggplot_build(p))
  }

  expect_s3_class(gr_plot_plate(plate, "max_od", label = TRUE), "ggplot")
})

test_that("gr_plot_plate rejects unknown fills with guidance", {
  plate <- synthetic_plate()
  expect_error(gr_plot_plate(plate, "nope"), "Available")
  expect_error(gr_plot_plate(plate, "flagged"), "gr_qc")
})

test_that("gr_plot_curves returns a ggplot in all modes", {
  plate <- gr_qc(synthetic_plate())
  plate <- gr_layout(plate, data.frame(well = gRate:::gr_all_wells(),
                                       strain = rep(c("wt", "mut"), 48)))

  expect_s3_class(gr_plot_curves(plate), "ggplot")
  expect_s3_class(gr_plot_curves(plate, colour_by = "strain"), "ggplot")
  expect_s3_class(gr_plot_curves(plate, wells = c("A1", "c5")), "ggplot")
  expect_no_error(ggplot2::ggplot_build(gr_plot_curves(plate)))
})

test_that("gr_plot_curves raw mode needs a corrected plate", {
  plate <- gr_qc(synthetic_plate())
  expect_error(gr_plot_curves(plate, raw = TRUE), "not been spatially")
  plate <- gr_spatial(plate)
  expect_s3_class(gr_plot_curves(plate, raw = TRUE), "ggplot")
})

test_that("gr_plot_curves validates inputs", {
  plate <- synthetic_plate()
  expect_error(gr_plot_curves(plate, wells = "Z9"), "Invalid well")
  expect_error(gr_plot_curves(plate, colour_by = "nope"), "gr_layout")
})

test_that("plate heatmap uses the ltc heatmap0 ramp with quantile equalization", {
  expect_length(gr_colors$sequential, 9)
  expect_identical(gr_colors$sequential[1], "#001219")

  plate <- gr_qc(synthetic_plate())
  expect_no_error(ggplot2::ggplot_build(gr_plot_plate(plate, "max_od")))
  expect_no_error(
    ggplot2::ggplot_build(gr_plot_plate(plate, "max_od", equalize = FALSE))
  )

  # A constant fill falls back to the linear mapping without erroring.
  flat <- plate
  flat$data$value <- 1
  expect_no_error(ggplot2::ggplot_build(gr_plot_plate(flat, "max_od")))
})
