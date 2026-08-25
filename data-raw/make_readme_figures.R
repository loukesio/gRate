# Regenerates every figure in man/figures/ used by the README.
# Run from the package root: source("data-raw/make_readme_figures.R")
# Needs the package installed, plus patchwork (figures only, not a package dep).

library(gRate)
library(ggplot2)
library(patchwork)

dir.create("man/figures", showWarnings = FALSE, recursive = TRUE)
save_fig <- function(name, plot, width, height) {
  ggsave(file.path("man/figures", name), plot,
         width = width, height = height, dpi = 150, bg = "white")
}

set.seed(42)

# --- The bundled example plate: QC'd and fitted -----------------------------
plate <- gr_read(system.file("extdata", "growth_wide.csv", package = "gRate")) |>
  gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
  gr_qc()

save_fig("README-platemap.png", gr_plot_plate(plate, "max_od"), 7, 4.2)
save_fig("README-flagged.png", gr_plot_plate(plate, "flagged"), 7, 4.2)
save_fig("README-curves.png", gr_plot_curves(plate), 9, 5.5)

fitted <- gr_fit(plate)
save_fig(
  "README-fit.png",
  gr_plot_fit(fitted, wells = c("A1", "B3", "C5", "E6")),
  8, 5
)

# --- Spatial correction: the plate before and after -------------------------
# The two panels share one LINEAR fill scale: per-panel quantile equalization
# would re-amplify the corrected panel's residual noise and hide the
# flattening that is the whole point of the comparison.
corrected <- gr_spatial(plate)
rng <- range(gr_summarise(plate)$max_od, gr_summarise(corrected)$max_od)
shared <- scale_fill_gradientn(colours = gr_colors$sequential,
                               limits = rng, name = "max_od")
suppressMessages(save_fig(
  "README-spatial.png",
  (gr_plot_plate(plate, "max_od", equalize = FALSE) + shared +
     labs(title = "Before correction") +
     theme(legend.position = "none")) +
    (gr_plot_plate(corrected, "max_od", equalize = FALSE) + shared +
       labs(title = "After gr_spatial()")),
  10, 3.6
))

# --- Comparisons: a two-strain plate with a real difference -----------------
times <- seq(0, 24, by = 0.5)
wells <- as.vector(t(outer(LETTERS[1:8], 1:12, paste0)))
two_strain <- do.call(rbind, lapply(wells, function(w) {
  col <- as.integer(sub("^[A-H]", "", w))
  r <- if (col <= 6) 0.9 else 0.6
  K <- 1.2 * runif(1, 0.97, 1.03)
  data.frame(well = w, time = times,
             value = 0.05 + K / (1 + exp(-r * (times - 8))) +
               rnorm(length(times), 0, 0.003))
}))
layout <- data.frame(
  well = wells,
  strain = ifelse(as.integer(sub("^[A-H]", "", wells)) <= 6, "fast", "slow"),
  bio_rep = match(substr(wells, 1, 1), LETTERS),
  tech_rep = (as.integer(sub("^[A-H]", "", wells)) - 1) %% 6 + 1
)
cmp_plate <- gr_read(two_strain, format = "long") |>
  gr_layout(layout) |>
  gr_qc() |>
  gr_fit()
save_fig(
  "README-compare.png",
  gr_plot_compare(gr_compare(cmp_plate, what = "r", by = "strain")),
  6.5, 4.2
)

# --- Diauxie: curve + rolling per-capita rate with detected phases ----------
dx_curve <- data.frame(
  well = "B2",
  time = seq(0, 28, by = 0.25),
  value = 0.05 +
    0.3 / (1 + exp(-0.8 * (seq(0, 28, by = 0.25) - 5))) +
    0.9 / (1 + exp(-0.5 * (seq(0, 28, by = 0.25) - 16))) +
    rnorm(length(seq(0, 28, by = 0.25)), 0, 0.003)
)
dx_plate <- gr_read(dx_curve, format = "long")
dx <- gr_diauxie(dx_plate)

# Rolling per-capita slopes, as gr_diauxie computes them internally.
n <- dx_curve$value - mean(head(dx_curve$value, 3))
keep <- n > 0.05
tk <- dx_curve$time[keep]
y <- log(n[keep])
win <- 5
slopes <- sapply(seq_len(length(y) - win + 1), function(i) {
  j <- i:(i + win - 1)
  c(mean(tk[j]), cov(tk[j], y[j]) / var(tk[j]))
})
slope_df <- data.frame(time = slopes[1, ], rate = stats::runmed(slopes[2, ], 3))
phase_pts <- data.frame(
  time = c(dx$t1, dx$t2),
  rate = c(dx$r1, dx$r2),
  label = c(sprintf("phase 1: r = %.2f", dx$r1),
            sprintf("phase 2: r = %.2f", dx$r2))
)

p_od <- ggplot(dx_curve, aes(time, value)) +
  geom_point(size = 0.6, colour = gr_colors$muted) +
  geom_vline(xintercept = dx$trough_t, linetype = "dashed",
             colour = gr_colors$baseline) +
  labs(title = "A diauxic well", y = "OD600", x = NULL) +
  theme_gr()
p_rate <- ggplot(slope_df, aes(time, rate)) +
  geom_line(colour = gr_colors$series[1], linewidth = 0.7) +
  geom_point(data = phase_pts, colour = gr_colors$series[2], size = 3) +
  geom_text(data = phase_pts, aes(label = label),
            vjust = -1, hjust = "inward", size = 3.2,
            colour = gr_colors$ink2) +
  geom_vline(xintercept = dx$trough_t, linetype = "dashed",
             colour = gr_colors$baseline) +
  expand_limits(y = max(phase_pts$rate) * 1.25) +
  labs(y = "per-capita growth rate", x = "time",
       subtitle = "gr_diauxie() finds the two rate peaks and the trough between them") +
  theme_gr()
save_fig("README-diauxie.png", p_od / p_rate, 7.5, 5.5)

# --- Lag: one curve, four definitions ---------------------------------------
lag_well <- subset(plate$data, well == "C3")
lags <- gr_lag(plate)
l <- lags[lags$well == "C3", ]
lag_df <- data.frame(
  method = c("logistic tangent", "Gompertz tangent", "easylinear tangent",
             "threshold crossing"),
  lag = c(l$lag_logistic, l$lag_gompertz, l$lag_easylinear, l$lag_threshold)
)
save_fig(
  "README-lag.png",
  ggplot(lag_well, aes(time, value)) +
    geom_point(size = 0.7, colour = gr_colors$muted) +
    geom_vline(data = lag_df, aes(xintercept = lag, colour = method),
               linewidth = 0.7) +
    scale_colour_manual(values = unname(gr_colors$series[1:4])) +
    labs(title = "Four lag definitions, one well",
         subtitle = sprintf(
           "gr_lag(): spread across methods = %.1f h - disagreement is a diagnostic",
           l$lag_range),
         y = "OD600", x = "time", colour = NULL) +
    theme_gr() +
    theme(legend.position = "bottom"),
  7.5, 4.6
)

message("Wrote ", length(list.files("man/figures")), " figures to man/figures/")
