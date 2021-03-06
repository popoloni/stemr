// [[Rcpp::depends(RcppArmadillo)]]
#include "stemr_types.h"
#include "stemr_utils.h"

using namespace Rcpp;
using namespace arma;

//' Simulate an LNA path using a non-centered parameterization for the
//' log-transformed counting process LNA.
//'
//' @param lna_times vector of interval endpoint times
//' @param lna_draws vector of N(0,1) draws to be mapped to the path
//' @param lna_pars numeric matrix of parameters, constants, and time-varying
//'   covariates at each of the lna_times
//' @param init_start index in the parameter vector where the initial compartment
//'   volumes start
//' @param param_update_inds logical vector indicating at which of the times the
//'   LNA parameters need to be updated.
//' @param stoich_matrix stoichiometry matrix giving the changes to compartments
//'   from each reaction
//' @param forcing_inds logical vector of indicating at which times in the
//'   time-varying covariance matrix a forcing is applied.
//' @param forcing_matrix matrix containing the forcings.
//' @param max_attempts maximum number of tries if the first increment is rejected
//' @param step_size initial step size for the ODE solver (adapted internally,
//' but too large of an initial step can lead to failure in stiff systems).
//' @param lna_pointer external pointer to the compiled LNA integration function.
//' @param set_pars_pointer external pointer to the function for setting LNA pars.
//' @return list containing the stochastic perturbations (i.i.d. N(0,1) draws) and
//' the LNA path on its natural scale which is determined by the perturbations.
//'
//' @export
// [[Rcpp::export]]
Rcpp::List propose_lna(const arma::rowvec& lna_times,
                       const Rcpp::NumericVector& lna_draws,
                       const Rcpp::NumericMatrix& lna_pars,
                       const Rcpp::IntegerVector& lna_param_inds,
                       const Rcpp::IntegerVector& lna_tcovar_inds,
                       const int init_start,
                       const Rcpp::LogicalVector& param_update_inds,
                       const arma::mat& stoich_matrix,
                       const Rcpp::LogicalVector& forcing_inds,
                       const arma::uvec& forcing_tcov_inds,
                       const arma::mat& forcings_out,
                       const arma::cube& forcing_transfers,
                       int max_attempts,
                       double step_size,
                       SEXP lna_pointer,
                       SEXP set_pars_pointer) {
      
        // get the dimensions of various objects
        int n_events = stoich_matrix.n_cols;         // number of transition events, e.g., S2I, I2R
        int n_comps  = stoich_matrix.n_rows;         // number of model compartments (all strata)
        int n_odes   = n_events + n_events*n_events; // number of ODEs
        int n_times  = lna_times.n_elem;             // number of times at which the LNA must be evaluated
        int n_tcovar = lna_tcovar_inds.size();       // number of time-varying covariates or parameters
        int n_forcings = forcing_tcov_inds.n_elem;   // number of forcings
        
        // for use with forcings
        double forcing_flow = 0;
        arma::vec forcing_distvec(n_comps, arma::fill::zeros);

        // initialize the objects used in each time interval
        double t_L = 0;
        double t_R = 0;
        Rcpp::NumericVector current_params = lna_pars.row(0);   // vector for storing the current parameter values
        CALL_SET_ODE_PARAMS(current_params, set_pars_pointer);  // set the parameters in the odeintr namespace

        // initial state vector - copy elements from the current parameter vector
        arma::vec init_volumes(current_params.begin() + init_start, n_comps);

        // initialize the LNA objects - the vector for storing the current state
        Rcpp::NumericVector lna_state_vec(n_odes);   // vector to store the results of the ODEs
        
        arma::vec lna_drift(n_events, arma::fill::zeros); // incidence mean vector (natural scale)
        arma::mat lna_diffusion(n_events, n_events, arma::fill::zeros); // diffusion matrix
        
        arma::vec log_lna(n_events, arma::fill::zeros);  // LNA increment, log scale
        arma::vec nat_lna(n_events, arma::fill::zeros);  // LNA increment, natural scale
        
        // Objects for computing the eigen decomposition of the LNA covariance matrices
        arma::vec svd_d(n_events, arma::fill::zeros);
        arma::mat svd_U(n_events, n_events, arma::fill::zeros);
        arma::mat svd_V(n_events, n_events, arma::fill::zeros);
        bool good_svd = true;
        
        // matrix in which to store the LNA path
        arma::mat lna_path(n_events+1, n_times, arma::fill::zeros); // incidence path
        arma::mat prev_path(n_comps+1, n_times, arma::fill::zeros); // prevalence path (compartment volumes)
        lna_path.row(0) = lna_times;
        prev_path.row(0) = lna_times;
        prev_path(arma::span(1,n_comps), 0) = init_volumes;
        
        // apply forcings if called for - applied after censusing at the first time
        if(forcing_inds[0]) {
              
              // distribute the forcings proportionally to the compartment counts in the applicable states
              for(int j=0; j < n_forcings; ++j) {
                    
                    forcing_flow       = lna_pars(0, forcing_tcov_inds[j]);
                    forcing_distvec    = forcing_flow * normalise(forcings_out.col(j) % init_volumes, 1);
                    init_volumes      += forcing_transfers.slice(j) * forcing_distvec;
              }
        }
        
        // sample the stochastic perturbations - use Rcpp RNG for safety
        Rcpp::NumericVector draws_rcpp(Rcpp::clone(lna_draws));
        arma::mat draws(draws_rcpp.begin(), n_events, n_times-1, true);
        
        // iterate over the time sequence, solving the LNA over each interval
        for(int j=0; j < (n_times-1); ++j) {
              
              // set the times of the interval endpoints
              t_L = lna_times[j];
              t_R = lna_times[j+1];
              
              // Reset the LNA state vector and integrate the LNA ODEs over the next interval to 0
              std::fill(lna_state_vec.begin(), lna_state_vec.end(), 0.0);
              CALL_INTEGRATE_STEM_ODE(lna_state_vec, t_L, t_R, step_size, lna_pointer);
              
              // transfer the elements of the lna_state_vec to the process objects
              std::copy(lna_state_vec.begin(), lna_state_vec.begin() + n_events, lna_drift.begin());
              std::copy(lna_state_vec.begin() + n_events, lna_state_vec.end(), lna_diffusion.begin());
              
              // map the stochastic perturbation to the LNA path on its natural scale
              try{
                    if(lna_drift.has_nan() || lna_diffusion.has_nan()) {
                          good_svd = false;
                          throw std::runtime_error("Integration failed.");
                    } else {
                          good_svd = arma::svd(svd_U, svd_d, svd_V, lna_diffusion); // compute the SVD
                    }
                    
                    if(!good_svd) {
                          throw std::runtime_error("SVD failed.");
                          
                    } else {
                          svd_d.elem(arma::find(svd_d < 0)).zeros();          // zero out negative sing. vals
                          svd_V.each_row() %= arma::sqrt(svd_d).t();          // multiply rows of V by sqrt(d)
                          svd_U *= svd_V.t();                                 // complete svd_sqrt
                          svd_U.elem(arma::find(lna_diffusion == 0)).zeros(); // zero out numerical errors
                          
                          log_lna = lna_drift + svd_U * draws.col(j);         // map the LNA draws
                    }
                    
              } catch(std::exception & err) {
                    
                    // reinstatiate the SVD objects
                    arma::vec svd_d(n_events, arma::fill::zeros);
                    arma::mat svd_U(n_events, n_events, arma::fill::zeros);
                    arma::mat svd_V(n_events, n_events, arma::fill::zeros);
                    
                    // forward the exception
                    forward_exception_to_r(err);
                    
              } catch(...) {
                    ::Rf_error("c++ exception (unknown reason)");
              }
              
              // compute the LNA increment
              nat_lna = arma::vec(expm1(Rcpp::NumericVector(log_lna.begin(), log_lna.end())));
              
              // update the compartment volumes
              init_volumes += stoich_matrix * nat_lna;
              
              // throw errors for negative increments or negative volumes
              try{
                    if(any(nat_lna < 0)) {
                          throw std::runtime_error("Negative increment.");
                    }
                    
                    if(any(init_volumes < 0)) {
                          throw std::runtime_error("Negative compartment volumes.");
                    }
                    
              } catch(std::exception &err) {
                    
                    forward_exception_to_r(err);
                    
              } catch(...) {
                    ::Rf_error("c++ exception (unknown reason)");
              }      
              
              // save the increment and the prevalence
              lna_path(arma::span(1,n_events), j+1) = nat_lna;
              prev_path(arma::span(1,n_comps), j+1) = init_volumes;
              
              // apply forcings if called for - applied after censusing the path
              if(forcing_inds[j+1]) {
                    
                    // distribute the forcings proportionally to the compartment counts in the applicable states
                    for(int s=0; s < n_forcings; ++s) {
                          
                          forcing_flow       = lna_pars(j+1, forcing_tcov_inds[s]);
                          forcing_distvec    = forcing_flow * normalise(forcings_out.col(s) % init_volumes, 1);
                          init_volumes      += forcing_transfers.slice(s) * forcing_distvec;
                    }
                    
                    // throw errors for negative negative volumes
                    try{
                          if(any(init_volumes < 0)) {
                                throw std::runtime_error("Negative compartment volumes.");
                          }
                          
                    } catch(std::exception &err) {
                          
                          forward_exception_to_r(err);
                          
                    } catch(...) {
                          ::Rf_error("c++ exception (unknown reason)");
                    }
              }
              
              // update the parameters if they need to be updated
              if(param_update_inds[j+1]) {
                    
                    // time-varying covariates and parameters
                    std::copy(lna_pars.row(j+1).end() - n_tcovar,
                              lna_pars.row(j+1).end(),
                              current_params.end() - n_tcovar);
                    
              }
              
              // copy the compartment volumes to the current parameters
              std::copy(init_volumes.begin(), init_volumes.end(), current_params.begin() + init_start);
              
              // set the lna parameters and reset the LNA state vector
              CALL_SET_ODE_PARAMS(current_params, set_pars_pointer);
        }
        
        // return the paths
        return Rcpp::List::create(Rcpp::Named("draws")     = draws,
                                  Rcpp::Named("lna_path")  = lna_path.t(),
                                  Rcpp::Named("prev_path") = prev_path.t());
}