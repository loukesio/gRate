#' gRate colors and ggplot2 theme
#'
#' All gRate plots share one design system: a colorblind-validated categorical
#' palette (assigned in fixed slot order, never cycled), the multi-hue
#' `heatmap0` ramp for magnitude (heatmaps), a reserved status red for flagged
#' wells, and a quiet chart chrome — hairline gridlines, muted axis ink, no
#' decoration louder than the data.
#'
#' `gr_colors` exposes the named roles so your own plots can match:
#' `$series` (eight categorical hues in slot order), `$sequential` (the
#' nine-colour `heatmap0` ramp from the
#' [ltc palette package](https://github.com/loukesio/ltc_palettes), deep teal
#' through sand to dark red), `$flagged` (status red), `$fitted` (the
#' fit-line blue), and the ink roles `$ink`, `$ink2`, `$muted`, `$grid`,
#' `$baseline`, `$surface`, `$neutral`.
#'
#' @format `gr_colors` is a named list of hex colors and character vectors.
#' @export
#' @examples
#' gr_colors$series[1:3]
#' gr_colors$flagged
gr_colors <- list(
  # Categorical slots, fixed order (validated for adjacent-pair CVD safety).
  series = c(
    "#2a78d6", "#eb6834", "#1baf7a", "#eda100",
    "#e87ba4", "#008300", "#4a3aa7", "#e34948"
  ),
  # Heatmap ramp: the "heatmap0" palette from the ltc package
  # (github.com/loukesio/ltc_palettes), vendored with attribution. Multi-hue
  # so clustered values still separate on the plate maps.
  sequential = c(
    "#001219", "#005F73", "#0A9396", "#94D2BD", "#E9D8A6",
    "#EE9B00", "#CA6702", "#AE2012", "#9B2226"
  ),
  flagged = "#d03b3b",   # status red - reserved, never used for a series
  fitted = "#2a78d6",    # fitted-model lines
  ink = "#0b0b0b",       # titles
  ink2 = "#52514e",      # subtitles, legend, axis titles
  muted = "#898781",     # axis tick labels
  grid = "#e1e0d9",      # hairline gridlines
  baseline = "#c3c2b7",  # axes, de-emphasised data
  surface = "#fcfcfb",   # chart surface (also the tile-gap color)
  neutral = "#f0efec"    # "nothing to report" fill (unflagged wells)
)

#' @rdname gr_colors
#' @param base_size Base font size in points. Default `11`.
#' @return `theme_gr()` returns a ggplot2 theme object; add it to any plot.
#' @export
#' @examples
#' library(ggplot2)
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point(colour = gr_colors$series[1]) +
#'   theme_gr()
theme_gr <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      text = ggplot2::element_text(colour = gr_colors$ink2),
      plot.title = ggplot2::element_text(
        colour = gr_colors$ink, face = "bold",
        size = base_size + 2, margin = ggplot2::margin(b = 2)
      ),
      plot.subtitle = ggplot2::element_text(
        colour = gr_colors$ink2, size = base_size - 1,
        margin = ggplot2::margin(b = 8)
      ),
      plot.title.position = "plot",
      axis.title = ggplot2::element_text(
        colour = gr_colors$ink2, size = base_size - 1
      ),
      axis.text = ggplot2::element_text(
        colour = gr_colors$muted, size = base_size - 2
      ),
      panel.grid.major = ggplot2::element_line(
        colour = gr_colors$grid, linewidth = 0.3
      ),
      panel.grid.minor = ggplot2::element_blank(),
      legend.title = ggplot2::element_text(
        colour = gr_colors$ink2, size = base_size - 1
      ),
      legend.text = ggplot2::element_text(
        colour = gr_colors$ink2, size = base_size - 2
      ),
      strip.text = ggplot2::element_text(
        colour = gr_colors$ink2, size = base_size - 2
      ),
      plot.background = ggplot2::element_rect(
        fill = gr_colors$surface, colour = NA
      )
    )
}

# Internal: categorical scale in fixed slot order. Falls back to ggplot2's
# default (with a warning) past eight levels rather than cycling hues.
gr_scale_categorical <- function(aesthetic, n_levels, name = NULL) {
  if (n_levels > length(gr_colors$series)) {
    warning(
      "More than ", length(gr_colors$series), " groups; falling back to ",
      "default ggplot2 colours. Consider faceting or folding rare groups.",
      call. = FALSE
    )
    return(NULL)
  }
  if (aesthetic == "colour") {
    ggplot2::scale_colour_manual(values = gr_colors$series, name = name)
  } else {
    ggplot2::scale_fill_manual(values = gr_colors$series, name = name)
  }
}

# Internal: sequential fill for magnitude heatmaps. With `equalize`, the
# ramp's colours are anchored at the data's own quantiles, so values that
# cluster in a narrow band still spread across several hues; the colourbar
# warps to match, staying truthful. Falls back to a linear mapping when the
# data are (nearly) constant.
gr_scale_sequential <- function(x = NULL, name = NULL, equalize = TRUE) {
  pal <- gr_colors$sequential
  values <- NULL
  if (equalize && !is.null(x)) {
    x <- x[is.finite(x)]
    q <- stats::quantile(x, probs = seq(0, 1, length.out = length(pal)),
                         na.rm = TRUE, names = FALSE)
    if (length(unique(q)) > 2 && diff(range(q)) > 0) {
      pos <- (q - q[1]) / (q[length(q)] - q[1])
      keep <- !duplicated(pos)
      pal <- pal[keep]
      values <- pos[keep]
    }
  }
  ggplot2::scale_fill_gradientn(
    colours = pal, values = values, name = name, na.value = "white"
  )
}
