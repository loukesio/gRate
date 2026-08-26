# Lag time by several methods, with agreement

Lag time is notoriously method-dependent: tangent constructions, model
fits, and threshold crossings can disagree by hours on the same well.
Rather than pretending one definition is "the" lag, `gr_lag()` computes
it several ways per well and reports how much the methods agree — large
disagreement usually means the curve shape violates one method's
assumptions, and is worth a look with
[`gr_plot_curves()`](https://loukesio.github.io/gRate/reference/gr_plot_curves.md).

## Usage

``` r
gr_lag(
  plate,
  methods = c("logistic", "gompertz", "easylinear", "threshold"),
  n_baseline = 3,
  min_od = 0.05,
  window = 5,
  min_r2 = 0.97,
  threshold = 0.05,
  max_sd = 1.5
)
```

## Arguments

- plate:

  A `gr_plate` object.

- methods:

  Which lag definitions to compute. Default: all four.

- n_baseline:

  Number of initial readings averaged as the baseline that is subtracted
  before fitting. Default `3`.

- min_od:

  For `method = "easylinear"`: baseline-subtracted values must exceed
  this before a point enters the log-scale regressions. Default `0.05`:
  generous relative to typical OD noise, because log-scale noise at
  near-blank readings otherwise inflates the steepest-window estimate.
  Lower it for low-density experiments with a quiet reader.

- window:

  For `method = "easylinear"`: number of consecutive points per rolling
  regression. Default `5` (Hall et al.'s choice).

- min_r2:

  For `method = "easylinear"`: minimum R-squared for a window to be
  considered exponential growth. Default `0.97`.

- threshold:

  Rise above baseline (in OD units) defining the `threshold` lag.
  Default `0.05`.

- max_sd:

  Maximum standard deviation across methods (in time units) for a well
  to count as `agree = TRUE`. Default `1.5`.

## Value

A tibble with one row per well: `lag_<method>` columns, `lag_mean`,
`lag_sd`, `lag_range` (max minus min), `n_methods` (how many succeeded),
and `agree` (`NA` when fewer than two methods succeeded).

## Details

Methods:

- `logistic` — tangent at the inflection of a logistic fit, extrapolated
  to the baseline (as in
  [`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md)).

- `gompertz` — the same tangent construction on a Gompertz fit.

- `easylinear` — the fitted exponential of the steepest log-linear
  window extrapolated down to the initial log-density (Hall et al.
  2014).

- `threshold` — the first time the (lightly smoothed) curve rises more
  than `threshold` above baseline. Model-free and simple; by
  construction it reads later than tangent methods on shallow curves and
  earlier on steep ones.

Methods that fail on a well (e.g. anything model-based on a dead well)
contribute `NA` and are excluded from the agreement statistics.

## See also

[`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md) for
the tangent definitions.

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
lags <- gr_lag(plate)
head(lags)
#> # A tibble: 6 × 12
#>   well  row     col lag_logistic lag_gompertz lag_easylinear lag_threshold
#>   <chr> <chr> <int>        <dbl>        <dbl>          <dbl>         <dbl>
#> 1 A1    A         1         4.82         4.60           4.00           3.5
#> 2 A2    A         2         4.81         4.59           4.00           3.5
#> 3 A3    A         3         4.81         4.59           4.51           4  
#> 4 A4    A         4         4.79         4.57           4.00           3.5
#> 5 A5    A         5         4.82         4.59           4.00           3.5
#> 6 A6    A         6         4.79         4.57           4.50           4  
#> # ℹ 5 more variables: lag_mean <dbl>, lag_sd <dbl>, lag_range <dbl>,
#> #   n_methods <int>, agree <lgl>
subset(lags, !agree)  # wells where the definitions disagree
#> # A tibble: 0 × 12
#> # ℹ 12 variables: well <chr>, row <chr>, col <int>, lag_logistic <dbl>,
#> #   lag_gompertz <dbl>, lag_easylinear <dbl>, lag_threshold <dbl>,
#> #   lag_mean <dbl>, lag_sd <dbl>, lag_range <dbl>, n_methods <int>, agree <lgl>
```
