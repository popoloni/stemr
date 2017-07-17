// [[Rcpp::depends(RcppArmadillo)]]
#include <RcppArmadillo.h>

using namespace Rcpp;
using namespace arma;

//' Componentwise Metropolis random walk transition kernel
//'
//' @param params_prop vector in which the proposed parameters should be stored
//' @param params_cur vector containing the current parameter vector
//' @param ind C++ style index for the component index
//' @param kernel_cov vector of component proposal standard deviations
//'
//' @return propose new parameter values in place
//' @export
// [[Rcpp::export]]
void c_rw_adaptive(arma::rowvec& params_prop,
                   const arma::rowvec& params_cur,
                   int ind,
                   const arma::vec& kernel_cov,
                   const arma::vec& proposal_scaling,
                   const arma::vec& adaptations,
                   const arma::vec& nugget) {

        params_prop[ind] = params_cur[ind] +
                nugget[ind] * arma::randn(1)[0] +
                (1 - nugget[ind]) * arma::randn(1)[0] * kernel_cov[ind];
}