#' Construct a `gr_plate` object
#'
#' `gr_plate` is the single data structure every gRate function takes and
#' returns. It is a list with three components:
#'
#' * `$data` — a tidy tibble with one row per well and timepoint, columns
#'   `well`, `row`, `col`, `time`, `value`, plus any metadata columns added by
#'   [gr_layout()] and a `value_raw` column after [gr_spatial()] correction.
#' * `$qc` — a per-well tibble of QC flags, filled in by [gr_qc()]
#'   (`NULL` before QC has run).
#' * `$meta` — a list of plate-level metadata: `instrument`, `plate_id`,
#'   `read_interval`, and bookkeeping added by other functions.
#'
#' You rarely need to call `new_gr_plate()` yourself — [gr_read()] builds the
#' object from a raw export. It is exported so you can construct a plate from
#' data that is already tidy.
#'
#' @param data A data frame with columns `well`, `time`, `value`. `row` and
#'   `col` are derived from `well` if absent. Well ids are normalised (`"A01"`
#'   becomes `"A1"`).
#' @param qc Optional per-well QC tibble (normally left `NULL`; [gr_qc()]
#'   fills it in).
#' @param meta Named list of plate-level metadata.
#'
#' @return A `gr_plate` object.
#' @export
#' @examples
#' df <- expand.grid(well = c("A1", "A2"), time = 0:5)
#' df$value <- 0.05 + 0.01 * df$time
#' plate <- new_gr_plate(df)
#' plate
new_gr_plate <- function(data, qc = NULL, meta = list()) {
  data <- tibble::as_tibble(data)

  required <- c("well", "time", "value")
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols) > 0) {
    stop("`data` is missing required column(s): ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  data$well <- gr_norm_well(data$well)
  data$row <- gr_well_row(data$well)
  data$col <- gr_well_col(data$well)
  data$time <- as.numeric(data$time)
  data$value <- as.numeric(data$value)

  if (anyNA(data$time)) {
    stop("`time` contains missing or non-numeric values.", call. = FALSE)
  }
  if (anyDuplicated(data[c("well", "time")]) > 0) {
    stop("`data` contains duplicated well/time combinations.", call. = FALSE)
  }

  front <- c("well", "row", "col", "time", "value")
  data <- dplyr::select(
    data, dplyr::all_of(front), dplyr::everything()
  )
  data <- dplyr::arrange(data, .data$row, .data$col, .data$time)

  if (is.null(meta$read_interval)) {
    times <- sort(unique(data$time))
    meta$read_interval <- if (length(times) > 1) {
      stats::median(diff(times))
    } else {
      NA_real_
    }
  }

  structure(list(data = data, qc = qc, meta = meta), class = "gr_plate")
}

#' Test whether an object is a `gr_plate`
#'
#' @param x An object.
#' @return `TRUE` if `x` is a `gr_plate`, otherwise `FALSE`.
#' @export
#' @examples
#' path <- system.file("extdata", "growth_long.csv", package = "gRate")
#' is_gr_plate(gr_read(path))
#' is_gr_plate(mtcars)
is_gr_plate <- function(x) inherits(x, "gr_plate")

# Internal: stop unless `x` is a gr_plate.
gr_assert_plate <- function(x, arg = "plate") {
  if (!is_gr_plate(x)) {
    stop("`", arg, "` must be a gr_plate object created by gr_read().",
         call. = FALSE)
  }
  invisible(x)
}

#' @export
print.gr_plate <- function(x, ...) {
  n_wells <- dplyr::n_distinct(x$data$well)
  n_times <- dplyr::n_distinct(x$data$time)
  t_range <- range(x$data$time)

  cat(sprintf("<gr_plate> %d wells x %d timepoints\n", n_wells, n_times))
  cat(sprintf("  time: %g to %g", t_range[1], t_range[2]))
  if (!is.null(x$meta$read_interval) && !is.na(x$meta$read_interval)) {
    cat(sprintf(" (interval %g)", x$meta$read_interval))
  }
  cat("\n")

  if (!is.null(x$meta$instrument)) {
    cat(sprintf("  instrument: %s", x$meta$instrument))
    if (!is.null(x$meta$plate_id)) cat(sprintf(", plate: %s", x$meta$plate_id))
    cat("\n")
  }

  meta_cols <- setdiff(
    names(x$data),
    c("well", "row", "col", "time", "value", "value_raw", "fitted")
  )
  if (length(meta_cols) > 0) {
    cat("  metadata:", paste(meta_cols, collapse = ", "), "\n")
  }

  if (any(c("bio_rep", "tech_rep") %in% names(x$data))) {
    n_bio <- if ("bio_rep" %in% names(x$data)) {
      dplyr::n_distinct(x$data$bio_rep)
    } else {
      NA
    }
    n_tech <- if ("tech_rep" %in% names(x$data)) {
      dplyr::n_distinct(x$data$tech_rep)
    } else {
      NA
    }
    cat(sprintf(
      "  replicates: %s biological x %s technical\n",
      ifelse(is.na(n_bio), "?", n_bio), ifelse(is.na(n_tech), "?", n_tech)
    ))
  }

  if (is.null(x$qc)) {
    cat("  QC: not run (use gr_qc())\n")
  } else {
    flag_cols <- setdiff(names(x$qc), c("well", "row", "col", "flagged", "reasons"))
    counts <- vapply(x$qc[flag_cols], function(f) sum(f, na.rm = TRUE), integer(1))
    counts <- counts[counts > 0]
    n_flagged <- sum(x$qc$flagged, na.rm = TRUE)
    if (n_flagged == 0) {
      cat("  QC: all wells pass\n")
    } else {
      cat(sprintf(
        "  QC: %d flagged well%s (%s)\n",
        n_flagged, if (n_flagged == 1) "" else "s",
        paste(names(counts), counts, sep = ": ", collapse = ", ")
      ))
    }
  }

  if (!is.null(x$spatial)) {
    cat(sprintf(
      "  spatial: %s (stat: %s)\n",
      if (isTRUE(x$spatial$corrected)) "corrected" else "estimated, not corrected",
      x$spatial$stat
    ))
  }

  if (!is.null(x$fit)) {
    ok <- x$fit$fit_ok
    cat(sprintf(
      "  fit: %s (%d/%d wells), median r = %.3g\n",
      x$meta$fit_method %||% "?", sum(ok), length(ok),
      stats::median(x$fit$r[ok])
    ))
  }

  invisible(x)
}

#' Per-well summary statistics
#'
#' Computes simple per-well summaries of the growth curves: baseline (mean of
#' the first `n_baseline` readings), maximum value, rise above baseline, and
#' area under the curve. Used internally by [gr_qc()], [gr_spatial()] and
#' [gr_plot_plate()], and handy on its own for a quick look at a plate.
#'
#' @param plate A `gr_plate` object.
#' @param n_baseline Number of initial timepoints averaged to estimate the
#'   baseline of each well.
#'
#' @return A tibble with one row per well and columns `well`, `row`, `col`,
#'   `baseline`, `max_od`, `delta_od` (max minus baseline), and `auc`.
#' @export
#' @examples
#' path <- system.file("extdata", "growth_long.csv", package = "gRate")
#' plate <- gr_read(path)
#' gr_summarise(plate)
gr_summarise <- function(plate, n_baseline = 3) {
  gr_assert_plate(plate)
  plate$data |>
    dplyr::group_by(.data$well, .data$row, .data$col) |>
    dplyr::arrange(.data$time, .by_group = TRUE) |>
    dplyr::summarise(
      baseline = mean(utils::head(.data$value, n_baseline)),
      max_od = max(.data$value),
      delta_od = max(.data$value) - mean(utils::head(.data$value, n_baseline)),
      auc = gr_auc(.data$time, .data$value),
      .groups = "drop"
    )
}
