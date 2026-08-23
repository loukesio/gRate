# Synthetic 96-well plate with known injected artifacts. Every QC and spatial
# test asserts against this ground truth.
#
# Injected artifacts (defaults):
#   - 2 dead wells (baseline + noise only):        C5, F8
#   - 3 spike wells (one +0.4 jump mid-run):       B3, D10, G6
#   - multiplicative edge effect on the outer ring: x 0.85
#
# Returns a gr_plate built through gr_read() (so the reader is exercised too),
# with the ground truth attached as attributes.
synthetic_plate <- function(seed = 42,
                            interval = 0.5,
                            t_max = 24,
                            dead_wells = c("C5", "F8"),
                            spike_wells = c("B3", "D10", "G6"),
                            edge_factor = 0.85,
                            noise_sd = 0.003,
                            baseline = 0.05,
                            K = 1.2,
                            r = 0.6,
                            t_mid = 8) {
  set.seed(seed)
  times <- seq(0, t_max, by = interval)
  wells <- gRate:::gr_all_wells()
  edge <- gRate:::gr_edge_wells()

  make_curve <- function(well) {
    if (well %in% dead_wells) {
      value <- baseline + stats::rnorm(length(times), 0, noise_sd)
    } else {
      k_w <- K * stats::runif(1, 0.95, 1.05)
      value <- baseline + k_w / (1 + exp(-r * (times - t_mid))) +
        stats::rnorm(length(times), 0, noise_sd)
    }
    if (well %in% spike_wells) {
      value[round(length(times) / 3)] <- value[round(length(times) / 3)] + 0.4
    }
    if (well %in% edge) {
      value <- value * edge_factor
    }
    data.frame(well = well, time = times, value = value)
  }

  df <- do.call(rbind, lapply(wells, make_curve))
  plate <- gr_read(df, format = "long", plate_id = "synthetic")

  attr(plate, "truth") <- list(
    dead_wells = dead_wells,
    spike_wells = spike_wells,
    edge_wells = edge,
    edge_factor = edge_factor,
    baseline = baseline,
    K = K
  )
  plate
}

# A clean plate (no artifacts) for false-positive checks.
clean_plate <- function(seed = 1) {
  synthetic_plate(
    seed = seed,
    dead_wells = character(0),
    spike_wells = character(0),
    edge_factor = 1
  )
}
