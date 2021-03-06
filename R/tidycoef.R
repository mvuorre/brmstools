#' Tidy parameters from brmsfit objects
#'
#' Extract brmsfit parameter (summaries) into a tidy tibble. Returns a tibble
#' where the type of parameter (varying / average) is represented separately
#' from the parameter. Especially useful for plots where the "fixed"
#' parameters should be shown next to their "random" counterparts.
#'
#' @param model A brmsfit.
#' @param grouping Name of grouping variable (e.g. `(1 | grouping)`). Defaults
#' to `NA` which returns the unique / first grouping factor in model.
#' @param pars Parameters to extract; must match exactly. Combine many with
#' `c(...)`.
#' @param summary Should summary statistics be returned instead of raw values.
#' @param level For interval limits.
#'
#' @return a tibble
#' @export
tidycoef <- function(model,
                     grouping = NA,
                     pars = NA,
                     summary = FALSE,
                     level = .95) {

  .Deprecated("tidybayes")

  grouping <- get_grouping(model, grouping)
  if (is.na(pars)) {
    parameters <- dimnames(coef(model)[[grouping]])[[3]]
  } else {
    parameters <- pars
  }
  ranefs <- vector("list", length(parameters))
  names(ranefs) <- parameters
  for (parameter in parameters) {
    # Varying
    samples_r <- as.data.frame(coef(model, summary = FALSE)[[grouping]][, , parameter])
    samples_r[["iter"]] <- rownames(samples_r)
    samples_r <- tidyr::gather_(
      samples_r,
      key_col = grouping,
      value_col = parameter,
      gather_cols = as.character(model$data[[grouping]])
    )
    ranefs[[parameter]] <- samples_r
  }
  ranefs <- Reduce(function(...) merge(..., all=T), ranefs)
  ranefs[["type"]] <- "r"
  samples_f <- tibble::as_tibble(as.data.frame(fixef(model, summary = FALSE)))
  samples_f <- samples_f[,parameters]
  samples_f[[grouping]] <- NA
  samples_f[["type"]] <- "b"
  samples_f[["iter"]] <- rownames(samples_f)
  samples <- rbind(ranefs, samples_f)
  samples <- tidyr::gather_(samples,
                           key_col = "Parameter",
                           value = "value",
                           parameters)
  out <- tibble::as_tibble(samples)
  if (summary) {
    # Summaries
    probs <- c(.5 - level / 2, .5 + level / 2)
    samples_sum <- dplyr::group_by_(samples, "type", grouping, "Parameter")
    samples_sum <- dplyr::summarise_(
      samples_sum,
      Estimate = ~mean(value),
      Est.Error = ~sd(value),
      lwr = ~quantile(value, probs[1]),
      upr = ~quantile(value, probs[2])
    )
    samples_sum <- dplyr::ungroup(samples_sum)
    names(samples_sum) <- c("type", grouping, "Parameter",
                        "Estimate", "Est.Error",
                        paste0(probs[1]*100, "%ile"),
                        paste0(probs[2]*100, "%ile"))
    out <- tibble::as_tibble(samples_sum)
  }
  out
}
