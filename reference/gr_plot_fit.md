# Growth curves with fitted models overlaid

Plots the observed readings as points and the curve fitted by
[`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md) as a
line, one facet per well in plate position (or wrapped, for a subset).
For `method = "logistic"` the line spans the whole run; for
`method = "easylinear"` it is the fitted exponential drawn over the
winning regression window. Wells whose fit failed show points only.

## Usage

``` r
gr_plot_fit(plate, wells = NULL)
```

## Arguments

- plate:

  A `gr_plate` object after
  [`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md).

- wells:

  Optional character vector of well ids to restrict the plot to; facets
  then wrap instead of using the plate grid.

## Value

A ggplot object.

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
plate <- gr_fit(gr_qc(plate))
gr_plot_fit(plate, wells = c("A1", "B3", "C5"))
```
