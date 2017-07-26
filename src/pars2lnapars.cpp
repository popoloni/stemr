#include <RcppArmadillo.h>
using namespace Rcpp;
using namespace arma;

//' Identify which rates to update when a state transition event occurs.
//'
//' @param lnapars matrix of lna parameters, constants, and time-varying covars
//' @param parameters vector of parameters to be copied into the matrix
//'
//' @return modifies the lna parameter matrix in place
//' @export
// [[Rcpp::export]]
void pars2lnapars(arma::mat& lnapars, const arma::rowvec& parameters) {

        int n_pars  = parameters.n_elem;
        lnapars.cols(0, n_pars-1).each_row() = parameters;
}

//' Copy an element from one vector into another
//'
//' @param dest destination row vector
//' @param orig origin row vector
//' @param ind C++ style index for the element to be copied
//'
//' @return copy an element of one row vector into another.
//' @export
// [[Rcpp::export]]
void copy_elem(arma::rowvec& dest, const arma::rowvec& orig, int ind) {

        dest[ind] = orig[ind];
}

//' Copy the contents of one vector into another
//'
//' @param dest destination row vector
//' @param orig origin row vector
//'
//' @return copy the elements of one row vector into another.
//' @export
// [[Rcpp::export]]
void copy_vec(arma::rowvec& dest, const arma::rowvec& orig) {

        dest = orig;
}

//' Copy the contents of one matrix into another
//'
//' @param dest destination matrix
//' @param orig origin matrix
//'
//' @return copy the elements of one matrix into another.
//' @export
// [[Rcpp::export]]
void copy_mat(arma::mat& dest, const arma::mat& orig) {

        dest = orig;
}

//' Copy the contents of one matrix into another
//'
//' @param dest destination matrix
//' @param orig origin matrix
//' @param ind column index
//'
//' @return copy the elements of one matrix into another.
//' @export
// [[Rcpp::export]]
void copy_col(arma::mat& dest, const arma::mat& orig, int ind) {

        dest.col(ind) = orig.col(ind);
}

//' Copy some of the rows of one matrix into another
//'
//' @param dest destination matrix
//' @param orig origin matrix
//' @param inds column index
//'
//' @return copy the elements of one matrix into another.
//' @export
// [[Rcpp::export]]
void copy_2_rows(arma::mat& dest, const arma::mat& orig, const arma::uvec& inds) {

        dest.rows(inds) = orig;
}

