#' Update model parameters via factor slice sampling
#'
#' @param model_params_est vector of model parameters on the estimation scale
#' @param model_params_nat vector of model parameters on the natural scale
#' @param interval_widths vector of slice interval widths
#' @param slice_eigenvecs matrix of slice factors
#' @param path list containing the LNA path, N(0,1) draws, and likelihood
#' @param data matrix containing the data
#' @param priors list with functions for computing the prior density and
#'   transformations to and from the estimation scale
#' @param params_logprior_cur log prior density of model parameters
#' @param lna_params_cur matrix with current LNA parameters, tcovar, tparam,
#'   etc.
#' @param tparam list with time-varying parameters
#' @param censusmat matrix for storing the LNA path at census times
#' @param emitmat matrix for emission probabilities
#' @param flow_matrix flow matrix
#' @param stoich_matrix stoichiometry matrix
#' @param lna_times times at which the LNA is evaluated
#' @param forcing_inds indices at which forcings are applied
#' @param forcing_matrix matrix containing forcings
#' @param lna_param_inds indices for LNA parameters for computing emission probs
#' @param lna_const_inds indices for constants used in computing emission probs
#' @param lna_tcovar_inds indices for time-varying covariates
#' @param lna_initdist_inds index for where the initial compartment volumes
#'   begin
#' @param param_update_inds indices for when LNA parameters should be updated
#' @param lna_event_inds codes for elementary events
#' @param census_indices indices for when the LNA path should be censused
#' @param measproc_indmat matrix giving the indices for data likelihood
#'   contributions
#' @param svd_d vector for LNA singular values
#' @param svd_U matrix for LNA left singular vectors
#' @param svd_V matrix for LNA right singular vectors
#' @param lna_pointer external pointer for LNA
#' @param lna_set_pars_pointer external pointer for setting LNA parameters
#' @param d_meas_pointer external pointer for computing emission probabilities
#' @param do_prevalence should prevalence be computed
#' @param step_size initial step size for ODE stepper
#' @param params_prop_est vector for proposed model parameters on their estimation scale
#' @param params_prop_nat vector for proposed model parameters on their natural scale
#' @param slice_probs slice direction sampling probabilities
#' @param n_afss_updates number of afss updates per iteration
#' @param lna_param_vec vector for lna parameters
#' @param n_contractions_afss vector for storing the number of contractions
#' @param n_expansions_afss number of expansions
#' @param c_contractions_afss cumulative number of contractions
#' @param c_expansions_afss cumulative number of expansions
#'
#' @return update the model parameters, path, and likelihood terms in place
#' @export
factor_slice_sampler <- 
      function(
            model_params_est,
            model_params_nat,
            params_prop_est,
            params_prop_nat,
            interval_widths,
            n_contractions_afss,
            n_expansions_afss,
            c_contractions_afss,
            c_expansions_afss,
            slice_eigenvecs,
            slice_probs,
            n_afss_updates,
            path,
            pathmat_prop,
            data,
            priors,
            params_logprior_cur,
            lna_params_cur,
            lna_param_vec,
            tparam,
            censusmat,
            emitmat,
            flow_matrix,
            stoich_matrix,
            lna_times,
            forcing_inds,
            forcing_tcov_inds,
            forcings_out,
            forcing_transfers,
            lna_param_inds,
            lna_const_inds,
            lna_tcovar_inds,
            lna_initdist_inds,
            param_update_inds,
            lna_event_inds,
            census_indices,
            measproc_indmat,
            svd_d,
            svd_U,
            svd_V,
            lna_pointer,
            lna_set_pars_pointer,
            d_meas_pointer,
            do_prevalence,
            step_size) {
      
      directions <- sample.int(n = length(slice_probs), size = n_afss_updates, replace = FALSE, prob = slice_probs)
      
      for(f in directions) {
            
            # sample the likelihood threshold
            threshold <- path$data_log_lik + params_logprior_cur - rexp(1)
            
            # construct the approximate bracket
            lower <- -interval_widths[f] * runif(1)
            upper <- lower + interval_widths[f]
            
            # Step out the bracket
            logpost_lower <- NULL
            logpost_upper <- NULL
            
            # step out lower bound
            while(is.null(logpost_lower) || threshold < logpost_lower) {
                  
                  # lower end of the bracket on the estimation scale
                  copy_vec(dest = params_prop_est, orig = model_params_est + lower * slice_eigenvecs[,f])
                  
                  # get the parameters on the natural scale
                  copy_vec(dest = params_prop_nat, orig = priors$from_estimation_scale(params_prop_est))
                  
                  # compute the prior density
                  logprior_lower <- priors$prior_density(params_nat = params_prop_nat,
                                                         params_est = params_prop_est)
                  
                  # if the log prior is not -Inf, find the path
                  if(logprior_lower != -Inf) {
                        
                        # insert the parameters into the lna_parameters matrix
                        pars2lnapars2(lnapars    = lna_params_cur,
                                      parameters = params_prop_nat, 
                                      c_start    = 0)
                        
                        # compute the time-varying parameters if necessary
                        if(!is.null(tparam)) {
                              for(p in seq_along(tparam)) {
                                    insert_tparam(tcovar    = lna_params_cur,
                                                  values    = tparam[[p]]$draws2par(
                                                        parameters = lna_params_cur[1,],
                                                        draws      = tparam[[p]]$draws_cur),
                                                  col_ind   = tparam[[p]]$col_ind,
                                                  tpar_inds = tparam[[p]]$tpar_inds)
                              }      
                        }
                        
                        # initialize data log likelihood
                        loglik_lower <- NULL
                        
                        # map the perturbations to an LNA path
                        try({
                              map_draws_2_lna(
                                    pathmat           = pathmat_prop,
                                    draws             = path$draws,
                                    lna_times         = lna_times,
                                    lna_pars          = lna_params_cur,
                                    lna_param_vec     = lna_param_vec,
                                    lna_param_inds    = lna_param_inds,
                                    lna_tcovar_inds   = lna_tcovar_inds,
                                    init_start        = lna_initdist_inds[1],
                                    param_update_inds = param_update_inds,
                                    stoich_matrix     = stoich_matrix,
                                    forcing_inds      = forcing_inds,
                                    forcing_tcov_inds = forcing_tcov_inds,
                                    forcings_out      = forcings_out,
                                    forcing_transfers = forcing_transfers,
                                    svd_d             = svd_d,
                                    svd_U             = svd_U,
                                    svd_V             = svd_V,
                                    lna_pointer       = lna_pointer,
                                    set_pars_pointer  = lna_set_pars_pointer,
                                    step_size         = step_size
                              )
                              
                              census_lna(
                                    path                = pathmat_prop,
                                    census_path         = censusmat,
                                    census_inds         = census_indices,
                                    lna_event_inds      = lna_event_inds,
                                    flow_matrix_lna     = flow_matrix,
                                    do_prevalence       = do_prevalence,
                                    init_state          = lna_params_cur[1, lna_initdist_inds + 1],
                                    lna_pars            = lna_params_cur,
                                    forcing_inds        = forcing_inds,
                                    forcing_tcov_inds   = forcing_tcov_inds,
                                    forcings_out        = forcings_out,
                                    forcing_transfers   = forcing_transfers
                              )
                              
                              # evaluate the density of the incidence counts
                              evaluate_d_measure_LNA(
                                    emitmat           = emitmat,
                                    obsmat            = data,
                                    censusmat         = censusmat,
                                    measproc_indmat   = measproc_indmat,
                                    lna_parameters    = lna_params_cur,
                                    lna_param_inds    = lna_param_inds,
                                    lna_const_inds    = lna_const_inds,
                                    lna_tcovar_inds   = lna_tcovar_inds,
                                    param_update_inds = param_update_inds,
                                    census_indices    = census_indices,
                                    lna_param_vec     = lna_param_vec,
                                    d_meas_ptr        = d_meas_pointer
                              )
                              
                              # compute the data log likelihood
                              loglik_lower <- sum(emitmat[,-1][measproc_indmat])
                              if(is.nan(loglik_lower)) loglik_lower <- -Inf
                        }, silent = TRUE)
                        
                        if(is.null(loglik_lower)) loglik_lower <- -Inf      
                        
                  } else {
                        loglik_lower <- -Inf
                  }
                  
                  # compute log-posterior
                  logpost_lower <- loglik_lower + logprior_lower
                  
                  # step out the bracket if necessary
                  if(threshold < logpost_lower) {
                        
                        # decrease the lower endpoint of the bracket
                        lower <- lower - interval_widths[f]
                        
                        # increment the numbers of expansions
                        increment_elem(n_expansions_afss, f-1)
                        increment_elem(c_expansions_afss, f-1)
                  }
            }
            
            # step out upper
            while(is.null(logpost_upper) || threshold < logpost_upper) {
                  
                  # upper end of the bracket on the estimation scale
                  copy_vec(dest = params_prop_est, orig = model_params_est + upper * slice_eigenvecs[,f])
                  
                  # get the parameters on the natural scale
                  copy_vec(dest = params_prop_nat, orig = priors$from_estimation_scale(params_prop_est))
                  
                  # compute the prior density
                  logprior_upper <- priors$prior_density(params_nat = params_prop_nat,
                                                         params_est = params_prop_est)
                  
                  # if the log prior is not -Inf, find the path
                  if(logprior_upper != -Inf) {
                        
                        # insert the parameters into the lna_parameters matrix
                        pars2lnapars2(lnapars    = lna_params_cur, 
                                      parameters = params_prop_nat, 
                                      c_start    = 0)
                        
                        # compute the time-varying parameters if necessary
                        if(!is.null(tparam)) {
                              for(p in seq_along(tparam)) {
                                    insert_tparam(tcovar    = lna_params_cur,
                                                  values    = tparam[[p]]$draws2par(
                                                        parameters = lna_params_cur[1,],
                                                        draws      = tparam[[p]]$draws_cur),
                                                  col_ind   = tparam[[p]]$col_ind,
                                                  tpar_inds = tparam[[p]]$tpar_inds)
                              }
                        }
                        
                        # initialize data log likelihood
                        loglik_upper <- NULL
                        
                        # map the perturbations to an LNA path
                        try({
                              map_draws_2_lna(
                                    pathmat           = pathmat_prop,
                                    draws             = path$draws,
                                    lna_times         = lna_times,
                                    lna_pars          = lna_params_cur,
                                    lna_param_vec     = lna_param_vec,
                                    lna_param_inds    = lna_param_inds,
                                    lna_tcovar_inds   = lna_tcovar_inds,
                                    init_start        = lna_initdist_inds[1],
                                    param_update_inds = param_update_inds,
                                    stoich_matrix     = stoich_matrix,
                                    forcing_inds      = forcing_inds,
                                    forcing_tcov_inds = forcing_tcov_inds,
                                    forcings_out      = forcings_out,
                                    forcing_transfers = forcing_transfers,
                                    svd_d             = svd_d,
                                    svd_U             = svd_U,
                                    svd_V             = svd_V,
                                    lna_pointer       = lna_pointer,
                                    set_pars_pointer  = lna_set_pars_pointer,
                                    step_size         = step_size
                              )
                              
                              census_lna(
                                    path                = pathmat_prop,
                                    census_path         = censusmat,
                                    census_inds         = census_indices,
                                    lna_event_inds      = lna_event_inds,
                                    flow_matrix_lna     = flow_matrix,
                                    do_prevalence       = do_prevalence,
                                    init_state          = lna_params_cur[1, lna_initdist_inds + 1],
                                    lna_pars            = lna_params_cur,
                                    forcing_inds        = forcing_inds,
                                    forcing_tcov_inds   = forcing_tcov_inds,
                                    forcings_out        = forcings_out,
                                    forcing_transfers   = forcing_transfers
                              )
                              
                              # evaluate the density of the incidence counts
                              evaluate_d_measure_LNA(
                                    emitmat           = emitmat,
                                    obsmat            = data,
                                    censusmat         = censusmat,
                                    measproc_indmat   = measproc_indmat,
                                    lna_parameters    = lna_params_cur,
                                    lna_param_inds    = lna_param_inds,
                                    lna_const_inds    = lna_const_inds,
                                    lna_tcovar_inds   = lna_tcovar_inds,
                                    param_update_inds = param_update_inds,
                                    census_indices    = census_indices,
                                    lna_param_vec     = lna_param_vec,
                                    d_meas_ptr        = d_meas_pointer
                              )
                              
                              # compute the data log likelihood
                              loglik_upper <- sum(emitmat[,-1][measproc_indmat])
                              if(is.nan(loglik_upper)) loglik_upper <- -Inf
                        }, silent = TRUE)
                        
                        if(is.null(loglik_upper)) loglik_upper <- -Inf
                        
                  } else {
                        loglik_upper <- -Inf
                  }
                  
                  # compute log-posterior
                  logpost_upper <- loglik_upper + logprior_upper
                  
                  # step out the bracket if necessary
                  if(threshold < logpost_upper) {
                        
                        # decrease the upper endpoint of the bracket
                        upper <- upper + interval_widths[f]
                        
                        # increment the numbers of expansions
                        increment_elem(n_expansions_afss, f-1)
                        increment_elem(c_expansions_afss, f-1)
                  }
            }
            
            # initialize the log-posterior
            logpost_prop <- -Inf 

            # sample from the bracket
            while((upper - lower) > sqrt(.Machine$double.eps) && (logpost_prop < threshold)) {
                  
                  # sample uniformly in the bracket
                  prop <- runif(1, lower, upper)
                  
                  # proposed parameters on the estimation scale
                  copy_vec(dest = params_prop_est, orig = model_params_est + prop * slice_eigenvecs[,f])
                  
                  # get the parameters on the natural scale
                  copy_vec(dest = params_prop_nat, orig = priors$from_estimation_scale(params_prop_est))
                  
                  # compute the prior density
                  logprior_prop <- priors$prior_density(params_nat = params_prop_nat, 
                                                        params_est = params_prop_est)
                  
                  # if the log prior is not -Inf, find the path
                  if(logprior_prop != -Inf) {
                        
                        # insert the parameters into the lna_parameters matrix
                        pars2lnapars2(lnapars    = lna_params_cur, 
                                      parameters = params_prop_nat,
                                      c_start    = 0)
                        
                        # compute the time-varying parameters if necessary
                        if(!is.null(tparam)) {
                              for(p in seq_along(tparam)) {
                                    insert_tparam(tcovar    = lna_params_cur,
                                                  values    = tparam[[p]]$draws2par(
                                                        parameters = lna_params_cur[1,],
                                                        draws      = tparam[[p]]$draws_cur),
                                                  col_ind   = tparam[[p]]$col_ind,
                                                  tpar_inds = tparam[[p]]$tpar_inds)
                              }
                        }
                        
                        # initialize data log likelihood
                        loglik_prop <- NULL
                        
                        # map the perturbations to an LNA path
                        try({
                              map_draws_2_lna(
                                    pathmat           = pathmat_prop,
                                    draws             = path$draws,
                                    lna_times         = lna_times,
                                    lna_pars          = lna_params_cur,
                                    lna_param_vec     = lna_param_vec,
                                    lna_param_inds    = lna_param_inds,
                                    lna_tcovar_inds   = lna_tcovar_inds,
                                    init_start        = lna_initdist_inds[1],
                                    param_update_inds = param_update_inds,
                                    stoich_matrix     = stoich_matrix,
                                    forcing_inds      = forcing_inds,
                                    forcing_tcov_inds = forcing_tcov_inds,
                                    forcings_out      = forcings_out,
                                    forcing_transfers = forcing_transfers,
                                    svd_d             = svd_d,
                                    svd_U             = svd_U,
                                    svd_V             = svd_V,
                                    lna_pointer       = lna_pointer,
                                    set_pars_pointer  = lna_set_pars_pointer,
                                    step_size         = step_size
                              )
                              
                              census_lna(
                                    path                = pathmat_prop,
                                    census_path         = censusmat,
                                    census_inds         = census_indices,
                                    lna_event_inds      = lna_event_inds,
                                    flow_matrix_lna     = flow_matrix,
                                    do_prevalence       = do_prevalence,
                                    init_state          = lna_params_cur[1, lna_initdist_inds + 1],
                                    lna_pars            = lna_params_cur,
                                    forcing_inds        = forcing_inds,
                                    forcing_tcov_inds   = forcing_tcov_inds,
                                    forcings_out        = forcings_out,
                                    forcing_transfers   = forcing_transfers
                              )
                              
                              # evaluate the density of the incidence counts
                              evaluate_d_measure_LNA(
                                    emitmat           = emitmat,
                                    obsmat            = data,
                                    censusmat         = censusmat,
                                    measproc_indmat   = measproc_indmat,
                                    lna_parameters    = lna_params_cur,
                                    lna_param_inds    = lna_param_inds,
                                    lna_const_inds    = lna_const_inds,
                                    lna_tcovar_inds   = lna_tcovar_inds,
                                    param_update_inds = param_update_inds,
                                    census_indices    = census_indices,
                                    lna_param_vec     = lna_param_vec,
                                    d_meas_ptr        = d_meas_pointer
                              )
                              
                              # compute the data log likelihood
                              loglik_prop <- sum(emitmat[,-1][measproc_indmat])
                              if(is.nan(loglik_prop)) loglik_prop <- -Inf
                        }, silent = TRUE)
                        
                        if(is.null(loglik_prop)) loglik_prop <- -Inf
                        
                  } else {
                        loglik_prop <- -Inf
                  }
                  
                  # compute log-posterior
                  logpost_prop <- loglik_prop + logprior_prop
                  
                  # shrink the bracket if necessary
                  if(threshold > logpost_prop) {
                        
                        # adjust the bounds
                        if(prop < 0) {
                              lower <- prop
                        } else {
                              upper <- prop
                        }
                        
                        # increment the number of contractions
                        increment_elem(n_contractions_afss, f-1)
                        increment_elem(c_contractions_afss, f-1)
                  }
            }
            
            if((upper - lower) > sqrt(.Machine$double.eps)) {
                  
                  # update vectors of model parameters
                  copy_vec(dest = model_params_est, orig = params_prop_est)
                  copy_vec(dest = model_params_nat, orig = params_prop_nat)
                  
                  # update the likelihood terms
                  copy_vec(dest = params_logprior_cur, orig = logprior_prop)
                  copy_vec(dest = path$data_log_lik,   orig = loglik_prop)
                  
                  # copy the path matrix
                  copy_mat(path$lna_path, pathmat_prop)
                  
            } else {
                  
                  # insert the parameters into the lna_parameters matrix
                  pars2lnapars2(lnapars    = lna_params_cur,
                                parameters = model_params_nat, 
                                c_start    = 0)
                  
                  # recover the original time-varying covariates
                  # compute the time-varying parameters if necessary
                  if(!is.null(tparam)) {
                        for(p in seq_along(tparam)) {
                              insert_tparam(tcovar    = lna_params_cur,
                                            values    = tparam[[p]]$draws2par(parameters = lna_params_cur[1,],
                                                                              draws = tparam[[p]]$draws_cur),
                                            col_ind   = tparam[[p]]$col_ind,
                                            tpar_inds = tparam[[p]]$tpar_inds)
                        }
                  }
            }
      }      
}