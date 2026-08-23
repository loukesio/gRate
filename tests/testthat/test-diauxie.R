# A plate mixing single-phase and genuinely diauxic wells. The diauxic curves
# are two stacked logistics: a fast small phase (r = 0.8, K = 0.3, mid t = 5),
# a plateau, then a slower larger phase (r = 0.5, K = 0.9, mid t = 16).
diauxic_plate <- function(seed = 21) {
  set.seed(seed)
  times <- seq(0, 28, by = 0.25)
  single <- function(w) {
    data.frame(well = w, time = times,
               value = 0.05 + 1.2 / (1 + exp(-0.6 * (times - 8))) +
                 rnorm(length(times), 0, 0.003))
  }
  double <- function(w) {
    data.frame(well = w, time = times,
               value = 0.05 +
                 0.3 / (1 + exp(-0.8 * (times - 5))) +
                 0.9 / (1 + exp(-0.5 * (times - 16))) +
                 rnorm(length(times), 0, 0.003))
  }
  df <- rbind(
    do.call(rbind, lapply(paste0("A", 1:4), single)),
    do.call(rbind, lapply(paste0("B", 1:4), double)),
    data.frame(well = "C1", time = times,       # dead well
               value = 0.05 + rnorm(length(times), 0, 0.003))
  )
  gr_read(df, format = "long")
}

test_that("gr_diauxie separates single-phase, diauxic, and dead wells", {
  dx <- gr_diauxie(diauxic_plate())

  a <- dx[dx$row == "A", ]
  expect_true(all(a$n_phases == 1))
  expect_false(any(a$diauxic))
  expect_true(all(is.na(a$r2)))

  b <- dx[dx$row == "B", ]
  expect_true(all(b$diauxic))
  expect_true(all(b$n_phases >= 2))
  # First phase is the faster one, early; second slower, later.
  expect_true(all(b$t1 < b$t2))
  expect_true(all(b$r1 > b$r2))
  expect_true(all(b$trough_t > b$t1 & b$trough_t < b$t2))

  dead <- dx[dx$well == "C1", ]
  expect_true(is.na(dead$diauxic))
  expect_match(dead$note, "min_od")
})

test_that("thresholds guard against noise phases", {
  # Demanding a rate every well lacks -> no phases anywhere.
  dx <- gr_diauxie(diauxic_plate(), min_rate = 5)
  expect_true(all(dx$n_phases == 0))
  expect_false(any(dx$diauxic[dx$row %in% c("A", "B")]))

  # An extreme drop requirement merges the two phases of the B wells.
  dx2 <- gr_diauxie(diauxic_plate(), drop_frac = 1e-6)
  expect_true(all(dx2$n_phases[dx2$row == "B"] == 1))
})

test_that("the standard synthetic plate has no false diauxie", {
  dx <- gr_diauxie(synthetic_plate())
  truth <- attr(synthetic_plate(), "truth")
  ok <- !dx$well %in% c(truth$dead_wells)
  expect_false(any(dx$diauxic[ok], na.rm = FALSE))
})
