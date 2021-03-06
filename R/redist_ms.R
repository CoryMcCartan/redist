#' @rdname redist_mergesplit
#' @order 2
#'
#' @param adj adjacency matrix, list, or object of class
#' "SpatialPolygonsDataFrame."
#' @param total_pop A vector containing the populations of each geographic
#' unit
#' @param ndists The number of congressional districts.
#' @param pop_tol The desired population constraint.  All sampled districts
#' will have a deviation from the target district size no more than this value
#' in percentage terms, i.e., \code{pop_tol=0.01} will ensure districts have
#' populations within 1% of the target population.
#'
#' @return \code{redist.mergesplit} returns an object of class list containing the
#' simulated plans.
#'
#' @export
#' @md
#' @examples \dontrun{
#' data(fl25)
#' adj <- redist.adjacency(fl25)
#' out <- redist.mergesplit(adj = adj, total_pop = fl25$pop,
#'                          nsims = 5, ndists = 3, pop_tol = 0.1)
#' }
redist.mergesplit <- function(adj, total_pop, nsims, ndists, pop_tol = 0.01,
                              init_plan, counties, compactness = 1,
                              constraints = list(), constraint_fn = function(m) rep(0, ncol(m)),
                              adapt_k_thresh = 0.975, k = NULL, verbose = TRUE,
                              silent = FALSE) {
  if (missing(adj)) {
    stop('Please provide an argument to adj.')
  }
  V <- length(adj)

  if (missing(total_pop)) {
    stop('Please provide an argument to total_pop.')
  }
  if (missing(nsims)) {
    stop('Please provide an argument to nsims.')
  }
  if (missing(ndists)) {
    stop('Please provide an argument to ndists')
  }

  if (compactness < 0) {
    stop('Compactness parameter must be non-negative')
  }
  if (adapt_k_thresh < 0 | adapt_k_thresh > 1) {
    stop('`adapt_k_thresh` parameter must lie in [0, 1].')
  }
  if (nsims < 1) {
    stop('`nsims` must be positive.')
  }

  if (missing(counties)) {
      counties <- rep(1, V)
  } else {
      if (any(is.na(counties)))
          stop("County vector must not contain missing values.")
      if (max(contiguity(adj = adj, group = redist.county.id(counties))) > 1) {
          warning('Counties were not continuous. Additional county splits are expected.')

          counties <- redist.county.relabel(adj = adj, counties = counties)
          counties <- redist.county.id(counties = counties)
      }
  }

  # Other constraints
  proc = process_smc_ms_constr(constraints, V)
  constraints = proc$constraints
  n_current <- max(constraints$status_quo$current)

  # handle printing
  verbosity <- 1
  if (verbose) verbosity <- 3
  if (silent) verbosity <- 0
  if (is.null(k)) k <- 0

  target <- sum(total_pop) / ndists
  pop_bounds <- target * c(1 - pop_tol, 1, 1 + pop_tol)

  if (missing(init_plan)) {
    init_plan <- redist.smc(
      adj = adj,
      total_pop = total_pop,
      nsims = 1,
      ndists = ndists,
      counties = counties,
      pop_tol = pop_tol,
      silent = TRUE
    )$plans
  } else {
    if (length(init_plan) != V) {
      stop('init_plan must have one entry for each unit.')
    }
    if (min(init_plan) == 0) {
      init_plan[init_plan == 0] <- max(init_plan) + 1
    }
    if (max(init_plan) != ndists) {
      stop('An incorrect number of districts was provided within init_plan.')
    }
  }

  # Create plans
  algout <- ms_plans(
    nsims + 1L, adj, init_plan, counties, total_pop, ndists, pop_bounds[2],
    pop_bounds[1], pop_bounds[3], compactness,
    constraints$status_quo$strength, constraints$status_quo$current, n_current,
    constraints$vra_old$strength, constraints$vra_old$tgt_vra_min,
    constraints$vra_old$tgt_vra_other, constraints$vra_old$pow_vra, proc$min_pop,
    constraints$vra$strength, constraints$vra$tgts_min,
    constraints$incumbency$strength, constraints$incumbency$incumbents,
    constraints$splits$strength,
    adapt_k_thresh, k, verbosity
  )


  out <- list(
    plans = algout$plans[, -1],
    adj = adj,
    nsims = nsims,
    compactness = compactness,
    constraints = constraints,
    total_pop = total_pop,
    counties = counties,
    adapt_k_thresh = adapt_k_thresh,
    mhdecisions = algout$mhdecisions,
    algorithm = 'mergesplit'
  )
  return(out)
}
