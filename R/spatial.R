#' Estimate and correct spatial (positional) artifacts
#'
#' **Experimental.** Wells at the plate edge
#' often read systematically lower (evaporation, temperature gradients). This
#' function estimates row and column effects on a per-well summary statistic
#' with Tukey's median polish ([stats::medpolish()]) and, optionally, corrects
#' every curve multiplicatively.
#'
#' The statistic is computed per well, log-transformed, and decomposed into
#' overall + row + column effects. The multiplicative bias factor for a well
#' is `exp(row_effect + col_effect)`; correction divides the whole curve by
#' that factor. Wells flagged by [gr_qc()] are excluded from *estimating* the
#' effects (they would distort the medians) but still receive the correction.
#'
#' Median polish captures row and column trends. A pure "outer ring" effect is
#' mostly absorbed (rows A/H and columns 1/12), but corner wells are corrected
#' twice over — inspect `gr_plot_plate(plate, "max_od")` before and after, and
#' treat this correction as a diagnostic aid, not gospel. It is deliberately
#' simple (no mixed models): if your design confounds treatments with plate
#' position, no correction can rescue it — randomise the layout instead.
#'
#' @param plate A `gr_plate` object, ideally after [gr_qc()].
#' @param stat Summary statistic to estimate effects on: `"max_od"` (default)
#'   or `"auc"`.
#' @param correct If `TRUE` (default), divide each curve by its estimated bias
#'   factor. The uncorrected values are kept in a `value_raw` column. If
#'   `FALSE`, effects are estimated and stored but the data are untouched.
#' @param exclude_flagged If `TRUE` (default) and QC has run, flagged wells are
#'   excluded from effect estimation.
#' @param n_baseline Passed to [gr_summarise()] for the statistic computation.
#'
#' @return The `gr_plate` with a `$spatial` element: a list with the `stat`
#'   used, named vectors `row_effects` and `col_effects` (multiplicative, 1 =
#'   no bias), the `overall` level, a per-well tibble `factors`, and
#'   `corrected` (logical). If `correct = TRUE`, `$data$value` is replaced by
#'   the corrected values and the original kept as `$data$value_raw`.
#' @export
#' @seealso [gr_plot_plate()] to inspect the spatial pattern.
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#' plate <- gr_qc(plate)
#' plate <- gr_spatial(plate)
#' plate$spatial$row_effects
#' plate
gr_spatial <- function(plate,
                       stat = c("max_od", "auc"),
                       correct = TRUE,
                       exclude_flagged = TRUE,
                       n_baseline = 3) {
  gr_assert_plate(plate)
  stat <- match.arg(stat)

  if (!is.null(plate$spatial) && isTRUE(plate$spatial$corrected)) {
    stop(
      "This plate has already been spatially corrected; ",
      "correcting twice would compound the adjustment.",
      call. = FALSE
    )
  }

  stats_tbl <- gr_summarise(plate, n_baseline = n_baseline)
  stats_tbl$.stat <- stats_tbl[[stat]]

  if (any(stats_tbl$.stat <= 0)) {
    stop(
      "Spatial correction needs strictly positive '", stat, "' values ",
      "(they are log-transformed). Check your blanking.",
      call. = FALSE
    )
  }

  estimate <- stats_tbl
  if (exclude_flagged && !is.null(plate$qc)) {
    estimate <- dplyr::left_join(
      estimate,
      plate$qc[c("well", "flagged")],
      by = "well"
    )
    estimate$.stat[which(estimate$flagged)] <- NA_real_
  }

  # 8x12 matrix of log(stat); NAs for excluded or absent wells.
  mat <- matrix(NA_real_, nrow = 8, ncol = 12,
                dimnames = list(LETTERS[1:8], as.character(1:12)))
  mat[cbind(match(estimate$row, LETTERS), estimate$col)] <- log(estimate$.stat)

  mp <- stats::medpolish(mat, na.rm = TRUE, trace.iter = FALSE)

  row_effects <- exp(mp$row)
  col_effects <- exp(mp$col)
  # Rows/columns with no usable wells get no adjustment.
  row_effects[is.na(row_effects)] <- 1
  col_effects[is.na(col_effects)] <- 1

  factors <- tibble::tibble(
    well = gr_all_wells(),
    row = gr_well_row(gr_all_wells()),
    col = gr_well_col(gr_all_wells()),
    factor = row_effects[gr_well_row(gr_all_wells())] *
      col_effects[as.character(gr_well_col(gr_all_wells()))]
  )

  plate$spatial <- list(
    stat = stat,
    overall = exp(mp$overall),
    row_effects = row_effects,
    col_effects = col_effects,
    factors = factors,
    corrected = correct
  )

  if (correct) {
    if (!"value_raw" %in% names(plate$data)) {
      plate$data$value_raw <- plate$data$value
    }
    plate$data <- plate$data |>
      dplyr::left_join(factors[c("well", "factor")], by = "well") |>
      dplyr::mutate(value = .data$value / .data$factor) |>
      dplyr::select(-"factor")
    plate$meta$spatial_corrected <- TRUE
  }

  plate
}
