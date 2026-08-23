#' Attach a plate layout (well metadata) to a `gr_plate`
#'
#' Joins experimental design information — strain, treatment, replicate,
#' anything per-well — onto the plate data. Two layout formats are accepted:
#'
#' * **long** — a data frame or CSV with a `well` column plus one column per
#'   metadata variable. This is the recommended format because it carries any
#'   number of variables at once.
#' * **grid** — an 8 x 12 table mirroring the physical plate (optionally with
#'   a leading column of row letters A-H), where each cell holds one value.
#'   The values become a single metadata column named by `name`. Call
#'   `gr_layout()` repeatedly to add several grid variables.
#'
#' The format is detected automatically: a table with a `well` column is
#' treated as long, an 8-row table with 12 value columns as a grid.
#'
#' ## Biological and technical replicates
#'
#' gRate treats two metadata columns as special: `bio_rep` (biological
#' replicate — independent cultures) and `tech_rep` (technical replicate —
#' the same culture measured in several wells). Layout columns already named
#' `bio_rep` / `tech_rep` are picked up automatically; otherwise point the
#' `bio_rep` / `tech_rep` arguments at the layout columns holding them and
#' they are renamed on the way in. Once designated, they show up in
#' [print()][new_gr_plate], can colour [gr_plot_curves()], and technical
#' replicates can be averaged on export
#' (`gr_export(collapse_tech = TRUE)`).
#'
#' @param plate A `gr_plate` object.
#' @param layout A data frame or path to a CSV/TSV/Excel file, in long or grid
#'   format.
#' @param name Name for the metadata column created from a grid layout
#'   (default `"content"`). Ignored for long layouts.
#' @param bio_rep Optional name of the layout column identifying biological
#'   replicates; it is renamed to `bio_rep`.
#' @param tech_rep Optional name of the layout column identifying technical
#'   replicates; it is renamed to `tech_rep`.
#' @param ... Additional arguments passed to the file reader when `layout` is
#'   a path.
#'
#' @return The `gr_plate` with metadata columns added to `$data`.
#' @export
#' @seealso [gr_read()], [gr_qc()]
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#'
#' # long layout: well + any number of metadata columns
#' plate <- gr_layout(
#'   plate,
#'   system.file("extdata", "layout_long.csv", package = "gRate")
#' )
#' plate
#'
#' # grid layout: an 8x12 table of values, one variable at a time
#' plate <- gr_layout(
#'   plate,
#'   system.file("extdata", "layout_grid.csv", package = "gRate"),
#'   name = "strain_grid"
#' )
#' head(plate$data)
gr_layout <- function(plate, layout, name = "content",
                      bio_rep = NULL, tech_rep = NULL, ...) {
  gr_assert_plate(plate)

  if (is.character(layout) && length(layout) == 1) {
    layout <- gr_read_table(layout, ...)
  }
  if (!is.data.frame(layout)) {
    stop("`layout` must be a data frame or a file path.", call. = FALSE)
  }

  layout <- tibble::as_tibble(layout, .name_repair = "minimal")

  for (rep_arg in c("bio_rep", "tech_rep")) {
    from <- get(rep_arg)
    if (is.null(from)) next
    if (!from %in% names(layout)) {
      stop("`", rep_arg, "` column '", from, "' not found in the layout.",
           call. = FALSE)
    }
    if (rep_arg %in% names(layout) && from != rep_arg) {
      stop("The layout already has a '", rep_arg, "' column; cannot also ",
           "rename '", from, "' to it.", call. = FALSE)
    }
    names(layout)[names(layout) == from] <- rep_arg
  }

  long <- if (!is.null(gr_match_col(layout, "well"))) {
    gr_layout_long(layout)
  } else {
    gr_layout_grid(layout, name = name)
  }

  clash <- intersect(setdiff(names(long), "well"), names(plate$data))
  if (length(clash) > 0) {
    stop(
      "Layout column(s) already present in the plate data: ",
      paste(clash, collapse = ", "),
      ". Rename them in the layout (or use a different `name`).",
      call. = FALSE
    )
  }

  unknown <- setdiff(long$well, unique(plate$data$well))
  if (length(unknown) > 0) {
    warning(
      "Layout contains well(s) not present in the plate data: ",
      paste(unknown, collapse = ", "),
      call. = FALSE
    )
  }
  uncovered <- setdiff(unique(plate$data$well), long$well)
  if (length(uncovered) > 0) {
    warning(
      length(uncovered), " well(s) in the plate data have no layout entry ",
      "and get NA metadata (e.g. ", uncovered[1], ").",
      call. = FALSE
    )
  }

  plate$data <- dplyr::left_join(plate$data, long, by = "well")
  plate
}

# Internal: long layout -> tibble(well, <metadata cols>).
gr_layout_long <- function(layout) {
  well_col <- gr_match_col(layout, "well")
  layout <- dplyr::rename(layout, well = dplyr::all_of(well_col))
  layout$well <- gr_norm_well(layout$well)
  if (anyDuplicated(layout$well) > 0) {
    dup <- unique(layout$well[duplicated(layout$well)])
    stop(
      "Layout has duplicated well id(s): ", paste(dup, collapse = ", "),
      call. = FALSE
    )
  }
  # row/col in a layout would clash with the plate's own; drop silently.
  layout[setdiff(names(layout), c("row", "col"))]
}

# Internal: 8x12 grid layout -> tibble(well, <name>).
gr_layout_grid <- function(layout, name) {
  # Allow a leading column of row letters (A-H) in any order.
  first <- toupper(trimws(as.character(layout[[1]])))
  row_labels <- LETTERS[1:8]
  if (nrow(layout) == 8 && all(sort(first) == row_labels)) {
    layout <- layout[order(match(first, row_labels)), -1]
  }

  if (nrow(layout) != 8 || ncol(layout) != 12) {
    stop(
      "Grid layouts must be 8 rows x 12 columns (optionally with a leading ",
      "column of row letters A-H); got ", nrow(layout), " x ", ncol(layout),
      ". For arbitrary metadata use a long layout with a 'well' column.",
      call. = FALSE
    )
  }

  values <- as.vector(t(as.matrix(layout)))
  out <- tibble::tibble(well = gr_all_wells(), value = values)
  names(out)[2] <- name
  out
}
