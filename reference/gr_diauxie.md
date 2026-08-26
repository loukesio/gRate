# Detect multi-phase (diauxic) growth

Scans every well for multiple growth phases — the classic diauxic shift
when a culture exhausts one carbon source and switches to another. The
per-capita growth rate profile is estimated by rolling regressions on
the log-scale curve (the same machinery as
`gr_fit(method = "easylinear")`); distinct phases appear as separate
peaks in that profile with a genuine trough between them.

## Usage

``` r
gr_diauxie(
  plate,
  n_baseline = 3,
  min_od = 0.05,
  window = 5,
  min_rate = 0.1,
  drop_frac = 0.5
)
```

## Arguments

- plate:

  A `gr_plate` object.

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

- min_rate:

  Minimum per-capita rate (in 1/time units) for a slope peak to count as
  a growth phase. Default `0.1`.

- drop_frac:

  The slope must fall below this fraction of the smaller of two
  neighbouring peaks for them to count as separate phases. Default
  `0.5`.

## Value

A tibble with one row per well: `n_phases`, `diauxic` (`n_phases >= 2`;
`NA` where the profile could not be estimated), per-phase rates and
times `r1`/`t1`, `r2`/`t2` (the two largest-rate phases in time order;
`NA` where absent), `trough_t` (time of the minimum between them), and
`note`.

## Details

A phase is a local maximum of the (median-smoothed) slope profile of at
least `min_rate`. Two neighbouring peaks count as separate phases only
if the slope drops below `drop_frac` times the smaller peak somewhere
between them — otherwise they are merged and the higher one kept. This
guards against calling noise wiggles "phases".

## See also

[`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md) for
single-phase rate estimation; use
[`gr_plot_curves()`](https://loukesio.github.io/gRate/reference/gr_plot_curves.md)
on flagged wells to see the shift.

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
dx <- gr_diauxie(plate)
table(dx$diauxic, useNA = "ifany")
#> 
#> FALSE  <NA> 
#>    94     2 
```
