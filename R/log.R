#' Log an event for a flow
#'
#' Records a log entry for the named flow. On HTTP failure, retries up to
#' 3 times with 2-second intervals. If all retries fail, emits a warning
#' and returns `NULL` invisibly — the calling script is never stopped.
#'
#' @param conn A connection object from [pl_connect()].
#' @param flow Flow name (character).
#' @param status One of `"SUCCESS"`, `"ERROR"`, or `"FATAL"`.
#' @param log_type Free-text log type (e.g. `"data_job"`, `"website_online"`).
#'   See [pl_log_types] for standard values, but any string is accepted.
#' @param message Optional human-readable log message.
#' @param metadata Optional named list, serialized to JSON.
#'
#' @return Invisibly returns the created log record, or `NULL` on failure.
#'
#' @examples
#' \dontrun{
#' conn <- pl_connect()
#' pl_log(conn, "ectrl_data_load", "SUCCESS", log_type = "data_job",
#'        message = "Loaded 14230 rows",
#'        metadata = list(rows = 14230, duration_s = 45.2))
#' }
#' @export
pl_log <- function(conn, flow, status, log_type, message = NULL, metadata = NULL) {
  pl_validate_conn(conn)

  if (!status %in% .valid_statuses) {
    stop(sprintf("'status' must be one of: %s", paste(.valid_statuses, collapse = ", ")))
  }
  if (!is.character(flow) || length(flow) != 1 || nchar(flow) == 0) {
    stop("'flow' must be a non-empty character string.")
  }
  if (!is.character(log_type) || length(log_type) != 1 || nchar(log_type) == 0) {
    stop("'log_type' must be a non-empty character string.")
  }

  result <- pl_retry(
    {
      flow_id <- pl_resolve_flow_id(conn, flow)

      body <- list(
        flow     = flow_id,
        log_type = log_type,
        status   = status,
        message  = message
      )
      if (!is.null(metadata)) {
        body$metadata <- jsonlite::toJSON(metadata, auto_unbox = TRUE)
      }
      body <- Filter(Negate(is.null), body)

      resp <- pl_base_req(conn) |>
        httr2::req_url_path_append("api", "collections", "pl_logs", "records") |>
        httr2::req_body_json(body) |>
        httr2::req_method("POST") |>
        httr2::req_perform()

      httr2::resp_body_json(resp)
    },
    times = 3,
    wait = 2
  )

  if (inherits(result, "error")) {
    warning(sprintf(
      "pocketlogR: failed to log event for flow '%s' after 3 attempts: %s",
      flow, conditionMessage(result)
    ))
    return(invisible(NULL))
  }

  invisible(result)
}

#' Log a SUCCESS event
#'
#' Convenience wrapper around [pl_log()] for successful outcomes.
#'
#' @param conn A connection object from [pl_connect()].
#' @param flow Flow name (character).
#' @param log_type Free-text log type (e.g. `"data_job"`, `"website_online"`).
#'   See [pl_log_types] for standard values, but any string is accepted.
#' @param message Optional human-readable log message.
#' @param metadata Optional named list, serialized to JSON.
#'
#' @return Invisibly returns the created log record, or `NULL` on failure.
#'
#' @examples
#' \dontrun{
#' pl_success(conn, "ectrl_data_load", log_type = "data_job",
#'            message = "Loaded 14230 rows",
#'            metadata = list(rows = 14230))
#' }
#' @export
pl_success <- function(conn, flow, log_type, message = NULL, metadata = NULL) {
  pl_log(conn, flow, "SUCCESS", log_type = log_type, message = message, metadata = metadata)
}

#' Log an ERROR event
#'
#' Convenience wrapper around [pl_log()] for recoverable errors.
#'
#' @param conn A connection object from [pl_connect()].
#' @param flow Flow name (character).
#' @param log_type Free-text log type (e.g. `"data_job"`, `"website_online"`).
#'   See [pl_log_types] for standard values, but any string is accepted.
#' @param message Optional human-readable log message.
#' @param metadata Optional named list, serialized to JSON.
#'
#' @return Invisibly returns the created log record, or `NULL` on failure.
#'
#' @examples
#' \dontrun{
#' pl_error(conn, "ans_website_online", log_type = "website_online",
#'          message = "HTTP 503 returned",
#'          metadata = list(http_status = 503))
#' }
#' @export
pl_error <- function(conn, flow, log_type, message = NULL, metadata = NULL) {
  pl_log(conn, flow, "ERROR", log_type = log_type, message = message, metadata = metadata)
}

#' Log a FATAL event
#'
#' Convenience wrapper around [pl_log()] for unrecoverable failures.
#'
#' @param conn A connection object from [pl_connect()].
#' @param flow Flow name (character).
#' @param log_type Free-text log type (e.g. `"data_job"`, `"website_online"`).
#'   See [pl_log_types] for standard values, but any string is accepted.
#' @param message Optional human-readable log message.
#' @param metadata Optional named list, serialized to JSON.
#'
#' @return Invisibly returns the created log record, or `NULL` on failure.
#'
#' @examples
#' \dontrun{
#' pl_fatal(conn, "ectrl_data_load", log_type = "data_job",
#'          message = "Unrecoverable database error")
#' }
#' @export
pl_fatal <- function(conn, flow, log_type, message = NULL, metadata = NULL) {
  pl_log(conn, flow, "FATAL", log_type = log_type, message = message, metadata = metadata)
}
