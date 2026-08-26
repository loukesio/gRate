# Package index

## Read and annotate

From raw export to an annotated plate object.

- [`gr_read()`](https://loukesio.github.io/gRate/reference/gr_read.md) :

  Read a plate reader export into a `gr_plate` object

- [`gr_layout()`](https://loukesio.github.io/gRate/reference/gr_layout.md)
  :

  Attach a plate layout (well metadata) to a `gr_plate`

- [`new_gr_plate()`](https://loukesio.github.io/gRate/reference/new_gr_plate.md)
  :

  Construct a `gr_plate` object

- [`is_gr_plate()`](https://loukesio.github.io/gRate/reference/is_gr_plate.md)
  :

  Test whether an object is a `gr_plate`

- [`gr_summarise()`](https://loukesio.github.io/gRate/reference/gr_summarise.md)
  : Per-well summary statistics

## Quality control

- [`gr_qc()`](https://loukesio.github.io/gRate/reference/gr_qc.md) :
  Flag problematic wells

## Spatial correction

- [`gr_spatial()`](https://loukesio.github.io/gRate/reference/gr_spatial.md)
  : Estimate and correct spatial (positional) artifacts

## Growth parameters

Fitting, uncertainty, lag, diauxie, and the results tables.

- [`gr_fit()`](https://loukesio.github.io/gRate/reference/gr_fit.md) :
  Fit growth models and estimate growth parameters per well
- [`gr_results()`](https://loukesio.github.io/gRate/reference/gr_results.md)
  : The results table: growth parameters joined with your metadata
- [`gr_fit_summary()`](https://loukesio.github.io/gRate/reference/gr_fit_summary.md)
  : Summarise growth parameters across replicates
- [`gr_lag()`](https://loukesio.github.io/gRate/reference/gr_lag.md) :
  Lag time by several methods, with agreement
- [`gr_diauxie()`](https://loukesio.github.io/gRate/reference/gr_diauxie.md)
  : Detect multi-phase (diauxic) growth

## Compare groups

- [`gr_compare()`](https://loukesio.github.io/gRate/reference/gr_compare.md)
  : Compare growth parameters between strains or conditions
- [`gr_plot_compare()`](https://loukesio.github.io/gRate/reference/gr_plot_compare.md)
  : Plot a growth parameter comparison

## Plots and theme

- [`gr_plot_plate()`](https://loukesio.github.io/gRate/reference/gr_plot_plate.md)
  : Plate heatmap of a statistic, QC flag, or metadata variable
- [`gr_plot_curves()`](https://loukesio.github.io/gRate/reference/gr_plot_curves.md)
  : Faceted growth curves with flagged wells highlighted
- [`gr_plot_fit()`](https://loukesio.github.io/gRate/reference/gr_plot_fit.md)
  : Growth curves with fitted models overlaid
- [`gr_colors`](https://loukesio.github.io/gRate/reference/gr_colors.md)
  [`theme_gr()`](https://loukesio.github.io/gRate/reference/gr_colors.md)
  : gRate colors and ggplot2 theme

## Export and report

- [`gr_export()`](https://loukesio.github.io/gRate/reference/gr_export.md)
  :

  Export a `gr_plate` for downstream analysis

- [`as_growthcurver()`](https://loukesio.github.io/gRate/reference/as_growthcurver.md)
  :

  Convert a `gr_plate` to growthcurver input

- [`as_gcplyr()`](https://loukesio.github.io/gRate/reference/as_gcplyr.md)
  :

  Convert a `gr_plate` to gcplyr-style tidy data

- [`gr_report()`](https://loukesio.github.io/gRate/reference/gr_report.md)
  : Render a one-page HTML QC report for a plate
