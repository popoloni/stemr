% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/initialize_ode.R
\name{initialize_ode}
\alias{initialize_ode}
\title{Initialize the LNA path}
\usage{
initialize_ode(
  data,
  ode_parameters,
  tparam,
  censusmat,
  emitmat,
  stoich_matrix,
  ode_pointer,
  ode_set_pars_pointer,
  ode_times,
  ode_param_vec,
  ode_param_inds,
  ode_const_inds,
  ode_tcovar_inds,
  ode_initdist_inds,
  param_update_inds,
  census_indices,
  ode_event_inds,
  measproc_indmat,
  d_meas_pointer,
  do_prevalence,
  forcing_inds,
  forcing_tcov_inds,
  forcings_out,
  forcing_transfers,
  initialization_attempts,
  step_size,
  fixed_inits,
  init_volumes_cur,
  initdist_objects,
  par_init_fcn = NULL
)
}
\arguments{
\item{data}{matrix containing the dataset}

\item{ode_parameters}{parameters, contants, time-varying covariates at ode
times}

\item{censusmat}{template matrix for the ode path and incidence at the
observation times}

\item{emitmat}{matrix in which to store the log-emission probabilities}

\item{stoich_matrix}{ode stoichiometry matrix}

\item{ode_pointer}{external ode pointer}

\item{ode_set_pars_pointer}{pointer for setting the ode parameters}

\item{ode_times}{times at whicht eh ode should be evaluated}

\item{ode_param_inds}{C++ column indices for parameters}

\item{ode_const_inds}{C++ column indices for constants}

\item{ode_tcovar_inds}{C++ column indices for time varying covariates}

\item{ode_initdist_inds}{C++ column indices in the ode parameter matrix for
the initial state}

\item{param_update_inds}{logical vector indicating when to update the
parameters}

\item{census_indices}{C++ row indices of ode times when the path is to be
censused}

\item{ode_event_inds}{vector of column indices in the ode path for which
incidence will be computed.}

\item{measproc_indmat}{logical matrix for evaluating the measuement process}

\item{d_meas_pointer}{external pointer for the measurement process function}

\item{do_prevalence}{should prevalence be computed?}

\item{forcing_inds}{logical vector of indicating at which times in the
time-varying covariance matrix a forcing is applied.}

\item{initialization_attempts}{number of initialization attempts}

\item{step_size}{initial step size for the ODE solver (adapted internally,
but too large of an initial step can lead to failure in stiff systems).}
}
\value{
ODE path
}
\description{
Initialize the LNA path
}
