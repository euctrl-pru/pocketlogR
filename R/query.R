#' Query log entries
#'
#' Returns a data.frame of log entries, optionally filtered. All filter
#' arguments are optional and combined with AND logic.
#'
#' @param conn A connection object from [pl_connect()].
#' @param flow Optional flow name to filter by.
#' @param status Optional status to filter by (`"SUCCESS"`, `"ERROR"`, or `"FATAL"`).
#' @param from Optional start timestamp (`POSIXct` or ISO 8601 string).
#' @param to Optional end timestamp (`POSIXct` or ISO 8601 string).
#' @param limit Maximum number of records to return. Default 50.
#'
#' @return A data.frame with columns: `id`, `flow` (flow name), `status`,
#'   `message`, `metadata`, `created`.
#'
#' @examples
#' \dontrun{
#' conn <- pl_connect()
#' pl_get_logs(conn)
#' pl_get_logs(conn, flow = "ectrl_data_load", status = "ERROR")
#' pl_get_logs(conn, from = Sys.time() - 86400, limit = 100)
#' }
#' @export
pl_get_logs <- function(conn, flow = NULL, status = NULL, from = NULL, to = NULL, limit = 50) {
  pl_validate_conn(conn)

  if (!is.null(status) && !status %in% .valid_statuses) {
    stop(sprintf("'status' must be one of: %s", paste(.valid_statuses, collapse = ", ")))
  }

  filter_parts <- c(
    if (!is.null(flow))   sprintf('flow.name = "%s"', flow),
    if (!is.null(status)) sprintf('status = "%s"', status),
    if (!is.null(from))   sprintf('created >= "%s"', pl_format_timestamp(from)),
    if (!is.null(to))     sprintf('created <= "%s"', pl_format_timestamp(to))
  )
  filter <- if (length(filter_parts) > 0) paste(filter_parts, collapse = " && ") else NULL

  req <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections", "pl_logs", "records") |>
    httr2::req_url_query(
      perPage = limit,
      sort    = "-id",
      expand  = "flow"
    )

  if (!is.null(filter)) req <- httr2::req_url_query(req, filter = filter)

  resp <- httr2::req_perform(req)
  body <- httr2::resp_body_json(resp)
  items <- body$items

  if (length(items) == 0) {
    return(data.frame(
      id = character(0), flow = character(0), status = character(0),
      message = character(0), metadata = I(list()), created = character(0),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    id       = vapply(items, function(i) i$id %||% NA_character_, character(1)),
    flow     = vapply(items, function(i) {
      (i$expand$flow$name %||% i$flow) %||% NA_character_
    }, character(1)),
    status   = vapply(items, function(i) i$status %||% NA_character_, character(1)),
    message  = vapply(items, function(i) i$message %||% NA_character_, character(1)),
    metadata = I(lapply(items, function(i) i$metadata)),
    created  = vapply(items, function(i) i$created %||% NA_character_, character(1)),
    stringsAsFactors = FALSE
  )
}
