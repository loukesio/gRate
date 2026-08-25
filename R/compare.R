#' Compare growth parameters between strains or conditions
#'
#' Tests whether a growth parameter (growth rate `r` by default) differs
#' between groups — strains, media, treatments — doing the statistics at the
#' right level of replication. Technical replicates are averaged into their
#' biological replicate **before** any test, so wells never inflate the sample
#' size (the pseudoreplication mistake). Flagged wells and failed fits are
#' excluded first.
#'
#' The unit of replication is chosen automatically: if the layout designates
#' `bio_rep`, each biological replicate contributes one value per group
#' (its technical replicates averaged); without `bio_rep`, each well is
#' treated as a replicate — fine only if your wells really are independent
#' cultures.
#'
#' With `method = "welch"` (default) the overall test is Welch's t-test for
#' two groups or Welch's ANOVA ([stats::oneway.test()]) for more, followed by
#' pairwise Welch t-tests with Holm adjustment. `method = "kruskal"` uses the
#' Kruskal-Wallis test and pairwise Wilcoxon tests instead — for small or
#' clearly non-normal samples.
#'
#' @param plate A `gr_plate` object after [gr_fit()] (layout with metadata
#'   required; [gr_qc()] recommended).
#' @param what Which parameter to compare: `"r"` (default), `"K"`, `"lag"`,
#'   `"doubling_time"`, `"N0"`, or `"t_rmax"`.
#' @param by Character vector of metadata columns defining the groups.
#'   Default: every metadata column except `bio_rep` and `tech_rep`.
#' @param method `"welch"` (default) or `"kruskal"` (see Details).
#' @param drop_flagged If `TRUE` (default), wells flagged by [gr_qc()] are
#'   excluded before averaging and testing.
#' @param conf_level Confidence level for the per-group intervals shown in
#'   `$groups` and by [gr_plot_compare()]. Default `0.95`.
#'
#' @return An object of class `gr_compare`: a list with
#'   * `$groups` — per-group tibble: n (replicates), mean, sd, se, ci_lo,
#'     ci_hi;
#'   * `$overall` — the overall test (method, statistic, p_value);
#'   * `$pairwise` — tibble of pairwise comparisons with adjusted p-values;
#'   * `$data` — the replicate-level values the tests ran on;
#'   * `$what`, `$by`, `$method`, `$unit` — what was compared and how.
#' @export
#' @seealso [gr_plot_compare()] to visualise, [gr_fit_summary()] for plain
#'   descriptive summaries.
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate")) |>
#'   gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
#'   gr_qc() |>
#'   gr_fit()
#'
#' cmp <- gr_compare(plate, what = "r", by = "strain")
#' cmp
#' cmp$pairwise
gr_compare <- function(plate,
                       what = c("r", "K", "lag", "doubling_time", "N0", "t_rmax"),
                       by = NULL,
                       method = c("welch", "kruskal"),
                       drop_flagged = TRUE,
                       conf_level = 0.95) {
  gr_assert_plate(plate)
  what <- match.arg(what)
  method <- match.arg(method)
  if (is.null(plate$fit)) {
    stop("No fit results; run gr_fit() first.", call. = FALSE)
  }

  res <- gr_results(plate, params = what, drop_flagged = drop_flagged)
  res <- res[res$fit_ok, ]

  meta_cols <- setdiff(
    names(res),
    c("well", "row", "col", what, "fit_ok", "note", "flagged", "reasons")
  )
  if (is.null(by)) {
    by <- setdiff(meta_cols, c("bio_rep", "tech_rep"))
  } else {
    missing_by <- setdiff(by, meta_cols)
    if (length(missing_by) > 0) {
      stop("Grouping column(s) not in the plate metadata: ",
           paste(missing_by, collapse = ", "),
           ". Add them with gr_layout().", call. = FALSE)
    }
  }
  if (length(by) == 0) {
    stop("No metadata columns to group by; add them with gr_layout() ",
         "or pass `by`.", call. = FALSE)
  }

  # Collapse to the unit of replication: one value per biological replicate
  # (technical replicates averaged), or per well when bio_rep is absent.
  if ("bio_rep" %in% names(res)) {
    unit <- "biological replicates"
    data <- res |>
      dplyr::group_by(dplyr::across(dplyr::all_of(c(by, "bio_rep")))) |>
      dplyr::summarise(
        value = mean(.data[[what]]),
        n_wells = dplyr::n(),
        .groups = "drop"
      )
  } else {
    unit <- "wells"
    data <- res |>
      dplyr::mutate(value = .data[[what]], n_wells = 1L) |>
      dplyr::select(dplyr::all_of(c(by, "well")), "value", "n_wells")
  }

  data$group <- do.call(paste, c(data[by], sep = " / "))

  n_per_group <- table(data$group)
  if (length(n_per_group) < 2) {
    stop("Need at least 2 groups to compare; `by = ",
         paste(by, collapse = ", "), "` gives ", length(n_per_group), ".",
         call. = FALSE)
  }
  if (any(n_per_group < 2)) {
    stop(
      "Every group needs at least 2 ", unit, " to test; too few in: ",
      paste(names(n_per_group)[n_per_group < 2], collapse = ", "),
      call. = FALSE
    )
  }

  alpha <- 1 - conf_level
  groups <- data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by)), .data$group) |>
    dplyr::summarise(
      n = dplyr::n(),
      mean = mean(.data$value),
      sd = stats::sd(.data$value),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      se = .data$sd / sqrt(.data$n),
      ci_lo = .data$mean - stats::qt(1 - alpha / 2, .data$n - 1) * .data$se,
      ci_hi = .data$mean + stats::qt(1 - alpha / 2, .data$n - 1) * .data$se
    )

  grp <- factor(data$group)
  overall <- if (method == "welch") {
    if (nlevels(grp) == 2) {
      tt <- stats::t.test(value ~ grp, data = data)
      list(method = "Welch two-sample t-test",
           statistic = unname(tt$statistic), p_value = tt$p.value)
    } else {
      ow <- stats::oneway.test(value ~ grp, data = data, var.equal = FALSE)
      list(method = "Welch's ANOVA",
           statistic = unname(ow$statistic), p_value = ow$p.value)
    }
  } else {
    kw <- stats::kruskal.test(data$value, grp)
    list(method = "Kruskal-Wallis test",
         statistic = unname(kw$statistic), p_value = kw$p.value)
  }

  pw <- if (method == "welch") {
    suppressWarnings(stats::pairwise.t.test(
      data$value, grp, pool.sd = FALSE, p.adjust.method = "holm"
    ))
  } else {
    suppressWarnings(stats::pairwise.wilcox.test(
      data$value, grp, p.adjust.method = "holm", exact = FALSE
    ))
  }
  means <- stats::setNames(groups$mean, groups$group)
  pairwise <- as.data.frame(as.table(pw$p.value)) |>
    stats::na.omit() |>
    stats::setNames(c("group1", "group2", "p_adj")) |>
    dplyr::mutate(
      dplyr::across(c("group1", "group2"), as.character),
      diff = means[.data$group1] - means[.data$group2],
      .before = "p_adj"
    ) |>
    dplyr::arrange(.data$p_adj) |>
    tibble::as_tibble()

  structure(
    list(
      what = what, by = by, method = method, unit = unit,
      conf_level = conf_level,
      groups = groups, overall = overall, pairwise = pairwise, data = data
    ),
    class = "gr_compare"
  )
}

#' @export
print.gr_compare <- function(x, ...) {
  cat(sprintf(
    "<gr_compare> %s by %s (unit: %s)\n",
    x$what, paste(x$by, collapse = " / "), x$unit
  ))
  cat(sprintf(
    "  %s: statistic = %.3g, p = %.3g\n",
    x$overall$method, x$overall$statistic, x$overall$p_value
  ))
  cat("\n")
  print(dplyr::select(x$groups, -dplyr::all_of(x$by)), n = Inf)
  n_sig <- sum(x$pairwise$p_adj < 0.05)
  cat(sprintf(
    "\n  %d of %d pairwise comparison%s significant at 0.05 (Holm-adjusted);",
    n_sig, nrow(x$pairwise), if (nrow(x$pairwise) == 1) "" else "s"
  ))
  cat(" see $pairwise\n")
  invisible(x)
}

#' Plot a growth parameter comparison
#'
#' Visualises a [gr_compare()] result: one point per replicate (jittered),
#' with the group mean and its confidence interval overlaid as a crossbar.
#'
#' @param cmp A `gr_compare` object.
#'
#' @return A ggplot object.
#' @export
#' @examples
#' plate <- gr_read(system.file("extdata", "growth_long.csv", package = "gRate")) |>
#'   gr_layout(system.file("extdata", "layout_long.csv", package = "gRate")) |>
#'   gr_qc() |>
#'   gr_fit()
#' gr_plot_compare(gr_compare(plate, what = "K", by = "medium"))
gr_plot_compare <- function(cmp) {
  if (!inherits(cmp, "gr_compare")) {
    stop("`cmp` must be a gr_compare object from gr_compare().", call. = FALSE)
  }

  ggplot2::ggplot(cmp$data, ggplot2::aes(x = .data$group, y = .data$value)) +
    ggplot2::geom_jitter(width = 0.12, height = 0, size = 2,
                         colour = gr_colors$muted, alpha = 0.9) +
    ggplot2::geom_crossbar(
      data = cmp$groups,
      ggplot2::aes(y = .data$mean, ymin = .data$ci_lo, ymax = .data$ci_hi),
      width = 0.4, linewidth = 0.5, colour = gr_colors$series[1],
      fill = gr_colors$series[1], alpha = 0.1
    ) +
    ggplot2::labs(
      x = paste(cmp$by, collapse = " / "),
      y = cmp$what,
      title = sprintf("%s by %s", cmp$what, paste(cmp$by, collapse = " / ")),
      subtitle = sprintf(
        "points: %s; crossbar: mean and %g%% CI\n%s: p = %.3g",
        cmp$unit, 100 * cmp$conf_level, cmp$overall$method,
        cmp$overall$p_value
      )
    ) +
    theme_gr() +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 30, hjust = 1)
    )
}
