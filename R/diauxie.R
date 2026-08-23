#' Detect multi-phase (diauxic) growth
#'
#' Scans every well for multiple growth phases — the classic diauxic shift
#' when a culture exhausts one carbon source and switches to another. The
#' per-capita growth rate profile is estimated by rolling regressions on the
#' log-scale curve (the same machinery as `gr_fit(method = "easylinear")`);
#' distinct phases appear as separate peaks in that profile with a genuine
#' trough between them.
#'
#' A phase is a local maximum of the (median-smoothed) slope profile of at
#' least `min_rate`. Two neighbouring peaks count as separate phases only if
#' the slope drops below `drop_frac` times the smaller peak somewhere between
#' them — otherwise they are merged and the higher one kept. This guards
#' against calling noise wiggles "phases".
#'
#' @param plate A `gr_plate` object.
#' @inheritParams gr_fit
#' @param min_rate Minimum per-capita rate (in 1/time units) for a slope peak
#'   to count as a growth phase. Default `0.1`.
#' @param drop_frac The slope must fall below this fraction of the smaller of
#'   two neighbouring peaks for them to count as separate phases. Default
#'   `0.5`.
#'
#' @return A tibble with one row per well: `n_phases`, `diauxic`
#'   (`n_phases >= 2`; `NA` where the profile could not be estimated),
#'   per-phase rates and times `r1`/`t1`, `r2`/`t2` (the two largest-rate
#'   phases in time order; `NA` where absent), `trough_t` (time of the
#'   minimum between them), and `note`.
#' @export
#' @seealso [gr_fit()] for single-phase rate estimation; use
#'   [gr_plot_curves()] on flagged wells to see the shift.
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#' dx <- gr_diauxie(plate)
#' table(dx$diauxic, useNA = "ifany")
gr_diauxie <- function(plate,
                       n_baseline = 3,
                       min_od = 0.05,
                       window = 5,
                       min_rate = 0.1,
                       drop_frac = 0.5) {
  gr_assert_plate(plate)

  data <- dplyr::arrange(plate$data, .data$well, .data$time)
  rows <- lapply(split(seq_len(nrow(data)), data$well), function(idx) {
    gr_detect_phases(data$time[idx], data$value[idx],
                     n_baseline, min_od, window, min_rate, drop_frac)
  })

  well_pos <- dplyr::distinct(plate$data, .data$well, .data$row, .data$col)
  dplyr::bind_rows(rows, .id = "well") |>
    dplyr::left_join(well_pos, by = "well") |>
    dplyr::select("well", "row", "col", dplyr::everything()) |>
    dplyr::arrange(.data$row, .data$col)
}

# Internal: phase detection for one well (time-sorted vectors).
gr_detect_phases <- function(time, value, n_baseline, min_od, window,
                             min_rate, drop_frac) {
  empty <- tibble::tibble(
    n_phases = 0L, diauxic = NA,
    r1 = NA_real_, t1 = NA_real_, r2 = NA_real_, t2 = NA_real_,
    trough_t = NA_real_, note = ""
  )

  baseline <- mean(utils::head(value, n_baseline))
  n <- value - baseline
  keep <- n > min_od
  if (sum(keep) < window + 2) {
    empty$note <- sprintf("only %d point(s) above min_od = %g",
                          sum(keep), min_od)
    return(empty)
  }

  t_keep <- time[keep]
  y <- log(n[keep])
  n_win <- length(y) - window + 1
  slope <- t_mid <- numeric(n_win)
  for (i in seq_len(n_win)) {
    j <- i:(i + window - 1)
    slope[i] <- stats::cov(t_keep[j], y[j]) / stats::var(t_keep[j])
    t_mid[i] <- mean(t_keep[j])
  }
  slope <- stats::runmed(slope, 3)

  # Local maxima of the slope profile at or above min_rate.
  peaks <- which(
    slope >= min_rate &
      slope >= c(-Inf, slope[-n_win]) &
      slope >= c(slope[-1], Inf)
  )
  # Plateaus produce runs of equal values; keep one peak per run.
  if (length(peaks) > 1) {
    peaks <- peaks[c(TRUE, diff(peaks) > 1)]
  }
  if (length(peaks) == 0) {
    empty$diauxic <- FALSE
    empty$note <- sprintf("no growth phase above min_rate = %g", min_rate)
    return(empty)
  }

  # Merge peaks that lack a genuine trough between them.
  merged <- peaks[1]
  for (p in peaks[-1]) {
    last <- merged[length(merged)]
    valley <- min(slope[last:p])
    if (valley < drop_frac * min(slope[last], slope[p])) {
      merged <- c(merged, p)
    } else if (slope[p] > slope[last]) {
      merged[length(merged)] <- p
    }
  }

  phases <- merged[order(t_mid[merged])]
  out <- empty
  out$n_phases <- length(phases)
  out$diauxic <- length(phases) >= 2
  out$r1 <- slope[phases[1]]
  out$t1 <- t_mid[phases[1]]
  if (length(phases) >= 2) {
    out$r2 <- slope[phases[2]]
    out$t2 <- t_mid[phases[2]]
    between <- phases[1]:phases[2]
    out$trough_t <- t_mid[between[which.min(slope[between])]]
  }
  out
}
