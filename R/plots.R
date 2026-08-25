#' Plate heatmap of a statistic, QC flag, or metadata variable
#'
#' Draws the plate as an 8 x 12 grid (row A at the top, as you look at the
#' plate) with each well coloured by:
#'
#' * a summary statistic — `"max_od"` (default), `"auc"`, `"delta_od"`,
#'   `"baseline"`;
#' * a QC result — `"flagged"` or any individual check name run by [gr_qc()]
#'   (e.g. `"spike"`);
#' * a growth parameter from [gr_fit()] — `"r"`, `"K"`, `"lag"`,
#'   `"doubling_time"`, `"t_rmax"`, `"N0"`, `"sigma"`, or `"fit_ok"`;
#' * any metadata column added by [gr_layout()].
#'
#' @param plate A `gr_plate` object.
#' @param fill What to colour wells by (see Details). Default `"max_od"`.
#' @param label If `TRUE`, print the value in each well (rounded for numeric
#'   fills). Default `FALSE`.
#' @param equalize For numeric fills: if `TRUE` (default), the heatmap ramp's
#'   colours are anchored at the data's own quantiles, so wells that cluster
#'   in a narrow value band still separate visibly (the colourbar warps to
#'   match, staying truthful). Set `FALSE` for a plain linear mapping.
#'
#' @return A ggplot object (modify or print it like any other ggplot).
#' @export
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#' plate <- gr_qc(plate)
#' gr_plot_plate(plate, "max_od")
#' gr_plot_plate(plate, "flagged")
gr_plot_plate <- function(plate, fill = "max_od", label = FALSE,
                          equalize = TRUE) {
  gr_assert_plate(plate)

  summary_stats <- c("max_od", "auc", "delta_od", "baseline")
  qc_cols <- if (is.null(plate$qc)) character(0) else {
    setdiff(names(plate$qc), c("well", "row", "col", "reasons"))
  }
  fit_cols <- if (is.null(plate$fit)) character(0) else {
    setdiff(names(plate$fit), c("well", "row", "col", "note"))
  }
  meta_cols <- setdiff(
    names(plate$data),
    c("well", "row", "col", "time", "value", "value_raw", "fitted")
  )

  if (fill %in% summary_stats) {
    df <- gr_summarise(plate)
  } else if (fill %in% qc_cols) {
    df <- plate$qc
  } else if (fill %in% fit_cols) {
    df <- plate$fit
  } else if (fill %in% meta_cols) {
    df <- dplyr::distinct(
      plate$data, .data$well, .data$row, .data$col,
      .data[[fill]]
    )
  } else {
    stop(
      "Cannot plot '", fill, "'. Available: ",
      paste(c(summary_stats, qc_cols, fit_cols, meta_cols), collapse = ", "),
      if (is.null(plate$qc)) " (run gr_qc() for QC flags)" else "",
      if (is.null(plate$fit)) " (run gr_fit() for growth parameters)" else "",
      call. = FALSE
    )
  }

  df$row <- factor(df$row, levels = rev(LETTERS[1:8]))
  df$col <- factor(df$col, levels = 1:12)

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$col, y = .data$row,
                                        fill = .data[[fill]])) +
    # Tiles are separated by a gap in the surface colour, not a drawn border.
    ggplot2::geom_tile(colour = gr_colors$surface, linewidth = 0.6) +
    ggplot2::scale_x_discrete(position = "top", drop = FALSE) +
    ggplot2::scale_y_discrete(drop = FALSE) +
    ggplot2::coord_fixed() +
    ggplot2::labs(x = NULL, y = NULL, fill = fill,
                  title = paste("Plate map:", fill)) +
    theme_gr() +
    ggplot2::theme(panel.grid = ggplot2::element_blank())

  if (is.numeric(df[[fill]])) {
    p <- p + gr_scale_sequential(df[[fill]], name = fill,
                                 equalize = equalize)
  } else if (is.logical(df[[fill]])) {
    is_qc_flag <- fill %in% qc_cols && fill != "fit_ok"
    p <- p + ggplot2::scale_fill_manual(
      values = stats::setNames(
        if (is_qc_flag) c(gr_colors$neutral, gr_colors$flagged)
        else c(gr_colors$flagged, gr_colors$neutral),
        c("FALSE", "TRUE")
      ),
      labels = if (is_qc_flag) {
        c(`FALSE` = "pass", `TRUE` = "flagged")
      } else {
        ggplot2::waiver()
      },
      na.value = "white"
    )
  } else {
    scale <- gr_scale_categorical("fill", dplyr::n_distinct(df[[fill]]),
                                  name = fill)
    if (!is.null(scale)) p <- p + scale
  }

  if (label) {
    df$.label <- if (is.numeric(df[[fill]])) {
      signif(df[[fill]], 2)
    } else {
      df[[fill]]
    }
    p <- p + ggplot2::geom_text(
      data = df,
      ggplot2::aes(label = .data$.label),
      inherit.aes = TRUE, size = 2.5, colour = "white"
    )
  }

  p
}

#' Faceted growth curves with flagged wells highlighted
#'
#' Plots every well's curve in its plate position (8 x 12 facet grid). Wells
#' flagged by [gr_qc()] are drawn in colour with the flag reasons available in
#' the returned data; unflagged wells are grey.
#'
#' @param plate A `gr_plate` object.
#' @param colour_by Optional metadata column (added by [gr_layout()]) to
#'   colour curves by instead of QC status.
#' @param wells Optional character vector of well ids to restrict the plot to
#'   (e.g. `c("A1", "B3")`); facets then wrap instead of using the plate grid.
#' @param raw If `TRUE` and the plate was spatially corrected, plot the
#'   uncorrected `value_raw` instead. Default `FALSE`.
#'
#' @return A ggplot object.
#' @export
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#' plate <- gr_qc(plate)
#' gr_plot_curves(plate)
#' gr_plot_curves(plate, wells = c("A1", "C5", "F8"))
gr_plot_curves <- function(plate, colour_by = NULL, wells = NULL, raw = FALSE) {
  gr_assert_plate(plate)

  df <- plate$data
  if (raw) {
    if (!"value_raw" %in% names(df)) {
      stop("No `value_raw` column: the plate has not been spatially corrected.",
           call. = FALSE)
    }
    df$value <- df$value_raw
  }

  if (!is.null(wells)) {
    wells <- gr_norm_well(wells)
    df <- df[df$well %in% wells, ]
    if (nrow(df) == 0) stop("None of the requested wells are in the plate.",
                            call. = FALSE)
  }

  if (!is.null(plate$qc)) {
    df <- dplyr::left_join(df, plate$qc[c("well", "flagged", "reasons")],
                           by = "well")
  } else {
    df$flagged <- FALSE
  }

  df$row <- factor(df$row, levels = LETTERS[1:8])

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$time, y = .data$value,
                                        group = .data$well))

  lw <- if (is.null(wells)) 0.4 else 0.8

  if (!is.null(colour_by)) {
    if (!colour_by %in% names(df)) {
      stop("Column '", colour_by, "' not found; add it with gr_layout().",
           call. = FALSE)
    }
    p <- p + ggplot2::geom_line(ggplot2::aes(colour = .data[[colour_by]]),
                                linewidth = lw)
    scale <- gr_scale_categorical("colour",
                                  dplyr::n_distinct(df[[colour_by]]),
                                  name = colour_by)
    if (!is.null(scale)) p <- p + scale
  } else {
    p <- p +
      ggplot2::geom_line(ggplot2::aes(colour = .data$flagged),
                         linewidth = lw) +
      ggplot2::scale_colour_manual(
        values = stats::setNames(
          c(gr_colors$baseline, gr_colors$flagged), c("FALSE", "TRUE")
        ),
        labels = c(`FALSE` = "pass", `TRUE` = "flagged"),
        name = "QC"
      )
  }

  if (is.null(wells)) {
    p <- p + ggplot2::facet_grid(
      rows = ggplot2::vars(.data$row),
      cols = ggplot2::vars(.data$col)
    )
  } else {
    p <- p + ggplot2::facet_wrap(ggplot2::vars(.data$well))
  }

  p +
    ggplot2::labs(x = "time", y = "value") +
    theme_gr(base_size = 9) +
    ggplot2::theme(
      axis.text = ggplot2::element_text(size = 5)
    )
}

#' Growth curves with fitted models overlaid
#'
#' Plots the observed readings as points and the curve fitted by [gr_fit()]
#' as a line, one facet per well in plate position (or wrapped, for a
#' subset). For `method = "logistic"` the line spans the whole run; for
#' `method = "easylinear"` it is the fitted exponential drawn over the
#' winning regression window. Wells whose fit failed show points only.
#'
#' @param plate A `gr_plate` object after [gr_fit()].
#' @param wells Optional character vector of well ids to restrict the plot to;
#'   facets then wrap instead of using the plate grid.
#'
#' @return A ggplot object.
#' @export
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#' plate <- gr_fit(gr_qc(plate))
#' gr_plot_fit(plate, wells = c("A1", "B3", "C5"))
gr_plot_fit <- function(plate, wells = NULL) {
  gr_assert_plate(plate)
  if (!"fitted" %in% names(plate$data)) {
    stop("No fitted curves; run gr_fit() first.", call. = FALSE)
  }

  df <- plate$data
  if (!is.null(wells)) {
    wells <- gr_norm_well(wells)
    df <- df[df$well %in% wells, ]
    if (nrow(df) == 0) stop("None of the requested wells are in the plate.",
                            call. = FALSE)
  }
  df$row <- factor(df$row, levels = LETTERS[1:8])

  pt_size <- if (is.null(wells)) 0.3 else 0.7
  lw <- if (is.null(wells)) 0.5 else 0.8

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$time, group = .data$well)) +
    ggplot2::geom_point(ggplot2::aes(y = .data$value),
                        size = pt_size, colour = gr_colors$muted) +
    ggplot2::geom_line(
      data = df[!is.na(df$fitted), ],
      ggplot2::aes(y = .data$fitted),
      colour = gr_colors$fitted, linewidth = lw
    )

  if (is.null(wells)) {
    p <- p + ggplot2::facet_grid(
      rows = ggplot2::vars(.data$row),
      cols = ggplot2::vars(.data$col)
    )
  } else {
    p <- p + ggplot2::facet_wrap(ggplot2::vars(.data$well))
  }

  base <- if (is.null(wells)) 9 else 11

  p +
    ggplot2::labs(
      x = "time", y = "value",
      title = paste0("Fitted growth curves (",
                     plate$meta$fit_method %||% "unknown method", ")")
    ) +
    theme_gr(base_size = base) +
    ggplot2::theme(
      axis.text = ggplot2::element_text(size = base - 4)
    )
}
