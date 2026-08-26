# Render a one-page HTML QC report for a plate

Renders the bundled Quarto (`.qmd`) template into a standalone,
self-contained HTML report summarising the plate: metadata, per-well QC
flags with the thresholds used, plate heatmaps, growth curves, and (if
run) the spatial correction factors. Requires the `quarto` R package and
the Quarto CLI (bundled with recent RStudio, or from
<https://quarto.org/docs/get-started/>).

## Usage

``` r
gr_report(
  plate,
  file = "gRate_report.html",
  title = NULL,
  interactive = FALSE,
  quiet = TRUE
)
```

## Arguments

- plate:

  A `gr_plate` object, ideally after
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) (and
  optionally
  [`gr_spatial()`](https://loukesio.github.io/gRate/reference/gr_spatial.md)).

- file:

  Output HTML file path. Default `"gRate_report.html"` in the working
  directory.

- title:

  Report title. Defaults to the plate id if present.

- interactive:

  If `TRUE`, plots are rendered as zoomable, hoverable plotly widgets
  (hover a curve to see its well) and the results table becomes
  searchable and sortable. Requires the `plotly` and `DT` packages.
  Default `FALSE` (static figures).

- quiet:

  Passed to
  [`quarto::quarto_render()`](https://quarto-dev.github.io/quarto-r/reference/quarto_render.html).
  Default `TRUE`.

## Value

The path to the rendered HTML file, invisibly.

## Examples

``` r
# \donttest{
if (requireNamespace("quarto", quietly = TRUE) &&
    !is.null(quarto::quarto_path())) {
  plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
  plate <- gr_qc(plate)
  out <- gr_report(plate, file = file.path(tempdir(), "report.html"))
}
# }
```
