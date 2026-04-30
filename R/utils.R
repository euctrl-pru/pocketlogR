#' Default flow types
#'
#' A character vector of the default flow type identifiers used by pocketlogR.
#' These are not enforced — any string is accepted as a type. They exist for
#' documentation, consistency, and convenience.
#'
#' @export
pl_flow_types <- c(
  "data_job",
  "website_status",
  "email_check",
  "db_check",
  "website_online"
)

.valid_statuses <- c("SUCCESS", "ERROR", "FATAL")

pl_validate_conn <- function(conn) {
  if (!is.list(conn) || !all(c("url", "token") %in% names(conn))) {
    stop("'conn' must be a connection list with 'url' and 'token' elements. Use pl_connect() to create one.")
  }
  invisible(conn)
}

pl_base_req <- function(conn) {
  httr2::request(conn$url) |>
    httr2::req_headers(Authorization = conn$token)
}

pl_auth <- function(url, collection, email, password) {
  endpoint <- sprintf("%s/api/collections/%s/auth-with-password", url, collection)
  resp <- httr2::request(endpoint) |>
    httr2::req_body_json(list(identity = email, password = password)) |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) != 200) {
    body <- tryCatch(httr2::resp_body_json(resp), error = function(e) list())
    msg <- body$message %||% "Authentication failed"
    stop(sprintf("Authentication failed (%d): %s", httr2::resp_status(resp), msg))
  }

  httr2::resp_body_json(resp)$token
}

`%||%` <- function(x, y) if (!is.null(x)) x else y

pl_resolve_flow_id <- function(conn, flow_name) {
  filter <- sprintf('name = "%s"', flow_name)
  resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections", "pl_flows", "records") |>
    httr2::req_url_query(filter = filter, perPage = 1) |>
    httr2::req_perform()
  body <- httr2::resp_body_json(resp)
  if (length(body$items) == 0) {
    stop(sprintf("Flow '%s' not found.", flow_name))
  }
  body$items[[1]]$id
}

pl_resolve_flow_ids <- function(conn, flow_names) {
  if (is.null(flow_names) || length(flow_names) == 0) return(character(0))
  vapply(flow_names, pl_resolve_flow_id, character(1), conn = conn)
}

pl_get_all_flows_raw <- function(conn) {
  all_items <- list()
  page <- 1
  repeat {
    resp <- pl_base_req(conn) |>
      httr2::req_url_path_append("api", "collections", "pl_flows", "records") |>
      httr2::req_url_query(perPage = 200, page = page) |>
      httr2::req_perform()
    body <- httr2::resp_body_json(resp)
    all_items <- c(all_items, body$items)
    if (page >= body$totalPages) break
    page <- page + 1
  }
  all_items
}

pl_build_flow_name_map <- function(flows_raw) {
  ids <- vapply(flows_raw, `[[`, character(1), "id")
  names_vec <- vapply(flows_raw, `[[`, character(1), "name")
  stats::setNames(names_vec, ids)
}

# Safe named-vector lookup: returns NULL instead of erroring on missing keys.
pl_map_get <- function(map, key) {
  map[key][[1]]
}

# PocketBase returns "" for empty, a scalar string for one ID, or a list for multiple.
# Normalise all cases to a plain character vector of non-empty IDs.
pl_norm_dep_ids <- function(dep_ids) {
  if (is.null(dep_ids)) return(character(0))
  if (is.list(dep_ids)) dep_ids <- unlist(dep_ids)
  ids <- as.character(dep_ids)
  ids[nchar(ids) > 0]
}

pl_detect_cycle <- function(target_name, proposed_upstream_names, all_flows_raw) {
  id_map <- pl_build_flow_name_map(all_flows_raw)
  name_to_deps <- list()
  for (f in all_flows_raw) {
    dep_ids <- pl_norm_dep_ids(f$depends_on)
    if (length(dep_ids) == 0) {
      name_to_deps[[f$name]] <- character(0)
    } else {
      dep_names <- vapply(dep_ids, function(id) pl_map_get(id_map, id) %||% NA_character_, character(1))
      name_to_deps[[f$name]] <- dep_names[!is.na(dep_names)]
    }
  }

  visited <- character(0)
  stack <- proposed_upstream_names

  while (length(stack) > 0) {
    current <- stack[[1]]
    stack <- stack[-1]

    if (current == target_name) {
      return(TRUE)
    }

    if (current %in% visited) next
    visited <- c(visited, current)

    upstream <- name_to_deps[[current]]
    if (!is.null(upstream) && length(upstream) > 0) {
      stack <- c(stack, upstream)
    }
  }
  FALSE
}

pl_retry <- function(expr, times = 3, wait = 2) {
  expr_sub <- substitute(expr)
  caller_env <- parent.frame()
  child_env <- new.env(parent = caller_env)
  last_error <- NULL
  for (i in seq_len(times)) {
    result <- tryCatch(eval(expr_sub, envir = child_env), error = function(e) e)
    if (!inherits(result, "error")) return(result)
    last_error <- result
    if (i < times) Sys.sleep(wait)
  }
  last_error
}

pl_build_filter <- function(...) {
  parts <- list(...)
  parts <- Filter(Negate(is.null), parts)
  if (length(parts) == 0) return(NULL)
  paste(parts, collapse = " && ")
}

pl_format_timestamp <- function(ts) {
  if (is.null(ts)) return(NULL)
  if (inherits(ts, "POSIXct")) {
    format(ts, "%Y-%m-%d %H:%M:%S", tz = "UTC")
  } else {
    as.character(ts)
  }
}
