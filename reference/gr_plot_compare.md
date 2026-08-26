# Plot a growth parameter comparison

Visualises a
[`gr_compare()`](https://loukesio.github.io/gRate/reference/gr_compare.md)
result: one point per replicate (jittered), with the group mean and its
confidence interval overlaid as a crossbar.

## Usage

``` r
gr_plot_compare(cmp)
```

## Arguments

- cmp:

  A `gr_compare` object.

## Value

A ggplot object.

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate")) |>
  gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
  gr_qc() |>
  gr_fit()
gr_plot_compare(gr_compare(plate, what = "K", by = "medium"))
```
