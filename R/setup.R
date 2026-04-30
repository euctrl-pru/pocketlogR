#' Set up pocketlogR collections in PocketBase
#'
#' Creates the `pl_flows` and `pl_logs` collections with the correct schema and
#' API rules. Requires a superuser connection from [pl_connect_admin()].
#' This function is idempotent — safe to call multiple times.
#'
#' @param conn A superuser connection object from [pl_connect_admin()].
#'
#' @return Invisibly returns `NULL`.
#'
#' @examples
#' \dontrun{
#' conn_admin <- pl_connect_admin()
#' pl_setup(conn_admin)
#' }
#' @export
pl_setup <- function(conn) {
  pl_validate_conn(conn)

  existing <- .pl_list_collections(conn)
  existing_names <- vapply(existing, `[[`, character(1), "name")

  if (!"pl_flows" %in% existing_names) {
    cli::cli_alert_info("Creating collection {.val pl_flows}...")
    .pl_create_flows_collection(conn)
    cli::cli_alert_success("Collection {.val pl_flows} created.")
  } else {
    cli::cli_alert_info("Collection {.val pl_flows} already exists, skipping.")
  }

  if (!"pl_logs" %in% existing_names) {
    cli::cli_alert_info("Creating collection {.val pl_logs}...")
    .pl_create_logs_collection(conn)
    cli::cli_alert_success("Collection {.val pl_logs} created.")
  } else {
    cli::cli_alert_info("Collection {.val pl_logs} already exists, skipping.")
  }

  cli::cli_alert_success("pocketlogR setup complete.")
  invisible(NULL)
}

.pl_list_collections <- function(conn) {
  resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections") |>
    httr2::req_url_query(perPage = 200) |>
    httr2::req_perform()
  httr2::resp_body_json(resp)$items
}

.pl_create_flows_collection <- function(conn) {
  # Step 1: create without the self-referencing relation (can't reference own ID before it exists)
  body <- list(
    name = "pl_flows",
    type = "base",
    fields = list(
      list(name = "name",        type = "text", required = TRUE),
      list(name = "description", type = "text", required = FALSE),
      list(name = "type",        type = "text", required = TRUE),
      list(name = "schedule",    type = "text", required = FALSE)
    ),
    listRule   = "@request.auth.id != \"\"",
    viewRule   = "@request.auth.id != \"\"",
    createRule = "@request.auth.id != \"\"",
    updateRule = "@request.auth.id != \"\"",
    deleteRule = NULL
  )

  resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections") |>
    httr2::req_body_json(body) |>
    httr2::req_method("POST") |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  if (!httr2::resp_status(resp) %in% c(200, 201)) {
    raw <- tryCatch(httr2::resp_body_string(resp), error = function(e) "(unreadable)")
    stop(sprintf("Failed to create pl_flows collection (HTTP %d): %s",
                 httr2::resp_status(resp), raw))
  }

  col <- httr2::resp_body_json(resp)
  col_id <- col$id

  # Step 2: PATCH to add the self-referencing depends_on relation
  patch_body <- list(
    fields = c(col$fields, list(
      list(
        name          = "depends_on",
        type          = "relation",
        required      = FALSE,
        maxSelect     = 999L,
        collectionId  = col_id,
        cascadeDelete = FALSE
      )
    ))
  )

  patch_resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections", col_id) |>
    httr2::req_body_json(patch_body) |>
    httr2::req_method("PATCH") |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  if (!httr2::resp_status(patch_resp) %in% c(200, 201)) {
    raw <- tryCatch(httr2::resp_body_string(patch_resp), error = function(e) "(unreadable)")
    stop(sprintf("Failed to add depends_on field to pl_flows (HTTP %d): %s",
                 httr2::resp_status(patch_resp), raw))
  }

  invisible(httr2::resp_body_json(patch_resp))
}

.pl_create_logs_collection <- function(conn) {
  flows_resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections") |>
    httr2::req_url_query(perPage = 200) |>
    httr2::req_perform()
  collections <- httr2::resp_body_json(flows_resp)$items
  flows_col <- Filter(function(c) c$name == "pl_flows", collections)
  if (length(flows_col) == 0) stop("pl_flows collection must be created before pl_logs.")
  flows_col_id <- flows_col[[1]]$id

  body <- list(
    name = "pl_logs",
    type = "base",
    fields = list(
      list(
        name          = "flow",
        type          = "relation",
        required      = TRUE,
        maxSelect     = 1,
        collectionId  = flows_col_id,
        cascadeDelete = FALSE
      ),
      list(name = "status",   type = "text",     required = TRUE),
      list(name = "message",  type = "text",     required = FALSE),
      list(name = "metadata", type = "json",     required = FALSE),
      list(name = "created",  type = "autodate", onCreate = TRUE, onUpdate = FALSE)
    ),
    listRule   = "@request.auth.id != \"\"",
    viewRule   = "@request.auth.id != \"\"",
    createRule = "@request.auth.id != \"\"",
    updateRule = NULL,
    deleteRule = NULL
  )

  resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections") |>
    httr2::req_body_json(body) |>
    httr2::req_method("POST") |>
    httr2::req_error(is_error = function(resp) FALSE) |>
    httr2::req_perform()

  if (!httr2::resp_status(resp) %in% c(200, 201)) {
    body_err <- tryCatch(httr2::resp_body_string(resp), error = function(e) "(unreadable)")
    stop(sprintf("Failed to create pl_logs collection (HTTP %d): %s",
                 httr2::resp_status(resp), body_err))
  }

  invisible(httr2::resp_body_json(resp))
}
