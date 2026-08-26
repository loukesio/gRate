# Flag problematic wells

Runs per-well quality checks on the growth curves and records the
results in `plate$qc`. Wells are **flagged, never deleted** — downstream
you decide what to drop (see `drop_flagged` in
[`gr_export()`](https://loukesio.github.io/gRate/reference/gr_export.md)).

## Usage

``` r
gr_qc(
  plate,
  checks = c("no_growth", "spike", "drift", "late_jump", "noisy"),
  no_growth_delta = 0.05,
  n_baseline = 3,
  spike_delta = 0.1,
  drift_r2 = 0.95,
  late_frac = 0.6,
  late_jump_delta = 0.1,
  noisy_sd = 0.02,
  noisy_span = 0.25
)
```

## Arguments

- plate:

  A `gr_plate` object.

- checks:

  Character vector of checks to run. Defaults to all of `"no_growth"`,
  `"spike"`, `"drift"`, `"late_jump"`, `"noisy"`.

- no_growth_delta:

  Minimum rise above baseline (in OD units) for a well to count as
  grown. Default `0.05`.

- n_baseline:

  Number of initial readings averaged as the baseline. Default `3`.

- spike_delta:

  Minimum deviation from both neighbouring readings for a point to count
  as a spike. Default `0.1`.

- drift_r2:

  Squared correlation with time above which a growing, monotone curve is
  considered linear drift. Default `0.95`.

- late_frac:

  Fraction of the run that must be flat before a rise counts as a late
  jump. Default `0.6`.

- late_jump_delta:

  Minimum rise after the flat period to flag a late jump. Default `0.1`.

- noisy_sd:

  Maximum robust residual spread (MAD) around a loess smooth. Default
  `0.02`.

- noisy_span:

  `span` passed to
  [`stats::loess()`](https://rdrr.io/r/stats/loess.html) for the noise
  check. Default `0.25` — small enough that a sigmoid is followed
  closely, so the residuals measure noise rather than lack of fit.

## Value

The `gr_plate` with `$qc` set: a tibble with one row per well, one
logical column per check, `flagged` (any check failed) and `reasons`
(comma-separated names of failed checks). The thresholds used are stored
in `attr(plate$qc, "thresholds")`.

## Details

Available checks:

- `no_growth` — the curve never rises more than `no_growth_delta` above
  its baseline (mean of the first `n_baseline` readings). Empty or dead
  wells.

- `spike` — one or more single-timepoint jumps: a reading that is more
  than `spike_delta` above *both* neighbours (or below both). Typical of
  condensation, bubbles, or read glitches; a genuine growth rise never
  reverses in a single step.

- `drift` — the well rises but the curve is essentially a straight line
  (squared correlation with time above `drift_r2`, positive slope) with
  no sigmoid shape. Typical of evaporation or baseline drift.

- `late_jump` — flat for the first `late_frac` of the run, then a sudden
  rise of more than `late_jump_delta`. Contamination-like.

- `noisy` — the robust spread (median absolute deviation) of the
  residuals around a loess smooth exceeds `noisy_sd`. Robust so that
  isolated spikes, which have their own flag, do not also register as
  noise.

Every threshold is an argument; the defaults are sensible for OD600
growth curves read every 5–30 minutes but should be tuned to your
instrument.

## See also

[`gr_plot_plate()`](https://loukesio.github.io/gRate/reference/gr_plot_plate.md)
to visualise flags,
[`gr_export()`](https://loukesio.github.io/gRate/reference/gr_export.md)
to drop flagged wells on export.

## Examples

``` r
plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate"))
plate <- gr_qc(plate)
plate
#> <gr_plate> 96 wells x 49 timepoints
#>   time: 0 to 24 (interval 0.5)
#>   instrument: generic, plate: growth_long
#>   QC: 5 flagged wells (no_growth: 2, spike: 3)
subset(plate$qc, flagged)
#> # A tibble: 5 × 10
#>   well  row     col no_growth spike drift late_jump noisy flagged reasons  
#>   <chr> <chr> <int> <lgl>     <lgl> <lgl> <lgl>     <lgl> <lgl>   <chr>    
#> 1 B3    B         3 FALSE     TRUE  FALSE FALSE     FALSE TRUE    spike    
#> 2 C5    C         5 TRUE      FALSE FALSE FALSE     FALSE TRUE    no_growth
#> 3 D10   D        10 FALSE     TRUE  FALSE FALSE     FALSE TRUE    spike    
#> 4 F8    F         8 TRUE      FALSE FALSE FALSE     FALSE TRUE    no_growth
#> 5 G6    G         6 FALSE     TRUE  FALSE FALSE     FALSE TRUE    spike    
```
