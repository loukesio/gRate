#' Fit growth models and estimate growth parameters per well
#'
#' Estimates growth parameters for every well and stores them in `plate$fit`.
#' Two methods are available:
#'
#' * `"logistic"` (default) — a parametric fit of the logistic growth model
#'   via [stats::nls()] with the self-starting [stats::SSlogis()] model, on
#'   baseline-subtracted values. Returns the carrying capacity `K`, the
#'   intrinsic growth rate `r`, the initial density `N0`, the time of maximum
#'   growth `t_rmax` (the inflection point), the lag time (tangent at the
#'   inflection extrapolated to the baseline), and the doubling time
#'   `ln(2)/r`.
#' * `"gompertz"` — a parametric fit of the Gompertz model via
#'   [stats::SSgompertz()]. Growth curves with a long deceleration phase are
#'   often Gompertz-shaped rather than logistic. Here `r` is the Gompertz
#'   rate constant *k* — a different scale from the logistic `r`, so compare
#'   strains within one method, and compare models with `"compare"`.
#' * `"compare"` — fits **both** logistic and Gompertz to every well and
#'   keeps the model with the lower AIC. `$fit` gains `model` (the winner),
#'   `aic_logistic`, `aic_gompertz`, and `delta_aic` (the winner's margin;
#'   small values mean the data cannot really tell the models apart).
#' * `"easylinear"` — a nonparametric estimate after Hall et al. (2014):
#'   rolling linear regressions of `log(value - baseline)` over `window`
#'   consecutive points, keeping only windows whose R-squared exceeds
#'   `min_r2`; `r` is the steepest remaining slope — the maximum per-capita
#'   growth rate, often written \eqn{\mu_{max}}. The R-squared filter is what
#'   makes this robust: windows dominated by low-OD noise are simply
#'   rejected. `K` is the (spike-resistant, running-median smoothed) maximum
#'   of the curve, and the lag time is where the fitted exponential crosses
#'   the initial log-density. Use this when curves are not logistic
#'   (diauxie, weird shapes).
#'
#' Wells where the fit fails — dead wells have nothing to fit — get
#' `fit_ok = FALSE` and an explanatory `note`, never an error. Flagged wells
#' are fitted like any others (flags never delete); check `plate$qc` before
#' trusting their parameters. If the plate was corrected with [gr_spatial()],
#' the corrected values are fitted.
#'
#' Fitted curves are stored in a `fitted` column of `plate$data` (`NA` where
#' the model makes no prediction), so [gr_plot_fit()] can overlay them on the
#' data. Refitting (e.g. with the other method) simply replaces the previous
#' results.
#'
#' @param plate A `gr_plate` object, ideally after [gr_qc()] (and optionally
#'   [gr_spatial()]).
#' @param method `"logistic"`, `"gompertz"`, `"compare"`, or `"easylinear"`
#'   (see Details).
#' @param n_baseline Number of initial readings averaged as the baseline that
#'   is subtracted before fitting. Default `3`.
#' @param min_od For `method = "easylinear"`: baseline-subtracted values must
#'   exceed this before a point enters the log-scale regressions. Default
#'   `0.05`: generous relative to typical OD noise, because log-scale noise at
#'   near-blank readings otherwise inflates the steepest-window estimate.
#'   Lower it for low-density experiments with a quiet reader.
#' @param window For `method = "easylinear"`: number of consecutive points per
#'   rolling regression. Default `5` (Hall et al.'s choice).
#' @param min_r2 For `method = "easylinear"`: minimum R-squared for a window
#'   to be considered exponential growth. Default `0.97`.
#' @param boot Number of bootstrap resamples for confidence intervals on the
#'   parameters. Default `0` (off). With `boot > 0` (200 is a reasonable
#'   choice), residuals are resampled and the model refitted per resample;
#'   `$fit` gains percentile intervals `r_lo`/`r_hi` (both methods) and
#'   `K_lo`/`K_hi` (logistic only — easylinear's K is an empirical maximum,
#'   not a fitted parameter). Wells where fewer than half the resamples
#'   converge get `NA` intervals.
#' @param conf_level Confidence level for the bootstrap intervals. Default
#'   `0.95`.
#'
#' @references Hall BG, Acar H, Nandipati A, Barlow M (2014). Growth rates
#'   made easy. *Molecular Biology and Evolution* 31(1), 232-238.
#'
#' @return The `gr_plate` with `$fit` set: a tibble with one row per well and
#'   columns `well`, `row`, `col`, `r`, `K`, `N0`, `lag`, `t_rmax`,
#'   `doubling_time`, `sigma` (residual SD on the value scale), `fit_ok`, and
#'   `note`. `plate$data` gains a `fitted` column.
#' @export
#' @seealso [gr_plot_fit()] to inspect fits, [gr_plot_plate()] to map any fit
#'   parameter, [as_growthcurver()]/[as_gcplyr()] if you prefer those fitting
#'   engines.
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#' plate <- gr_qc(plate)
#' plate <- gr_fit(plate)
#' plate
#' head(plate$fit)
#' gr_plot_plate(plate, "r")
gr_fit <- function(plate,
                   method = c("logistic", "gompertz", "compare", "easylinear"),
                   n_baseline = 3,
                   min_od = 0.05,
                   window = 5,
                   min_r2 = 0.97,
                   boot = 0,
                   conf_level = 0.95) {
  gr_assert_plate(plate)
  method <- match.arg(method)

  fit_fun <- switch(
    method,
    logistic = function(time, value) {
      gr_fit_logistic(time, value, n_baseline, boot, conf_level)
    },
    gompertz = function(time, value) {
      gr_fit_gompertz(time, value, n_baseline, boot, conf_level)
    },
    compare = function(time, value) {
      gr_fit_compare(time, value, n_baseline, boot, conf_level)
    },
    easylinear = function(time, value) {
      gr_fit_easylinear(time, value, n_baseline, min_od, window, min_r2,
                        boot, conf_level)
    }
  )

  data <- dplyr::arrange(plate$data, .data$well, .data$time)
  results <- lapply(split(seq_len(nrow(data)), data$well), function(idx) {
    res <- fit_fun(data$time[idx], data$value[idx])
    res$fitted_tbl <- tibble::tibble(
      well = data$well[idx][1],
      time = data$time[idx],
      fitted = res$fitted
    )
    res
  })

  params <- dplyr::bind_rows(lapply(results, function(res) {
    tibble::as_tibble(res$params)
  }), .id = "well")

  well_pos <- dplyr::distinct(plate$data, .data$well, .data$row, .data$col)
  plate$fit <- params |>
    dplyr::left_join(well_pos, by = "well") |>
    dplyr::select("well", "row", "col", dplyr::everything()) |>
    dplyr::arrange(.data$row, .data$col)

  fitted_all <- dplyr::bind_rows(lapply(results, function(res) res$fitted_tbl))
  plate$data$fitted <- NULL
  plate$data <- dplyr::left_join(plate$data, fitted_all,
                                 by = c("well", "time"))

  plate$meta$fit_method <- method
  plate
}

# Internal: shared shape for a failed fit.
gr_fit_failure <- function(note) {
  list(
    params = list(
      model = NA_character_,
      r = NA_real_, K = NA_real_, N0 = NA_real_, lag = NA_real_,
      t_rmax = NA_real_, doubling_time = NA_real_, sigma = NA_real_,
      r_lo = NA_real_, r_hi = NA_real_, K_lo = NA_real_, K_hi = NA_real_,
      fit_ok = FALSE, note = note
    ),
    fitted = NULL
  )
}

# Internal: percentile interval from bootstrap replicates, NA unless at least
# half of the requested resamples produced a value.
gr_boot_ci <- function(reps, boot, conf_level) {
  reps <- reps[is.finite(reps)]
  if (length(reps) < boot / 2) {
    return(c(NA_real_, NA_real_))
  }
  unname(stats::quantile(reps, c((1 - conf_level) / 2, 1 - (1 - conf_level) / 2)))
}

# Internal: logistic fit for one well (time-sorted vectors).
gr_fit_logistic <- function(time, value, n_baseline, boot = 0,
                            conf_level = 0.95) {
  baseline <- mean(utils::head(value, n_baseline))
  n <- value - baseline

  fit <- tryCatch(
    suppressWarnings(
      stats::nls(n ~ stats::SSlogis(time, Asym, xmid, scal),
                 data = data.frame(time = time, n = n))
    ),
    error = function(e) conditionMessage(e)
  )
  if (is.character(fit)) {
    out <- gr_fit_failure(paste("nls:", fit))
    out$fitted <- rep(NA_real_, length(time))
    return(out)
  }

  cf <- stats::coef(fit)
  K <- unname(cf["Asym"])
  scal <- unname(cf["scal"])
  xmid <- unname(cf["xmid"])
  r <- 1 / scal

  if (r <= 0 || K <= 0) {
    out <- gr_fit_failure("nls converged to a non-growing solution")
    out$fitted <- rep(NA_real_, length(time))
    return(out)
  }

  ci <- list(r_lo = NA_real_, r_hi = NA_real_,
             K_lo = NA_real_, K_hi = NA_real_)
  if (boot > 0) {
    hat <- stats::fitted(fit)
    resid <- stats::residuals(fit)
    reps <- vapply(seq_len(boot), function(i) {
      n_star <- hat + sample(resid, replace = TRUE)
      re <- tryCatch(
        suppressWarnings(stats::nls(
          n_star ~ Asym / (1 + exp((xmid - time) / scal)),
          data = data.frame(time = time, n_star = n_star),
          start = list(Asym = K, xmid = xmid, scal = scal)
        )),
        error = function(e) NULL
      )
      if (is.null(re)) c(NA_real_, NA_real_) else {
        cfe <- stats::coef(re)
        c(1 / cfe[["scal"]], cfe[["Asym"]])
      }
    }, numeric(2))
    r_ci <- gr_boot_ci(reps[1, ], boot, conf_level)
    k_ci <- gr_boot_ci(reps[2, ], boot, conf_level)
    ci <- list(r_lo = r_ci[1], r_hi = r_ci[2],
               K_lo = k_ci[1], K_hi = k_ci[2])
  }

  list(
    params = c(list(
      model = "logistic",
      r = r,
      K = K,
      N0 = K / (1 + exp(xmid / scal)),
      # Tangent at the inflection (slope rK/4 through K/2) meets the baseline
      # at xmid - 2/r.
      lag = xmid - 2 * scal,
      t_rmax = xmid,
      doubling_time = log(2) * scal,
      sigma = stats::sigma(fit)
    ), ci, list(
      fit_ok = TRUE,
      note = ""
    )),
    fitted = stats::fitted(fit) + baseline,
    aic = stats::AIC(fit)
  )
}

# Internal: Gompertz fit for one well. N(t) = K * exp(-exp(-k (t - t_mid)));
# SSgompertz parameterises this as Asym * exp(-b2 * b3^t) with k = -log(b3)
# and t_mid = log(b2) / k.
gr_fit_gompertz <- function(time, value, n_baseline, boot = 0,
                            conf_level = 0.95) {
  baseline <- mean(utils::head(value, n_baseline))
  n <- value - baseline

  fit <- tryCatch(
    suppressWarnings(
      stats::nls(n ~ stats::SSgompertz(time, Asym, b2, b3),
                 data = data.frame(time = time, n = n))
    ),
    error = function(e) conditionMessage(e)
  )
  if (is.character(fit)) {
    out <- gr_fit_failure(paste("nls:", fit))
    out$fitted <- rep(NA_real_, length(time))
    return(out)
  }

  cf <- stats::coef(fit)
  K <- unname(cf[["Asym"]])
  b2 <- unname(cf[["b2"]])
  b3 <- unname(cf[["b3"]])

  if (K <= 0 || b2 <= 0 || b3 <= 0 || b3 >= 1) {
    out <- gr_fit_failure("nls converged to a non-growing solution")
    out$fitted <- rep(NA_real_, length(time))
    return(out)
  }

  k <- -log(b3)
  t_mid <- log(b2) / k

  ci <- list(r_lo = NA_real_, r_hi = NA_real_,
             K_lo = NA_real_, K_hi = NA_real_)
  if (boot > 0) {
    hat <- stats::fitted(fit)
    resid <- stats::residuals(fit)
    reps <- vapply(seq_len(boot), function(i) {
      n_star <- hat + sample(resid, replace = TRUE)
      re <- tryCatch(
        suppressWarnings(stats::nls(
          n_star ~ Asym * exp(-b2 * b3^time),
          data = data.frame(time = time, n_star = n_star),
          start = list(Asym = K, b2 = b2, b3 = b3)
        )),
        error = function(e) NULL
      )
      if (is.null(re)) c(NA_real_, NA_real_) else {
        cfe <- stats::coef(re)
        c(-log(cfe[["b3"]]), cfe[["Asym"]])
      }
    }, numeric(2))
    r_ci <- gr_boot_ci(reps[1, ], boot, conf_level)
    k_ci <- gr_boot_ci(reps[2, ], boot, conf_level)
    ci <- list(r_lo = r_ci[1], r_hi = r_ci[2],
               K_lo = k_ci[1], K_hi = k_ci[2])
  }

  list(
    params = c(list(
      model = "gompertz",
      r = k,
      K = K,
      N0 = K * exp(-b2),
      # Tangent at the inflection (slope kK/e through K/e) meets the baseline
      # at t_mid - 1/k.
      lag = t_mid - 1 / k,
      t_rmax = t_mid,
      doubling_time = log(2) / k,
      sigma = stats::sigma(fit)
    ), ci, list(
      fit_ok = TRUE,
      note = ""
    )),
    fitted = stats::fitted(fit) + baseline,
    aic = stats::AIC(fit)
  )
}

# Internal: fit logistic and Gompertz, keep the lower-AIC model.
gr_fit_compare <- function(time, value, n_baseline, boot = 0,
                           conf_level = 0.95) {
  # Fit both without bootstrap first; bootstrap only the winner.
  lo <- gr_fit_logistic(time, value, n_baseline)
  go <- gr_fit_gompertz(time, value, n_baseline)

  aic_lo <- if (isTRUE(lo$params$fit_ok)) lo$aic else NA_real_
  aic_go <- if (isTRUE(go$params$fit_ok)) go$aic else NA_real_

  if (is.na(aic_lo) && is.na(aic_go)) {
    out <- gr_fit_failure("neither logistic nor Gompertz converged")
    out$params$aic_logistic <- NA_real_
    out$params$aic_gompertz <- NA_real_
    out$params$delta_aic <- NA_real_
    out$fitted <- rep(NA_real_, length(time))
    return(out)
  }

  winner_is_logistic <- isTRUE(aic_lo <= aic_go) || is.na(aic_go)
  out <- if (winner_is_logistic) {
    if (boot > 0) gr_fit_logistic(time, value, n_baseline, boot, conf_level)
    else lo
  } else {
    if (boot > 0) gr_fit_gompertz(time, value, n_baseline, boot, conf_level)
    else go
  }

  out$params$aic_logistic <- aic_lo
  out$params$aic_gompertz <- aic_go
  out$params$delta_aic <- if (is.na(aic_lo) || is.na(aic_go)) {
    NA_real_
  } else {
    abs(aic_lo - aic_go)
  }
  out
}

# Internal: rolling-regression mu-max estimate for one well (Hall et al. 2014).
gr_fit_easylinear <- function(time, value, n_baseline, min_od, window, min_r2,
                              boot = 0, conf_level = 0.95) {
  baseline <- mean(utils::head(value, n_baseline))
  n <- value - baseline
  keep <- n > min_od

  if (sum(keep) < window + 2) {
    out <- gr_fit_failure(sprintf(
      "only %d point(s) above min_od = %g; nothing to fit", sum(keep), min_od
    ))
    out$fitted <- rep(NA_real_, length(time))
    return(out)
  }

  t_keep <- time[keep]
  y <- log(n[keep])
  n_win <- length(y) - window + 1

  slope <- intercept <- r2 <- numeric(n_win)
  for (i in seq_len(n_win)) {
    idx <- i:(i + window - 1)
    tw <- t_keep[idx]
    yw <- y[idx]
    slope[i] <- stats::cov(tw, yw) / stats::var(tw)
    intercept[i] <- mean(yw) - slope[i] * mean(tw)
    r2[i] <- stats::cor(tw, yw)^2
  }

  cand <- which(slope > 0 & r2 >= min_r2)
  if (length(cand) == 0) {
    out <- gr_fit_failure(sprintf(
      "no window of %d points with R^2 >= %g and positive slope", window, min_r2
    ))
    out$fitted <- rep(NA_real_, length(time))
    return(out)
  }

  best <- cand[which.max(slope[cand])]
  r <- slope[best]
  b <- intercept[best]
  idx <- best:(best + window - 1)

  # Initial log-density from the first readings that entered the regressions.
  log_n0 <- mean(utils::head(y, n_baseline))

  # Fitted exponential shown only over the winning window.
  fitted <- rep(NA_real_, length(time))
  fitted[which(keep)[idx]] <- exp(b + r * t_keep[idx]) + baseline

  ci <- list(r_lo = NA_real_, r_hi = NA_real_,
             K_lo = NA_real_, K_hi = NA_real_)
  if (boot > 0) {
    tw <- t_keep[idx]
    yw <- y[idx]
    yhat <- b + r * tw
    res_w <- yw - yhat
    reps <- vapply(seq_len(boot), function(i) {
      y_star <- yhat + sample(res_w, replace = TRUE)
      stats::cov(tw, y_star) / stats::var(tw)
    }, numeric(1))
    r_ci <- gr_boot_ci(reps, boot, conf_level)
    ci$r_lo <- r_ci[1]
    ci$r_hi <- r_ci[2]
  }

  list(
    params = c(list(
      model = "easylinear",
      r = r,
      K = max(stats::runmed(n[keep], 3)),
      N0 = exp(log_n0),
      lag = (log_n0 - b) / r,
      t_rmax = mean(t_keep[idx]),
      doubling_time = log(2) / r,
      sigma = stats::sd(exp(b + r * t_keep[idx]) - n[keep][idx])
    ), ci, list(
      fit_ok = TRUE,
      note = ""
    )),
    fitted = fitted
  )
}

#' Summarise growth parameters across replicates
#'
#' Aggregates the per-well growth parameters from [gr_fit()] over experimental
#' conditions: mean and standard deviation of `r`, `K`, `lag`, and
#' `doubling_time`, with the number of wells behind each estimate. This is the
#' step most fitting packages leave to you — combining technical and
#' biological replicates *after* excluding wells that QC flagged or whose fit
#' failed.
#'
#' By default wells are grouped by every metadata column added with
#' [gr_layout()] except the replicate identifiers (`bio_rep`, `tech_rep`), so
#' replicates of the same condition are averaged together. Pass `by` to group
#' differently — e.g. `by = c("strain", "medium", "bio_rep")` keeps biological
#' replicates separate and averages only technical ones.
#'
#' @param plate A `gr_plate` object after [gr_fit()].
#' @param by Character vector of metadata columns to group by. Default:
#'   all metadata columns except `bio_rep` and `tech_rep`. With no metadata at
#'   all, a single overall summary row is returned.
#' @param drop_flagged If `TRUE` (default), wells flagged by [gr_qc()] are
#'   excluded before averaging. Failed fits are always excluded.
#'
#' @return A tibble with the grouping columns, `n_wells`, and `<param>_mean` /
#'   `<param>_sd` for `r`, `K`, `lag`, and `doubling_time`.
#' @export
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate")) |>
#'   gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
#'   gr_qc() |>
#'   gr_fit()
#' gr_fit_summary(plate)
#' gr_fit_summary(plate, by = c("strain", "medium", "bio_rep"))
gr_fit_summary <- function(plate, by = NULL, drop_flagged = TRUE) {
  gr_assert_plate(plate)
  if (is.null(plate$fit)) {
    stop("No fit results; run gr_fit() first.", call. = FALSE)
  }

  meta_cols <- setdiff(
    names(plate$data),
    c("well", "row", "col", "time", "value", "value_raw", "fitted")
  )
  if (is.null(by)) {
    by <- setdiff(meta_cols, c("bio_rep", "tech_rep"))
  } else {
    missing_by <- setdiff(by, meta_cols)
    if (length(missing_by) > 0) {
      stop("Grouping column(s) not in the plate metadata: ",
           paste(missing_by, collapse = ", "),
           ". Add them with gr_layout().", call. = FALSE)
    }
  }

  df <- plate$fit
  if (drop_flagged && !is.null(plate$qc)) {
    df <- df[df$well %in% plate$qc$well[!plate$qc$flagged], ]
  }
  df <- df[df$fit_ok, ]

  if (length(by) > 0) {
    well_meta <- dplyr::distinct(
      plate$data, .data$well, dplyr::across(dplyr::all_of(by))
    )
    df <- dplyr::left_join(df, well_meta, by = "well")
  }

  df |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
    dplyr::summarise(
      n_wells = dplyr::n(),
      dplyr::across(
        dplyr::all_of(c("r", "K", "lag", "doubling_time")),
        list(mean = mean, sd = stats::sd)
      ),
      .groups = "drop"
    )
}

#' The results table: growth parameters joined with your metadata
#'
#' Returns the table you actually want after a fit: one row per well with the
#' experimental metadata from [gr_layout()] (strain, medium, replicates, ...),
#' the growth parameters from [gr_fit()], and the QC verdict from [gr_qc()] —
#' ready for plotting, statistics, or saving.
#'
#' This differs from `plate$fit` (parameters only, no metadata) and from
#' [gr_fit_summary()] (already averaged over replicates): `gr_results()` is
#' the full per-well table that sits between the two.
#'
#' @param plate A `gr_plate` object after [gr_fit()].
#' @param params Which fit parameters to include, any of `"r"`, `"K"`,
#'   `"lag"`, `"doubling_time"`, `"N0"`, `"t_rmax"`, `"sigma"`. Defaults to
#'   the first four — the ones most analyses care about.
#' @param drop_flagged If `TRUE`, wells flagged by [gr_qc()] are removed.
#'   Default `FALSE` — the `flagged` and `reasons` columns are included
#'   instead, so nothing disappears silently.
#' @param file Optional path; if given, the table is also written there as a
#'   CSV and the tibble returned invisibly.
#'
#' @return A tibble with columns `well`, `row`, `col`, the metadata columns,
#'   the requested parameters (with their `_lo`/`_hi` bootstrap intervals when
#'   [gr_fit()] was run with `boot > 0`), `fit_ok`, `note`, and (when QC has
#'   run) `flagged` and `reasons`.
#' @export
#' @seealso [gr_fit()], [gr_fit_summary()]
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate")) |>
#'   gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
#'   gr_qc() |>
#'   gr_fit()
#'
#' gr_results(plate)
#' gr_results(plate, params = c("r", "K"), drop_flagged = TRUE)
#' \dontrun{
#' gr_results(plate, file = "run1_growth_parameters.csv")
#' }
gr_results <- function(plate,
                       params = c("r", "K", "lag", "doubling_time"),
                       drop_flagged = FALSE,
                       file = NULL) {
  gr_assert_plate(plate)
  if (is.null(plate$fit)) {
    stop("No fit results; run gr_fit() first.", call. = FALSE)
  }
  params <- match.arg(
    params,
    c("r", "K", "lag", "doubling_time", "N0", "t_rmax", "sigma"),
    several.ok = TRUE
  )

  meta_cols <- setdiff(
    names(plate$data),
    c("well", "row", "col", "time", "value", "value_raw", "fitted")
  )
  # Bootstrap intervals (when gr_fit(boot > 0) computed them) travel with
  # their parameter.
  ci_cols <- intersect(
    paste0(rep(params, each = 2), c("_lo", "_hi")),
    names(plate$fit)
  )
  ci_cols <- ci_cols[vapply(plate$fit[ci_cols],
                            function(x) any(!is.na(x)), logical(1))]
  value_cols <- c(params, ci_cols)

  out <- plate$fit[c("well", "row", "col", value_cols, "fit_ok", "note")]
  if (length(meta_cols) > 0) {
    well_meta <- dplyr::distinct(
      plate$data, .data$well, dplyr::across(dplyr::all_of(meta_cols))
    )
    out <- dplyr::left_join(out, well_meta, by = "well")
    out <- out[c("well", "row", "col", meta_cols, value_cols,
                 "fit_ok", "note")]
  }

  if (!is.null(plate$qc)) {
    out <- dplyr::left_join(out, plate$qc[c("well", "flagged", "reasons")],
                            by = "well")
    if (drop_flagged) {
      out <- out[!out$flagged, ]
      out$flagged <- out$reasons <- NULL
    }
  } else if (drop_flagged) {
    stop("`drop_flagged = TRUE` requires QC results; run gr_qc() first.",
         call. = FALSE)
  }

  if (!is.null(file)) {
    utils::write.csv(out, file, row.names = FALSE)
    return(invisible(out))
  }
  out
}
