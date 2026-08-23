#' Render a one-page HTML QC report for a plate
#'
#' Renders the bundled Quarto (`.qmd`) template into a standalone,
#' self-contained HTML report summarising the plate: metadata, per-well QC
#' flags with the thresholds used, plate heatmaps, growth curves, and (if run)
#' the spatial correction factors. Requires the `quarto` R package and the
#' Quarto CLI (bundled with recent RStudio, or from
#' <https://quarto.org/docs/get-started/>).
#'
#' @param plate A `gr_plate` object, ideally after [gr_qc()] (and optionally
#'   [gr_spatial()]).
#' @param file Output HTML file path. Default `"gRate_report.html"` in the
#'   working directory.
#' @param title Report title. Defaults to the plate id if present.
#' @param interactive If `TRUE`, plots are rendered as zoomable, hoverable
#'   plotly widgets (hover a curve to see its well) and the results table
#'   becomes searchable and sortable. Requires the `plotly` and `DT`
#'   packages. Default `FALSE` (static figures).
#' @param quiet Passed to [quarto::quarto_render()]. Default `TRUE`.
#'
#' @return The path to the rendered HTML file, invisibly.
#' @export
#' @examples
#' \donttest{
#' if (requireNamespace("quarto", quietly = TRUE) &&
#'     !is.null(quarto::quarto_path())) {
#'   plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
#'   plate <- gr_qc(plate)
#'   out <- gr_report(plate, file = file.path(tempdir(), "report.html"))
#' }
#' }
gr_report <- function(plate,
                      file = "gRate_report.html",
                      title = NULL,
                      interactive = FALSE,
                      quiet = TRUE) {
  gr_assert_plate(plate)

  if (interactive) {
    missing_pkgs <- c("plotly", "DT")[!vapply(
      c("plotly", "DT"), requireNamespace, logical(1), quietly = TRUE
    )]
    if (length(missing_pkgs) > 0) {
      stop("interactive = TRUE requires the ",
           paste(missing_pkgs, collapse = " and "), " package(s). ",
           "Install with install.packages(c(\"plotly\", \"DT\")).",
           call. = FALSE)
    }
  }

  if (!requireNamespace("quarto", quietly = TRUE)) {
    stop("gr_report() requires the 'quarto' package. ",
         "Install it with install.packages(\"quarto\").", call. = FALSE)
  }
  if (is.null(quarto::quarto_path())) {
    stop("gr_report() requires the Quarto CLI (bundled with recent RStudio, ",
         "or see https://quarto.org/docs/get-started/).", call. = FALSE)
  }

  if (is.null(title)) {
    title <- if (!is.null(plate$meta$plate_id)) {
      paste("gRate report:", plate$meta$plate_id)
    } else {
      "gRate report"
    }
  }

  template <- system.file("qmd", "report.qmd", package = "gRate")
  if (template == "") {
    stop("Report template not found; reinstall gRate.", call. = FALSE)
  }

  file <- normalizePath(file, mustWork = FALSE)

  # Quarto renders next to its input, so work in a temp copy: the template,
  # the plate serialised to RDS, and the rendered HTML all live there until
  # the HTML is copied to `file`.
  work_dir <- tempfile("gRate-report-")
  dir.create(work_dir)
  on.exit(unlink(work_dir, recursive = TRUE), add = TRUE)

  input <- file.path(work_dir, "report.qmd")
  file.copy(template, input)
  saveRDS(plate, file.path(work_dir, "plate.rds"))

  quarto::quarto_render(
    input = input,
    output_file = "report.html",
    execute_params = list(plate_rds = "plate.rds", title = title,
                          interactive = interactive),
    quiet = quiet
  )

  rendered <- file.path(work_dir, "report.html")
  if (!file.exists(rendered)) {
    stop("Quarto did not produce the expected report file.", call. = FALSE)
  }
  if (!dir.exists(dirname(file))) {
    dir.create(dirname(file), recursive = TRUE)
  }
  file.copy(rendered, file, overwrite = TRUE)

  invisible(file)
}
