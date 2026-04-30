#' Add upstream dependencies to a flow
#'
#' Adds one or more upstream flows as dependencies of the target flow.
#' Validates that all named flows exist and that no cycle would be created.
#'
#' @param conn A connection object from [pl_connect()].
#' @param flow Name of the flow to update.
#' @param depends_on Character vector of upstream flow names to add.
#'
#' @return Invisibly returns the updated flow record.
#'
#' @examples
#' \dontrun{
#' conn <- pl_connect()
#' pl_add_dependency(conn, "ans_data_freshness", "another_upstream_flow")
#' }
#' @export
pl_add_dependency <- function(conn, flow, depends_on) {
  pl_validate_conn(conn)

  if (!is.character(flow) || length(flow) != 1) stop("'flow' must be a single character string.")
  if (!is.character(depends_on) || length(depends_on) == 0) stop("'depends_on' must be a non-empty character vector.")

  all_flows_raw <- pl_get_all_flows_raw(conn)
  target <- Filter(function(f) f$name == flow, all_flows_raw)
  if (length(target) == 0) stop(sprintf("Flow '%s' not found.", flow))
  target <- target[[1]]

  id_map <- pl_build_flow_name_map(all_flows_raw)
  current_dep_ids <- pl_norm_dep_ids(target$depends_on)

  new_dep_ids <- pl_resolve_flow_ids(conn, depends_on)

  all_proposed_names <- unique(c(
    vapply(current_dep_ids, function(id) pl_map_get(id_map, id) %||% id, character(1)),
    depends_on
  ))

  if (pl_detect_cycle(flow, all_proposed_names, all_flows_raw)) {
    stop(sprintf("Adding dependency would create a cycle involving flow '%s'.", flow))
  }

  combined_ids <- unique(unname(c(current_dep_ids, new_dep_ids)))

  resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections", "pl_flows", "records", target$id) |>
    httr2::req_body_json(list(depends_on = as.list(combined_ids))) |>
    httr2::req_method("PATCH") |>
    httr2::req_perform()

  cli::cli_alert_success("Dependencies updated for flow {.val {flow}}.")
  invisible(httr2::resp_body_json(resp))
}

#' Remove upstream dependencies from a flow
#'
#' Removes one or more upstream flows from the dependency list of the target flow.
#'
#' @param conn A connection object from [pl_connect()].
#' @param flow Name of the flow to update.
#' @param depends_on Character vector of upstream flow names to remove.
#'
#' @return Invisibly returns the updated flow record.
#'
#' @examples
#' \dontrun{
#' conn <- pl_connect()
#' pl_remove_dependency(conn, "ans_data_freshness", "another_upstream_flow")
#' }
#' @export
pl_remove_dependency <- function(conn, flow, depends_on) {
  pl_validate_conn(conn)

  if (!is.character(flow) || length(flow) != 1) stop("'flow' must be a single character string.")
  if (!is.character(depends_on) || length(depends_on) == 0) stop("'depends_on' must be a non-empty character vector.")

  all_flows_raw <- pl_get_all_flows_raw(conn)
  target <- Filter(function(f) f$name == flow, all_flows_raw)
  if (length(target) == 0) stop(sprintf("Flow '%s' not found.", flow))
  target <- target[[1]]

  remove_ids <- pl_resolve_flow_ids(conn, depends_on)
  current_dep_ids <- pl_norm_dep_ids(target$depends_on)
  remaining_ids <- unname(setdiff(current_dep_ids, remove_ids))

  resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections", "pl_flows", "records", target$id) |>
    httr2::req_body_json(list(depends_on = as.list(remaining_ids))) |>
    httr2::req_method("PATCH") |>
    httr2::req_perform()

  cli::cli_alert_success("Dependencies removed from flow {.val {flow}}.")
  invisible(httr2::resp_body_json(resp))
}

#' Get upstream dependencies of a flow
#'
#' Returns a data.frame of upstream flows for the named flow.
#'
#' @param conn A connection object from [pl_connect()].
#' @param flow Flow name.
#' @param recursive If `TRUE`, walks the full DAG upward and returns all
#'   transitive upstream dependencies. If `FALSE` (default), returns only
#'   direct (immediate) upstream dependencies.
#'
#' @return A data.frame with columns: `name`, `type`, `description`, `schedule`, `depth`.
#'
#' @examples
#' \dontrun{
#' conn <- pl_connect()
#' pl_get_dependencies(conn, "ans_monthly_update")
#' pl_get_dependencies(conn, "ans_monthly_update", recursive = TRUE)
#' }
#' @export
pl_get_dependencies <- function(conn, flow, recursive = FALSE) {
  pl_validate_conn(conn)

  all_flows_raw <- pl_get_all_flows_raw(conn)
  id_map <- pl_build_flow_name_map(all_flows_raw)
  name_to_flow <- stats::setNames(all_flows_raw, vapply(all_flows_raw, `[[`, character(1), "name"))

  target <- name_to_flow[[flow]]
  if (is.null(target)) stop(sprintf("Flow '%s' not found.", flow))

  .collect_deps <- function(flow_obj, depth, visited) {
    dep_ids <- pl_norm_dep_ids(flow_obj$depends_on)
    if (length(dep_ids) == 0) return(list())

    rows <- list()
    for (dep_id in dep_ids) {
      dep_name <- pl_map_get(id_map, dep_id)
      if (is.null(dep_name) || dep_name %in% visited) next
      dep_flow <- name_to_flow[[dep_name]]
      if (is.null(dep_flow)) next

      rows <- c(rows, list(list(
        name        = dep_name,
        type        = dep_flow$type %||% NA_character_,
        description = dep_flow$description %||% NA_character_,
        schedule    = dep_flow$schedule %||% NA_character_,
        depth       = depth
      )))

      if (recursive) {
        rows <- c(rows, .collect_deps(dep_flow, depth + 1, c(visited, dep_name)))
      }
    }
    rows
  }

  rows <- .collect_deps(target, 1, character(0))

  if (length(rows) == 0) {
    return(data.frame(
      name = character(0), type = character(0), description = character(0),
      schedule = character(0), depth = integer(0), stringsAsFactors = FALSE
    ))
  }

  data.frame(
    name        = vapply(rows, `[[`, character(1), "name"),
    type        = vapply(rows, `[[`, character(1), "type"),
    description = vapply(rows, `[[`, character(1), "description"),
    schedule    = vapply(rows, `[[`, character(1), "schedule"),
    depth       = as.integer(vapply(rows, function(r) r$depth, numeric(1))),
    stringsAsFactors = FALSE
  )
}

#' Get dependency chain health status for a flow
#'
#' Walks the DAG upward (recursively through all upstream dependencies) and
#' collects the most recent log entry for each flow in the chain, including
#' the flow itself.
#'
#' @param conn A connection object from [pl_connect()].
#' @param flow Flow name.
#' @param since Optional `POSIXct` or ISO 8601 string. If provided, only log
#'   entries created after this timestamp are considered. Flows with no logs
#'   since that time get `status = NA`.
#'
#' @return A data.frame sorted by `depth` then `flow`, with columns: `flow`,
#'   `type`, `status`, `message`, `created`, `depth`.
#'
#' @examples
#' \dontrun{
#' conn <- pl_connect()
#' pl_get_status(conn, "ans_monthly_update")
#' pl_get_status(conn, "ans_monthly_update", since = Sys.time() - 86400)
#' }
#' @export
pl_get_status <- function(conn, flow, since = NULL) {
  pl_validate_conn(conn)

  all_flows_raw <- pl_get_all_flows_raw(conn)
  id_map <- pl_build_flow_name_map(all_flows_raw)
  name_to_flow <- stats::setNames(all_flows_raw, vapply(all_flows_raw, `[[`, character(1), "name"))

  target <- name_to_flow[[flow]]
  if (is.null(target)) stop(sprintf("Flow '%s' not found.", flow))

  .collect_chain <- function(flow_obj, depth, visited) {
    fname <- flow_obj$name
    if (fname %in% visited) return(list())
    visited <- c(visited, fname)

    latest_log <- .fetch_latest_log(conn, fname, since)

    row <- list(list(
      flow    = fname,
      type    = flow_obj$type %||% NA_character_,
      status  = latest_log$status,
      message = latest_log$message,
      created = latest_log$created,
      depth   = depth
    ))

    dep_ids <- pl_norm_dep_ids(flow_obj$depends_on)
    for (dep_id in dep_ids) {
      dep_name <- pl_map_get(id_map, dep_id)
      if (is.null(dep_name)) next
      dep_flow <- name_to_flow[[dep_name]]
      if (is.null(dep_flow)) next
      row <- c(row, .collect_chain(dep_flow, depth + 1, visited))
    }
    row
  }

  rows <- .collect_chain(target, 0, character(0))

  df <- data.frame(
    flow    = vapply(rows, `[[`, character(1), "flow"),
    type    = vapply(rows, `[[`, character(1), "type"),
    status  = vapply(rows, function(r) r$status %||% NA_character_, character(1)),
    message = vapply(rows, function(r) r$message %||% NA_character_, character(1)),
    created = vapply(rows, function(r) r$created %||% NA_character_, character(1)),
    depth   = as.integer(vapply(rows, function(r) r$depth, numeric(1))),
    stringsAsFactors = FALSE
  )

  df[order(df$depth, df$flow), ]
}

.fetch_latest_log <- function(conn, flow_name, since = NULL) {
  filter_parts <- sprintf('flow.name = "%s"', flow_name)
  if (!is.null(since)) {
    filter_parts <- c(filter_parts, sprintf('created >= "%s"', pl_format_timestamp(since)))
  }
  filter <- paste(filter_parts, collapse = " && ")

  resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections", "pl_logs", "records") |>
    httr2::req_url_query(filter = filter, sort = "-id", perPage = 1) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) != 200) return(list(status = NA_character_, message = NA_character_, created = NA_character_))

  body <- httr2::resp_body_json(resp)
  if (length(body$items) == 0) return(list(status = NA_character_, message = NA_character_, created = NA_character_))

  item <- body$items[[1]]
  list(
    status  = item$status %||% NA_character_,
    message = item$message %||% NA_character_,
    created = item$created %||% NA_character_
  )
}

#' Get a full DAG overview of all flows and their health
#'
#' Returns a tibble (data.frame) of ALL flows with both their raw (most recent
#' log) status and effective (cascade-aware) status. A flow is considered
#' "poisoned" if any upstream dependency has a more recent ERROR/FATAL log
#' than the flow's own last SUCCESS log — meaning the flow ran successfully
#' before the upstream broke.
#'
#' @param conn A connection object from [pl_connect()].
#' @param since Optional `POSIXct` or ISO 8601 string. If provided, only
#'   considers log entries created after this timestamp.
#'
#' @return A data.frame with columns:
#'   - `flow` (character): flow name
#'   - `type` (character): flow type
#'   - `schedule` (character): schedule string
#'   - `raw_status` (character): most recent log status (`NA` if never logged)
#'   - `raw_status_time` (character): timestamp of most recent log
#'   - `effective_status` (character): `"SUCCESS"`, `"ERROR"`, `"FATAL"`,
#'     `"POISONED"`, or `NA` if never logged
#'   - `poisoned_by` (list-column): character vector of upstream flow names
#'     that caused poisoning
#'   - `depends_on` (list-column): character vector of direct upstream flow names
#'   - `is_root` (logical): `TRUE` if the flow has no upstream dependencies
#'
#' @details
#' **Poisoning rule:** A downstream flow is poisoned if:
#' 1. It has at least one upstream flow with an ERROR or FATAL log.
#' 2. The downstream's last SUCCESS log is MORE RECENT than that upstream failure.
#'    (i.e., the downstream ran successfully after the upstream had already broken.)
#' 3. The downstream itself is not already ERROR or FATAL.
#'
#' If the downstream has never logged, `effective_status` is `NA` (unknown),
#' regardless of upstream status.
#'
#' @examples
#' \dontrun{
#' conn <- pl_connect()
#' dag <- pl_get_dag(conn)
#' dag
#' }
#' @export
pl_get_dag <- function(conn, since = NULL) {
  pl_validate_conn(conn)

  all_flows_raw <- pl_get_all_flows_raw(conn)
  if (length(all_flows_raw) == 0) {
    return(data.frame(
      flow = character(0), type = character(0), schedule = character(0),
      raw_status = character(0), raw_status_time = character(0),
      effective_status = character(0),
      poisoned_by = I(list()), depends_on = I(list()), is_root = logical(0),
      stringsAsFactors = FALSE
    ))
  }

  id_map <- pl_build_flow_name_map(all_flows_raw)
  name_to_flow <- stats::setNames(all_flows_raw, vapply(all_flows_raw, `[[`, character(1), "name"))

  latest_logs <- stats::setNames(
    lapply(all_flows_raw, function(f) .fetch_latest_log(conn, f$name, since)),
    vapply(all_flows_raw, `[[`, character(1), "name")
  )

  .parse_ts <- function(ts_str) {
    if (is.null(ts_str) || is.na(ts_str) || nchar(ts_str) == 0) return(NA)
    tryCatch(as.POSIXct(ts_str, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC"), error = function(e) NA)
  }

  .get_all_upstream <- function(flow_name, visited) {
    f <- name_to_flow[[flow_name]]
    if (is.null(f)) return(character(0))
    dep_ids <- pl_norm_dep_ids(f$depends_on)
    if (length(dep_ids) == 0) return(character(0))

    upstream <- character(0)
    for (dep_id in dep_ids) {
      dep_name <- pl_map_get(id_map, dep_id)
      if (is.null(dep_name) || dep_name %in% visited) next
      upstream <- c(upstream, dep_name)
      upstream <- c(upstream, .get_all_upstream(dep_name, c(visited, dep_name)))
    }
    unique(upstream)
  }

  rows <- lapply(all_flows_raw, function(f) {
    fname   <- f$name
    log     <- latest_logs[[fname]]
    dep_ids <- pl_norm_dep_ids(f$depends_on)
    dep_names <- if (length(dep_ids) > 0) {
      vapply(dep_ids, function(id) pl_map_get(id_map, id) %||% id, character(1))
    } else {
      character(0)
    }

    raw_status      <- log$status  %||% NA_character_
    raw_status_time <- log$created %||% NA_character_
    is_root         <- length(dep_ids) == 0

    last_success_ts <- NA
    if (!is.na(raw_status) && raw_status == "SUCCESS") {
      last_success_ts <- .parse_ts(raw_status_time)
    }

    if (is.na(raw_status)) {
      effective_status <- NA_character_
      poisoned_by_vec  <- character(0)
    } else if (raw_status %in% c("ERROR", "FATAL")) {
      effective_status <- raw_status
      poisoned_by_vec  <- character(0)
    } else {
      all_upstream <- .get_all_upstream(fname, character(0))
      poisoners <- character(0)

      for (up_name in all_upstream) {
        up_log    <- latest_logs[[up_name]]
        up_status <- up_log$status %||% NA_character_
        if (!is.na(up_status) && up_status %in% c("ERROR", "FATAL")) {
          up_ts <- .parse_ts(up_log$created %||% NA_character_)
          if (!is.na(last_success_ts) && !is.na(up_ts) && last_success_ts > up_ts) {
            poisoners <- c(poisoners, up_name)
          }
        }
      }

      if (length(poisoners) > 0) {
        effective_status <- "POISONED"
        poisoned_by_vec  <- poisoners
      } else {
        effective_status <- raw_status
        poisoned_by_vec  <- character(0)
      }
    }

    list(
      flow             = fname,
      type             = f$type %||% NA_character_,
      schedule         = f$schedule %||% NA_character_,
      raw_status       = raw_status,
      raw_status_time  = raw_status_time,
      effective_status = effective_status,
      poisoned_by      = list(poisoned_by_vec),
      depends_on       = list(dep_names),
      is_root          = is_root
    )
  })

  data.frame(
    flow             = vapply(rows, `[[`, character(1), "flow"),
    type             = vapply(rows, `[[`, character(1), "type"),
    schedule         = vapply(rows, function(r) r$schedule %||% NA_character_, character(1)),
    raw_status       = vapply(rows, function(r) r$raw_status %||% NA_character_, character(1)),
    raw_status_time  = vapply(rows, function(r) r$raw_status_time %||% NA_character_, character(1)),
    effective_status = vapply(rows, function(r) r$effective_status %||% NA_character_, character(1)),
    poisoned_by      = I(lapply(rows, function(r) r$poisoned_by[[1]])),
    depends_on       = I(lapply(rows, function(r) r$depends_on[[1]])),
    is_root          = vapply(rows, `[[`, logical(1), "is_root"),
    stringsAsFactors = FALSE
  )
}
