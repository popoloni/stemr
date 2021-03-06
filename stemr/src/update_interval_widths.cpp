// [[Rcpp::depends(RcppArmadillo)]]
#include <RcppArmadillo.h>

using namespace Rcpp;
using namespace arma;

//' Update factors and interval widths for automated factor slice sampling
//'
//' @param interval_widths vector of interval widths
//' @param n_expansions_afss vector with number of expansion
//' @param n_contractions_afss vector with number of contractions
//' @param c_expansions_afss cumulative numbers of expansions
//' @param c_contractions_afss cumulative numbers of contractions
//' @param slice_ratios vector for storing ratio of cumulative number of 
//'   expansions over number of interval width changes
//' @param adaptation_factor 
//'
//' @return adapt interval widths in place
//' @export
// [[Rcpp::export]]
void update_interval_widths(arma::vec& interval_widths,
                            arma::vec& n_expansions_afss,
                            arma::vec& n_contractions_afss,
                            const arma::vec& c_expansions_afss,
                            const arma::vec& c_contractions_afss,
                            arma::vec& slice_ratios,
                            double adaptation_factor,
                            double target_ratio) {
      
      // update the expansion-contraction ratios
      slice_ratios = c_expansions_afss / (c_expansions_afss + c_contractions_afss);
      
      // substitute the slice ratios for where there are zero expansions or contractions
      arma::uvec exp_zeros = arma::find(n_expansions_afss == 0);
      arma::uvec con_zeros = arma::find(n_contractions_afss == 0);
      n_expansions_afss.elem(exp_zeros) = slice_ratios.elem(exp_zeros);
      n_contractions_afss.elem(con_zeros) = slice_ratios.elem(con_zeros);
      
      // update the interval widths -- Robbins-Monro recursion
      interval_widths = arma::exp(
            log(interval_widths) +
                  adaptation_factor * (n_expansions_afss / (n_expansions_afss + n_contractions_afss) - target_ratio));
      
      // reset the number of contractions and expansions
      n_expansions_afss.zeros();
      n_contractions_afss.zeros();      
}