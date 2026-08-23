#' Export a `gr_plate` for downstream analysis
#'
#' Turns a processed plate back into a plain data frame, in the shape a
#' downstream tool expects:
#'
#' * `"tidy"` (default) — one row per well and timepoint, with all metadata
#'   columns and, when [gr_qc()] has run, `flagged` and `reasons` joined in.
#' * `"growthcurver"` — a wide data frame with a `time` column and one column
#'   per well, ready for `growthcurver::SummarizeGrowthByPlate()`.
#' * `"gcplyr"` — a long data frame with columns `Well`, `Time`,
#'   `Measurements` (plus metadata), the tidy shape gcplyr's design functions
#'   expect.
#'
#' @param plate A `gr_plate` object.
#' @param as Output shape: `"tidy"`, `"growthcurver"`, or `"gcplyr"`.
#' @param drop_flagged If `TRUE`, wells flagged by [gr_qc()] are removed from
#'   the export. Default `FALSE` — gRate flags, you decide. Requires
#'   [gr_qc()] to have run.
#' @param collapse_tech If `TRUE`, technical replicates are averaged: rows are
#'   grouped by every metadata column except the well identity and `tech_rep`,
#'   plus time, and `value` becomes their mean. Requires a `tech_rep` column
#'   (designate one with [gr_layout()]) and only makes sense for the tidy
#'   shape, since averaged curves no longer belong to a single well. The
#'   result gains `n_wells` (wells averaged) and, if QC has run, `flagged`
#'   is `TRUE` when *any* contributing well was flagged (combine with
#'   `drop_flagged = TRUE` to average only clean wells).
#'
#' @return A data frame in the requested shape.
#' @export
#' @seealso [as_growthcurver()], [as_gcplyr()]
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#' plate <- gr_qc(plate)
#'
#' head(gr_export(plate))
#' gc_input <- gr_export(plate, as = "growthcurver", drop_flagged = TRUE)
#' names(gc_input)[1:5]
gr_export <- function(plate,
                      as = c("tidy", "growthcurver", "gcplyr"),
                      drop_flagged = FALSE,
                      collapse_tech = FALSE) {
  gr_assert_plate(plate)
  as <- match.arg(as)

  if (collapse_tech && as != "tidy") {
    stop(
      "`collapse_tech = TRUE` only applies to `as = \"tidy\"`: averaged ",
      "curves no longer belong to a single well, which the '", as,
      "' shape requires.",
      call. = FALSE
    )
  }

  df <- plate$data

  if (drop_flagged) {
    if (is.null(plate$qc)) {
      stop("`drop_flagged = TRUE` requires QC results; run gr_qc() first.",
           call. = FALSE)
    }
    keep <- plate$qc$well[!plate$qc$flagged]
    df <- df[df$well %in% keep, ]
  }

  switch(
    as,
    tidy = {
      if (!is.null(plate$qc)) {
        df <- dplyr::left_join(df, plate$qc[c("well", "flagged", "reasons")],
                               by = "well")
      }
      if (collapse_tech) {
        df <- gr_collapse_tech(df)
      }
      df
    },
    growthcurver = {
      wide <- df |>
        dplyr::select("time", "well", "value") |>
        tidyr::pivot_wider(names_from = "well", values_from = "value") |>
        dplyr::arrange(.data$time)
      as.data.frame(wide)
    },
    gcplyr = {
      out <- dplyr::rename(df, Well = "well", Time = "time",
                           Measurements = "value")
      as.data.frame(dplyr::select(out, -dplyr::any_of(c("row", "col", "value_raw"))))
    }
  )
}

#' Convert a `gr_plate` to growthcurver input
#'
#' Shorthand for `gr_export(plate, as = "growthcurver", ...)`: a wide data
#' frame with a `time` column and one column per well, the format
#' `growthcurver::SummarizeGrowthByPlate()` takes directly.
#'
#' @inheritParams gr_export
#' @return A wide data frame (`time` + one column per well).
#' @export
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#' plate <- gr_qc(plate)
#' d <- as_growthcurver(plate, drop_flagged = TRUE)
#' \dontrun{
#' growthcurver::SummarizeGrowthByPlate(d)
#' }
as_growthcurver <- function(plate, drop_flagged = FALSE) {
  gr_export(plate, as = "growthcurver", drop_flagged = drop_flagged)
}

#' Convert a `gr_plate` to gcplyr-style tidy data
#'
#' Shorthand for `gr_export(plate, as = "gcplyr", ...)`: a long data frame
#' with `Well`, `Time`, `Measurements` and any metadata columns, matching the
#' tidy shape used throughout gcplyr.
#'
#' @inheritParams gr_export
#' @return A long data frame with columns `Well`, `Time`, `Measurements`, plus
#'   metadata.
#' @export
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#' head(as_gcplyr(plate))
as_gcplyr <- function(plate, drop_flagged = FALSE) {
  gr_export(plate, as = "gcplyr", drop_flagged = drop_flagged)
}

# Internal: average technical replicates in a tidy export.
# Groups by time plus every column that is not well identity, tech_rep,
# measurement, or QC detail; value becomes the mean across the wells.
gr_collapse_tech <- function(df) {
  if (!"tech_rep" %in% names(df)) {
    stop(
      "`collapse_tech = TRUE` requires a 'tech_rep' column; designate one ",
      "with gr_layout(..., tech_rep = \"<column>\").",
      call. = FALSE
    )
  }

  drop_cols <- c("well", "row", "col", "tech_rep", "value", "value_raw",
                 "fitted", "flagged", "reasons")
  group_cols <- c(setdiff(names(df), c(drop_cols, "time")), "time")

  has_qc <- "flagged" %in% names(df)

  df |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
    dplyr::summarise(
      value = mean(.data$value),
      n_wells = dplyr::n_distinct(.data$well),
      flagged = if (has_qc) any(.data$flagged) else NA,
      .groups = "drop"
    ) |>
    (\(d) if (has_qc) d else dplyr::select(d, -"flagged"))()
}
