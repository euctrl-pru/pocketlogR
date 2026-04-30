#' Delete a flow (admin only)
#'
#' Deletes a flow by name. Requires a superuser connection. Because PocketBase
#' enforces referential integrity, any log entries referencing the flow must be
#' deleted first. Use `force = TRUE` to do this automatically.
#'
#' @param conn A superuser connection object from [pl_connect_admin()].
#' @param flow Flow name (character).
#' @param force If `TRUE`, deletes all log entries for this flow before deleting
#'   the flow itself. If `FALSE` (default), errors if log entries exist.
#'
#' @return Invisibly returns `NULL`.
#'
#' @examples
#' \dontrun{
#' conn_admin <- pl_connect_admin()
#' pl_delete_flow(conn_admin, "old_flow", force = TRUE)
#' }
#' @export
pl_delete_flow <- function(conn, flow, force = FALSE) {
  pl_validate_conn(conn)

  if (!is.character(flow) || length(flow) != 1 || nchar(flow) == 0)
    stop("'flow' must be a non-empty character string.")

  flows <- .pl_get_flows_raw_by_name(conn, flow)
  if (length(flows) == 0) stop(sprintf("Flow '%s' not found.", flow))
  flow_id <- flows[[1]]$id

  if (force) {
    n_deleted <- .pl_delete_logs_for_flow(conn, flow_id)
    if (n_deleted > 0) cli::cli_alert_info("Deleted {n_deleted} log entr{?y/ies} for flow {.val {flow}}.")
  }

  resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections", "pl_flows", "records", flow_id) |>
    httr2::req_method("DELETE") |>
    httr2::req_error(is_error = function(r) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 400) {
    raw <- tryCatch(httr2::resp_body_json(resp), error = function(e) list())
    if (grepl("constraint", raw$message %||% "", ignore.case = TRUE) ||
        grepl("relation", raw$message %||% "", ignore.case = TRUE)) {
      stop(sprintf(
        "Flow '%s' has log entries. Use force = TRUE to delete them first.",
        flow
      ))
    }
    stop(sprintf("Failed to delete flow '%s': %s", flow, raw$message %||% httr2::resp_status(resp)))
  }

  if (!httr2::resp_status(resp) %in% c(200, 204)) {
    raw <- tryCatch(httr2::resp_body_string(resp), error = function(e) "(unreadable)")
    stop(sprintf("Failed to delete flow '%s' (HTTP %d): %s", flow, httr2::resp_status(resp), raw))
  }

  cli::cli_alert_success("Flow {.val {flow}} deleted.")
  invisible(NULL)
}

#' Delete log entries (admin only)
#'
#' Deletes log entries. Requires a superuser connection. All filter arguments
#' are optional and combined with AND logic. Called with no filters, deletes
#' all log entries.
#'
#' @param conn A superuser connection object from [pl_connect_admin()].
#' @param flow Optional flow name. If provided, only logs for that flow are deleted.
#' @param before Optional `POSIXct` or ISO 8601 string. If provided, only logs
#'   created before this timestamp are deleted.
#' @param status Optional status string (`"SUCCESS"`, `"ERROR"`, or `"FATAL"`).
#'   If provided, only logs with that status are deleted.
#'
#' @return Invisibly returns the number of deleted records.
#'
#' @examples
#' \dontrun{
#' conn_admin <- pl_connect_admin()
#'
#' # Delete all logs older than 30 days
#' pl_delete_logs(conn_admin, before = Sys.time() - 30 * 86400)
#'
#' # Delete all error logs for a specific flow
#' pl_delete_logs(conn_admin, flow = "ectrl_data_load", status = "ERROR")
#'
#' # Delete all logs for a flow (used internally by pl_delete_flow(force=TRUE))
#' pl_delete_logs(conn_admin, flow = "old_flow")
#' }
#' @export
pl_delete_logs <- function(conn, flow = NULL, before = NULL, status = NULL) {
  pl_validate_conn(conn)

  if (!is.null(status) && !status %in% .valid_statuses) {
    stop(sprintf("'status' must be one of: %s", paste(.valid_statuses, collapse = ", ")))
  }

  filter_parts <- c(
    if (!is.null(flow))   sprintf('flow.name = "%s"', flow),
    if (!is.null(status)) sprintf('status = "%s"', status),
    if (!is.null(before)) sprintf('created <= "%s"', pl_format_timestamp(before))
  )
  filter <- if (length(filter_parts) > 0) paste(filter_parts, collapse = " && ") else NULL

  ids <- .pl_collect_log_ids(conn, filter)
  if (length(ids) == 0) {
    cli::cli_alert_info("No log entries matched — nothing deleted.")
    return(invisible(0L))
  }

  for (id in ids) {
    resp <- pl_base_req(conn) |>
      httr2::req_url_path_append("api", "collections", "pl_logs", "records", id) |>
      httr2::req_method("DELETE") |>
      httr2::req_error(is_error = function(r) FALSE) |>
      httr2::req_perform()

    if (!httr2::resp_status(resp) %in% c(200, 204)) {
      raw <- tryCatch(httr2::resp_body_string(resp), error = function(e) "(unreadable)")
      warning(sprintf("Failed to delete log %s (HTTP %d): %s", id, httr2::resp_status(resp), raw))
    }
  }

  cli::cli_alert_success("Deleted {length(ids)} log entr{?y/ies}.")
  invisible(length(ids))
}

# ── Internal helpers ──────────────────────────────────────────────────────────

.pl_get_flows_raw_by_name <- function(conn, flow_name) {
  filter <- sprintf('name = "%s"', flow_name)
  resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections", "pl_flows", "records") |>
    httr2::req_url_query(filter = filter, perPage = 1) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)$items
}

.pl_collect_log_ids <- function(conn, filter = NULL) {
  ids <- character(0)
  page <- 1
  repeat {
    req <- pl_base_req(conn) |>
      httr2::req_url_path_append("api", "collections", "pl_logs", "records") |>
      httr2::req_url_query(perPage = 200, page = page, fields = "id")
    if (!is.null(filter)) req <- httr2::req_url_query(req, filter = filter)

    resp <- httr2::req_perform(req)
    body <- httr2::resp_body_json(resp)
    ids  <- c(ids, vapply(body$items, `[[`, character(1), "id"))
    if (page >= body$totalPages) break
    page <- page + 1
  }
  ids
}

.pl_delete_logs_for_flow <- function(conn, flow_id) {
  filter <- sprintf('flow = "%s"', flow_id)
  ids <- .pl_collect_log_ids(conn, filter)
  for (id in ids) {
    pl_base_req(conn) |>
      httr2::req_url_path_append("api", "collections", "pl_logs", "records", id) |>
      httr2::req_method("DELETE") |>
      httr2::req_error(is_error = function(r) FALSE) |>
      httr2::req_perform()
  }
  length(ids)
}
