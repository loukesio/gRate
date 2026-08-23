# Ground truth from helper-synthetic.R: logistic curves with r = 0.6,
# K = 1.2 * runif(0.95, 1.05), baseline 0.05, midpoint t = 8. The tangent-lag
# for those parameters is 8 - 2/0.6 = 4.67.

test_that("logistic fit recovers the true parameters on a clean plate", {
  plate <- gr_fit(gr_qc(clean_plate()))
  fit <- plate$fit

  expect_true(all(fit$fit_ok))
  expect_lt(abs(median(fit$r) - 0.6), 0.05)
  expect_true(all(fit$K > 1.05 & fit$K < 1.35))
  expect_lt(abs(median(fit$lag) - 4.67), 0.7)
  expect_equal(fit$doubling_time, log(2) / fit$r)
  expect_identical(plate$meta$fit_method, "logistic")
})

test_that("easylinear recovers the true growth rate on a clean plate", {
  plate <- gr_fit(gr_qc(clean_plate()), method = "easylinear")
  fit <- plate$fit

  expect_true(all(fit$fit_ok))
  expect_lt(abs(median(fit$r) - 0.6), 0.06)
  expect_true(all(fit$r > 0.45 & fit$r < 0.8))
  expect_true(all(fit$K > 1.05 & fit$K < 1.35))
})

test_that("dead wells fail gracefully with a note", {
  plate <- gr_fit(gr_qc(synthetic_plate()))
  truth <- attr(plate, "truth")
  dead <- plate$fit[plate$fit$well %in% truth$dead_wells, ]

  expect_false(any(dead$fit_ok))
  expect_true(all(is.na(dead$r)))
  expect_true(all(nzchar(dead$note)))
  # All other wells still fit.
  expect_true(all(plate$fit$fit_ok[!plate$fit$well %in% truth$dead_wells]))
})

test_that("fitted curves are stored in $data and refitting replaces them", {
  plate <- gr_fit(gr_qc(clean_plate()))
  expect_true("fitted" %in% names(plate$data))
  expect_false(anyNA(plate$data$fitted))  # logistic predicts everywhere

  plate <- gr_fit(plate, method = "easylinear")
  expect_identical(plate$meta$fit_method, "easylinear")
  expect_true(anyNA(plate$data$fitted))   # easylinear only over its window
  expect_identical(sum(names(plate$data) == "fitted"), 1L)
})

test_that("spatial correction discards stale fits", {
  plate <- gr_fit(gr_qc(synthetic_plate()))
  expect_message(plate <- gr_spatial(plate), "discarding")
  expect_null(plate$fit)
  expect_false("fitted" %in% names(plate$data))
})

test_that("gr_fit_summary aggregates over replicates, excluding bad wells", {
  plate <- synthetic_plate() |>
    gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
    gr_qc() |>
    gr_fit()
  truth <- attr(plate, "truth")

  s <- gr_fit_summary(plate)
  expect_setequal(names(s)[1:2], c("strain", "medium"))
  expect_equal(nrow(s), 12)  # 6 strains x 2 media
  expect_false(any(c("bio_rep", "tech_rep") %in% names(s)))
  # strain_3 x LB (cols 5-6, rows A-D) contains dead C5 -> 7 clean wells of 8;
  # strain_2 x LB (cols 3-4) contains spiked B3 -> likewise 7.
  s3 <- s[s$strain == "strain_3" & s$medium == "LB", ]
  expect_equal(s3$n_wells, 7)
  expect_lt(abs(s3$r_mean - 0.6), 0.1)
  expect_equal(s[s$strain == "strain_2" & s$medium == "LB", ]$n_wells, 7)

  # Custom grouping keeps biological replicates separate.
  s_bio <- gr_fit_summary(plate, by = c("strain", "medium", "bio_rep"))
  expect_equal(nrow(s_bio), 6 * 2 * 4)

  expect_error(gr_fit_summary(plate, by = "nope"), "not in the plate metadata")
  expect_error(gr_fit_summary(synthetic_plate()), "run gr_fit")
})

test_that("collapse_tech is unaffected by the fitted column", {
  plate <- synthetic_plate() |>
    gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
    gr_qc() |>
    gr_fit()
  out <- gr_export(plate, collapse_tech = TRUE)
  expect_false("fitted" %in% names(out))
  expect_true(all(out$n_wells == 2))
})

test_that("fit results appear in print, plate map, and fit plot", {
  plate <- gr_fit(gr_qc(synthetic_plate()))
  expect_output(print(plate), "fit: logistic \\(94/96 wells\\)")

  expect_s3_class(gr_plot_plate(plate, "r"), "ggplot")
  expect_s3_class(gr_plot_plate(plate, "fit_ok"), "ggplot")
  p <- gr_plot_fit(plate, wells = c("A1", "C5"))
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
  expect_s3_class(gr_plot_fit(plate), "ggplot")

  expect_error(gr_plot_fit(synthetic_plate()), "run gr_fit")
  expect_error(gr_plot_plate(synthetic_plate(), "r"), "gr_fit")
})

test_that("gr_results joins parameters, metadata, and QC per well", {
  plate <- synthetic_plate() |>
    gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
    gr_qc() |>
    gr_fit()

  out <- gr_results(plate)
  expect_equal(nrow(out), 96)
  expect_true(all(c("well", "strain", "medium", "bio_rep", "tech_rep",
                    "r", "K", "lag", "doubling_time",
                    "fit_ok", "note", "flagged", "reasons") %in% names(out)))
  expect_false("sigma" %in% names(out))
  expect_true(out$flagged[out$well == "C5"])
  expect_true(is.na(out$r[out$well == "C5"]))

  # parameter selection
  sel <- gr_results(plate, params = c("r", "sigma"))
  expect_true(all(c("r", "sigma") %in% names(sel)))
  expect_false(any(c("K", "lag") %in% names(sel)))

  # drop_flagged removes exactly the flagged wells and the QC columns
  clean <- gr_results(plate, drop_flagged = TRUE)
  expect_equal(nrow(clean), 91)
  expect_false(any(c("flagged", "reasons") %in% names(clean)))
})

test_that("gr_results works without layout or QC, and writes CSV", {
  plate <- gr_fit(synthetic_plate())
  out <- gr_results(plate)
  expect_equal(nrow(out), 96)
  expect_false(any(c("flagged", "reasons") %in% names(out)))
  expect_error(gr_results(plate, drop_flagged = TRUE), "run gr_qc")
  expect_error(gr_results(synthetic_plate()), "run gr_fit")

  path <- withr::local_tempfile(fileext = ".csv")
  ret <- gr_results(plate, file = path)
  expect_true(file.exists(path))
  expect_equal(nrow(utils::read.csv(path)), 96)
  expect_s3_class(ret, "tbl_df")
})

test_that("bootstrap CIs cover the true growth rate", {
  # Small 6-well plate so 100 resamples stay fast: true r = 0.6. Midpoint
  # t = 12 keeps the first readings at pure baseline — with earlier growth,
  # baseline subtraction biases r slightly and honest CIs (which reflect only
  # sampling noise) rightly do not cover that bias.
  set.seed(11)
  times <- seq(0, 30, by = 0.5)
  wells <- c("A1", "A2", "B1", "B2", "C1", "C2")
  df <- do.call(rbind, lapply(wells, function(w) {
    K <- 1.2 * runif(1, 0.97, 1.03)
    data.frame(well = w, time = times,
               value = 0.05 + K / (1 + exp(-0.6 * (times - 12))) +
                 rnorm(length(times), 0, 0.003))
  }))
  plate <- gr_read(df, format = "long")

  fit <- gr_fit(plate, boot = 100)$fit
  expect_true(all(fit$r_lo < fit$r & fit$r < fit$r_hi))
  expect_true(all(fit$K_lo < fit$K & fit$K < fit$K_hi))
  covered <- fit$r_lo <= 0.6 & 0.6 <= fit$r_hi
  expect_gte(sum(covered), 4)  # ~95% nominal on 6 wells

  el <- gr_fit(plate, method = "easylinear", boot = 100)$fit
  expect_true(all(el$r_lo < el$r & el$r < el$r_hi))
  expect_true(all(is.na(el$K_lo)))  # easylinear K is empirical, no CI

  # CI columns travel with their parameter through gr_results()
  res <- gr_results(gr_fit(plate, boot = 100), params = c("r", "K"))
  expect_true(all(c("r_lo", "r_hi", "K_lo", "K_hi") %in% names(res)))

  # boot = 0 (default): columns exist but are all NA, and are not exported
  plain <- gr_fit(plate)
  expect_true(all(is.na(plain$fit$r_lo)))
  expect_false("r_lo" %in% names(gr_results(plain)))
})
