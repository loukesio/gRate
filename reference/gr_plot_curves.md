# Faceted growth curves with flagged wells highlighted

Plots every well's curve in its plate position (8 x 12 facet grid).
Wells flagged by
[`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) are
drawn in colour with the flag reasons available in the returned data;
unflagged wells are grey.

## Usage

``` r
gr_plot_curves(plate, colour_by = NULL, wells = NULL, raw = FALSE)
```

## Arguments

- plate:

  A `gr_plate` object.

- colour_by:

  Optional metadata column (added by
  [`gr_layout()`](https://loukesio.github.io/gRate/reference/gr_layout.md))
  to colour curves by instead of QC status.

- wells:

  Optional character vector of well ids to restrict the plot to (e.g.
  `c("A1", "B3")`); facets then wrap instead of using the plate grid.

- raw:

  If `TRUE` and the plate was spatially corrected, plot the uncorrected
  `value_raw` instead. Default `FALSE`.

## Value

A ggplot object.

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
plate <- gr_qc(plate)
gr_plot_curves(plate)

gr_plot_curves(plate, wells = c("A1", "C5", "F8"))
```
