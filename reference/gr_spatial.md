# Estimate and correct spatial (positional) artifacts

**Experimental.** Wells at the plate edge often read systematically
lower (evaporation, temperature gradients). This function estimates row
and column effects on a per-well summary statistic with Tukey's median
polish ([`stats::medpolish()`](https://rdrr.io/r/stats/medpolish.html))
and, optionally, corrects every curve multiplicatively.

## Usage

``` r
gr_spatial(
  plate,
  stat = c("max_od", "auc"),
  correct = TRUE,
  exclude_flagged = TRUE,
  n_baseline = 3
)
```

## Arguments

- plate:

  A `gr_plate` object, ideally after
  [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md).

- stat:

  Summary statistic to estimate effects on: `"max_od"` (default) or
  `"auc"`.

- correct:

  If `TRUE` (default), divide each curve by its estimated bias factor.
  The uncorrected values are kept in a `value_raw` column. If `FALSE`,
  effects are estimated and stored but the data are untouched.

- exclude_flagged:

  If `TRUE` (default) and QC has run, flagged wells are excluded from
  effect estimation.

- n_baseline:

  Passed to
  [`gr_summarise()`](https://loukesio.github.io/gRate/reference/gr_summarise.md)
  for the statistic computation.

## Value

The `gr_plate` with a `$spatial` element: a list with the `stat` used,
named vectors `row_effects` and `col_effects` (multiplicative, 1 = no
bias), the `overall` level, a per-well tibble `factors`, and `corrected`
(logical). If `correct = TRUE`, `$data$value` is replaced by the
corrected values and the original kept as `$data$value_raw`.

## Details

The statistic is computed per well, log-transformed, and decomposed into
overall + row + column effects. The multiplicative bias factor for a
well is `exp(row_effect + col_effect)`; correction divides the whole
curve by that factor. Wells flagged by
[`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) are
excluded from *estimating* the effects (they would distort the medians)
but still receive the correction.

Median polish captures row and column trends. A pure "outer ring" effect
is mostly absorbed (rows A/H and columns 1/12), but corner wells are
corrected twice over — inspect `gr_plot_plate(plate, "max_od")` before
and after, and treat this correction as a diagnostic aid, not gospel. It
is deliberately simple (no mixed models): if your design confounds
treatments with plate position, no correction can rescue it — randomise
the layout instead.

## See also

[`gr_plot_plate()`](https://loukesio.github.io/gRate/reference/gr_plot_plate.md)
to inspect the spatial pattern.

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
plate <- gr_qc(plate)
plate <- gr_spatial(plate)
plate$spatial$row_effects
#>         A         B         C         D         E         F         G         H 
#> 0.8749553 1.0319567 0.9888940 0.9963025 1.0037112 1.0427672 1.0069079 0.8693077 
plate
#> <gr_plate> 96 wells x 49 timepoints
#>   time: 0 to 24 (interval 0.5)
#>   instrument: generic, plate: growth_long
#>   QC: 5 flagged wells (no_growth: 2, spike: 3)
#>   spatial: corrected (stat: max_od)
```
