#' Construct a stem object.
#'
#' @param stem_object an existing stochastic epidemic model object to which
#'   model settings should be added.
#' @param data a matrix/data frame, or a list of matrices/data frames. All
#'   columns must be named according to which compartment_strata are measured.
#'   The first column must consist of observation times, t_1,...,t_L. If data on
#'   all measured compartments are accrued at the same observation times, a
#'   single matrix or data frame may be provided. If each compartment in the
#'   data was measured at different observation times, a list of matrices or
#'   data frames must be provided. Again, the first column of each matrix must
#'   consist of observation times, while subsequent columns must be labeled
#'   according to which compartments are reflected.
#' @param dynamics A list of objects describing the model dynamics, most
#'   straighforwardly generated using the \code{stem_dynamics} function.
#' @param measurement_process list of functions to simulate from or evaluate the
#'   likelihood of the measurement process. These are most easily generated
#'   using the \code{stem_measure} function.
#' @param stem_settings otional list of inference settings, most
#'   straightforwardly generated using the \code{stem_control} function.
#'
#' @return returns a \code{stem} object.
#' @export
#'
stem <- function(stem_object = NULL, data = NULL, dynamics = NULL, measurement_process = NULL, stem_settings = NULL) {

        if(is.null(stem_object)) {
                stem_object <- structure(list(dynamics            = NULL,
                                              measurement_process = NULL,
                                              stem_settings       = NULL), class = "stem")
        }

        if(!is.null(dynamics))            stem_object$dynamics <- dynamics
        if(!is.null(measurement_process)) stem_object$measurement_process <- measurement_process
        if(!is.null(stem_settings))       stem_object$stem_settings <- stem_settings

        return(stem_object)
}