#' Flag problematic wells
#'
#' Runs per-well quality checks on the growth curves and records the results
#' in `plate$qc`. Wells are **flagged, never deleted** — downstream you decide
#' what to drop (see `drop_flagged` in [gr_export()]).
#'
#' Available checks:
#'
#' * `no_growth` — the curve never rises more than `no_growth_delta` above its
#'   baseline (mean of the first `n_baseline` readings). Empty or dead wells.
#' * `spike` — one or more single-timepoint jumps: a reading that is more than
#'   `spike_delta` above *both* neighbours (or below both). Typical of
#'   condensation, bubbles, or read glitches; a genuine growth rise never
#'   reverses in a single step.
#' * `drift` — the well rises but the curve is essentially a straight line
#'   (squared correlation with time above `drift_r2`, positive slope) with no
#'   sigmoid shape. Typical of evaporation or baseline drift.
#' * `late_jump` — flat for the first `late_frac` of the run, then a sudden
#'   rise of more than `late_jump_delta`. Contamination-like.
#' * `noisy` — the robust spread (median absolute deviation) of the residuals
#'   around a loess smooth exceeds `noisy_sd`. Robust so that isolated spikes,
#'   which have their own flag, do not also register as noise.
#'
#' Every threshold is an argument; the defaults are sensible for OD600 growth
#' curves read every 5–30 minutes but should be tuned to your instrument.
#'
#' @param plate A `gr_plate` object.
#' @param checks Character vector of checks to run. Defaults to all of
#'   `"no_growth"`, `"spike"`, `"drift"`, `"late_jump"`, `"noisy"`.
#' @param no_growth_delta Minimum rise above baseline (in OD units) for a well
#'   to count as grown. Default `0.05`.
#' @param n_baseline Number of initial readings averaged as the baseline.
#'   Default `3`.
#' @param spike_delta Minimum deviation from both neighbouring readings for a
#'   point to count as a spike. Default `0.1`.
#' @param drift_r2 Squared correlation with time above which a growing,
#'   monotone curve is considered linear drift. Default `0.95`.
#' @param late_frac Fraction of the run that must be flat before a rise counts
#'   as a late jump. Default `0.6`.
#' @param late_jump_delta Minimum rise after the flat period to flag a late
#'   jump. Default `0.1`.
#' @param noisy_sd Maximum robust residual spread (MAD) around a loess smooth.
#'   Default `0.02`.
#' @param noisy_span `span` passed to [stats::loess()] for the noise check.
#'   Default `0.25` — small enough that a sigmoid is followed closely, so the
#'   residuals measure noise rather than lack of fit.
#'
#' @return The `gr_plate` with `$qc` set: a tibble with one row per well,
#'   one logical column per check, `flagged` (any check failed) and `reasons`
#'   (comma-separated names of failed checks). The thresholds used are stored
#'   in `attr(plate$qc, "thresholds")`.
#' @export
#' @seealso [gr_plot_plate()] to visualise flags, [gr_export()] to drop
#'   flagged wells on export.
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#' plate <- gr_qc(plate)
#' plate
#' subset(plate$qc, flagged)
gr_qc <- function(plate,
                  checks = c("no_growth", "spike", "drift", "late_jump", "noisy"),
                  no_growth_delta = 0.05,
                  n_baseline = 3,
                  spike_delta = 0.1,
                  drift_r2 = 0.95,
                  late_frac = 0.6,
                  late_jump_delta = 0.1,
                  noisy_sd = 0.02,
                  noisy_span = 0.25) {
  gr_assert_plate(plate)
  checks <- match.arg(checks, several.ok = TRUE)

  per_well <- plate$data |>
    dplyr::group_by(.data$well, .data$row, .data$col) |>
    dplyr::arrange(.data$time, .by_group = TRUE) |>
    dplyr::summarise(
      no_growth = gr_check_no_growth(.data$time, .data$value,
                                     no_growth_delta, n_baseline),
      spike = gr_check_spike(.data$time, .data$value, spike_delta),
      drift = gr_check_drift(.data$time, .data$value,
                             drift_r2, no_growth_delta, n_baseline),
      late_jump = gr_check_late_jump(.data$time, .data$value,
                                     late_frac, late_jump_delta,
                                     no_growth_delta, n_baseline),
      noisy = gr_check_noisy(.data$time, .data$value, noisy_sd, noisy_span),
      .groups = "drop"
    )

  # Keep only the requested checks, in canonical order.
  per_well <- per_well[c("well", "row", "col", checks)]

  flag_mat <- as.matrix(per_well[checks])
  per_well$flagged <- rowSums(flag_mat, na.rm = TRUE) > 0
  per_well$reasons <- apply(flag_mat, 1, function(f) {
    paste(checks[which(f)], collapse = ", ")
  })

  qc <- tibble::as_tibble(per_well)
  attr(qc, "thresholds") <- list(
    checks = checks,
    no_growth_delta = no_growth_delta,
    n_baseline = n_baseline,
    spike_delta = spike_delta,
    drift_r2 = drift_r2,
    late_frac = late_frac,
    late_jump_delta = late_jump_delta,
    noisy_sd = noisy_sd,
    noisy_span = noisy_span
  )

  plate$qc <- qc
  plate
}

# --- individual checks ------------------------------------------------------
# Each takes the time/value vectors of ONE well, already sorted by time,
# and returns a single logical.

gr_check_no_growth <- function(time, value, no_growth_delta, n_baseline) {
  baseline <- mean(utils::head(value, n_baseline))
  (max(value) - baseline) < no_growth_delta
}

gr_check_spike <- function(time, value, spike_delta) {
  n <- length(value)
  if (n < 3) return(FALSE)
  mid <- value[2:(n - 1)]
  lag <- value[1:(n - 2)]
  lead <- value[3:n]
  up <- (mid - lag) > spike_delta & (mid - lead) > spike_delta
  down <- (lag - mid) > spike_delta & (lead - mid) > spike_delta
  any(up | down)
}

gr_check_drift <- function(time, value, drift_r2, no_growth_delta, n_baseline) {
  # Only meaningful for wells that rose at all; dead wells are no_growth.
  if (gr_check_no_growth(time, value, no_growth_delta, n_baseline)) {
    return(FALSE)
  }
  if (stats::sd(value) == 0) return(FALSE)
  r <- stats::cor(time, value)
  r > 0 && r^2 > drift_r2
}

gr_check_late_jump <- function(time, value, late_frac, late_jump_delta,
                               no_growth_delta, n_baseline) {
  t_split <- min(time) + late_frac * (max(time) - min(time))
  early <- value[time <= t_split]
  late <- value[time > t_split]
  if (length(early) < n_baseline || length(late) < 2) return(FALSE)
  baseline <- mean(utils::head(early, n_baseline))
  early_flat <- (max(early) - baseline) < no_growth_delta
  late_rise <- (max(late) - baseline) > late_jump_delta
  early_flat && late_rise
}

gr_check_noisy <- function(time, value, noisy_sd, noisy_span) {
  if (length(value) < 10) return(FALSE)
  fit <- tryCatch(
    suppressWarnings(
      stats::loess(value ~ time, span = noisy_span, degree = 2,
                   family = "symmetric")
    ),
    error = function(e) NULL
  )
  if (is.null(fit)) return(FALSE)
  # MAD, not SD: a robust scale so one or two spikes (which have their own
  # flag) do not also count as noise.
  stats::mad(stats::residuals(fit)) > noisy_sd
}
