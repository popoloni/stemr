% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/construct_initdist_prior_lna.R
\name{construct_initdist_prior_lna}
\alias{construct_initdist_prior_lna}
\title{Construct a function for evaluating the log prior density of the initial
compartment concentrations (normalized volumes), which are taken to have
dirichlet prior.}
\usage{
construct_initdist_prior_lna(state_initializer, n_strata, constants)
}
\arguments{
\item{state_initializer}{list for intializing the comparment counts generated
by \code{\link{stem_dynamics}}.}

\item{n_strata}{number of strata.}

\item{constants}{vector of model constants, which contains the population
size and strata sizes.}
}
\value{
function for evaluating the log prior density of the initial
  compartment counts
}
\description{
Construct a function for evaluating the log prior density of the initial
compartment concentrations (normalized volumes), which are taken to have
dirichlet prior.
}
