# Handoff: platecheck R package

## One-line goal

QC + spatial bias correction for 96-well microbial growth curves. Reads
raw plate-reader exports, maps layout, flags bad wells, corrects
positional artifacts, outputs tidy data ready for growthcurver/gcplyr.

## Why it exists

No R package does automated well QC or edge-effect correction for plate
growth curves. Everyone hand-rolls this plumbing. platecheck is the
missing preprocessing layer — it does NOT fit growth models
(growthcurver/gcplyr already do that well).

## Package structure

    platecheck/
    ├── DESCRIPTION            # Depends: R >= 4.1; Imports: dplyr, tidyr, ggplot2, rlang, stats
    ├── NAMESPACE
    ├── R/
    │   ├── read_plate.R       # pc_read(): parsers for Tecan, BioTek, generic wide/long CSV
    │   ├── layout.R           # pc_layout(): map wells -> metadata (strain, treatment, replicate)
    │   │                      #   accepts a CSV/data.frame or an 8x12 grid layout
    │   ├── qc_wells.R         # pc_qc(): per-well flags:
    │   │                      #   - no_growth (max OD below threshold)
    │   │                      #   - spike (single-timepoint jumps: condensation/bubbles)
    │   │                      #   - drift (monotone baseline drift, no sigmoid shape)
    │   │                      #   - late_jump (contamination-like sudden rise)
    │   │                      #   - noisy (residual SD from loess above threshold)
    │   ├── spatial.R          # pc_spatial(): estimate row/col/edge effects on summary stats
    │   │                      #   (max OD, AUC) via median polish; correct curves multiplicatively
    │   ├── plots.R            # pc_plot_plate(): 8x12 heatmap (any stat or QC flag)
    │   │                      # pc_plot_curves(): faceted curves, flagged wells highlighted
    │   ├── export.R           # pc_export(): tidy long data.frame + as_growthcurver() /
    │   │                      #   as_gcplyr() converters
    │   └── report.R           # pc_report(): one-call Quarto/HTML QC report per plate
    ├── inst/extdata/          # 2-3 small example files (Tecan export, generic CSV, layout CSV)
    ├── tests/testthat/        # tests per function; include a synthetic plate with known
    │                          #   injected artifacts (edge effect, spikes, dead wells)
    ├── vignettes/
    │   └── platecheck.Rmd     # full workflow: read -> layout -> qc -> spatial -> export -> growthcurver
    └── README.md

## Core object

A single S3 class `pc_plate`: list with - `$data` — tidy tibble: well,
row, col, time, value (+ metadata cols after pc_layout) - `$qc` —
per-well tibble of flags + reasons - `$meta` — instrument, plate id,
read interval

All functions take and return `pc_plate` so the pipeline is:

``` r

pc_read("run1.xlsx", format = "tecan") |>
  pc_layout("layout.csv") |>
  pc_qc() |>
  pc_spatial() |>
  pc_export(as = "growthcurver")
```

## Design rules

- Base R + tidyverse only. NO Rcpp — nothing here is compute-heavy. Keep
  it simple.
- Every QC threshold is an argument with a sensible default; never
  hard-code.
- QC flags, never delete — user decides what to drop.
- Spatial correction is optional and clearly labeled experimental in
  docs; use median polish (stats::medpolish), not a mixed model. Simple
  beats complex.
- All plots ggplot2, return the ggplot object.
- Follow tidyverse style guide; roxygen2 docs with runnable examples on
  every exported function.

## Build order (do in this sequence)

1.  `pc_read` generic CSV (wide + long) → S3 class + print method
2.  `pc_layout`
3.  `pc_qc` (start with no_growth + spike; add others after tests pass)
4.  `pc_plot_plate` + `pc_plot_curves`
5.  `pc_spatial`
6.  `pc_export` + converters
7.  Tecan/BioTek parsers (get real example files first — ask before
    guessing formats)
8.  `pc_report`, vignette, README

## Testing requirement

Create `tests/testthat/helper-synthetic.R` that generates a synthetic
96-well plate: logistic curves + injected known artifacts (2 dead wells,
3 spike wells, multiplicative edge effect of 0.85 on outer ring). Every
QC/spatial test asserts against this ground truth.

## Definition of done

- `devtools::check()` clean (0 errors, 0 warnings)
- Vignette runs end-to-end on bundled example data
- Synthetic-plate tests recover all injected artifacts

## Explicitly out of scope

- Growth model fitting (delegate to growthcurver/gcplyr)
- 384-well support (design so it’s easy to add later, but don’t build
  it)
- Shiny app
