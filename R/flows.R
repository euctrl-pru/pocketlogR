#' Create a new flow
#'
#' Registers a new flow in PocketBase. Errors if a flow with the same name
#' already exists. Validates that `depends_on` flows exist and that adding
#' them would not create a cycle in the DAG.
#'
#' @param conn A connection object from [pl_connect()].
#' @param name Unique flow identifier (e.g. `"ectrl_data_load"`).
#' @param type Flow type string. See [pl_flow_types] for defaults, but any string is accepted.
#' @param description Optional human-readable description.
#' @param schedule Optional cron expression or human-readable schedule string.
#' @param owner Free-text owner or responsible party (e.g. `"quinten"`, `"team-data"`).
#' @param depends_on Optional character vector of upstream flow names.
#'
#' @return Invisibly returns the created flow record as a list.
#'
#' @examples
#' \dontrun{
#' conn <- pl_connect()
#' pl_create_flow(conn, "ectrl_data_load", type = "data_job", owner = "quinten",
#'                description = "Daily EUROCONTROL data import",
#'                schedule = "0 6 * * *")
#' }
#' @export
pl_create_flow <- function(conn, name, type, owner, description = NULL, schedule = NULL, depends_on = NULL) {
  pl_validate_conn(conn)

  if (!is.character(name) || length(name) != 1 || nchar(name) == 0)
    stop("'name' must be a non-empty character string.")
  if (!is.character(type) || length(type) != 1 || nchar(type) == 0)
    stop("'type' must be a non-empty character string.")
  if (!is.character(owner) || length(owner) != 1 || nchar(owner) == 0)
    stop("'owner' must be a non-empty character string.")

  existing <- pl_get_flows(conn, name = name)
  if (nrow(existing) > 0)
    stop(sprintf("A flow named '%s' already exists.", name))

  dep_ids <- character(0)
  if (!is.null(depends_on) && length(depends_on) > 0) {
    all_flows_raw <- pl_get_all_flows_raw(conn)

    if (pl_detect_cycle(name, depends_on, all_flows_raw)) {
      stop(sprintf(
        "Adding dependency would create a cycle involving flow '%s'.", name
      ))
    }
    dep_ids <- pl_resolve_flow_ids(conn, depends_on)
  }

  body <- list(
    name        = name,
    type        = type,
    description = description,
    schedule    = schedule,
    owner       = owner,
    depends_on  = as.list(unname(dep_ids))
  )
  body <- Filter(Negate(is.null), body)

  resp <- pl_base_req(conn) |>
    httr2::req_url_path_append("api", "collections", "pl_flows", "records") |>
    httr2::req_body_json(body) |>
    httr2::req_method("POST") |>
    httr2::req_perform()

  cli::cli_alert_success("Flow {.val {name}} created.")
  invisible(httr2::resp_body_json(resp))
}

#' List flows
#'
#' Returns a data.frame of flows, optionally filtered by type or name.
#'
#' @param conn A connection object from [pl_connect()].
#' @param type Optional flow type to filter by.
#' @param name Optional flow name to filter by.
#'
#' @return A data.frame with columns: `id`, `name`, `type`, `description`,
#'   `schedule`, `owner`, `depends_on` (list-column of upstream flow names), `created`, `updated`.
#'
#' @examples
#' \dontrun{
#' conn <- pl_connect()
#' pl_get_flows(conn)
#' pl_get_flows(conn, type = "data_job")
#' pl_get_flows(conn, name = "ectrl_data_load")
#' }
#' @export
pl_get_flows <- function(conn, type = NULL, name = NULL) {
  pl_validate_conn(conn)

  filter_parts <- c(
    if (!is.null(type)) sprintf('type = "%s"', type),
    if (!is.null(name)) sprintf('name = "%s"', name)
  )
  filter <- if (length(filter_parts) > 0) paste(filter_parts, collapse = " && ") else NULL

  all_items <- list()
  page <- 1
  repeat {
    req <- pl_base_req(conn) |>
      httr2::req_url_path_append("api", "collections", "pl_flows", "records") |>
      httr2::req_url_query(perPage = 200, page = page)

    if (!is.null(filter)) req <- httr2::req_url_query(req, filter = filter)

    resp <- httr2::req_perform(req)
    body <- httr2::resp_body_json(resp)
    all_items <- c(all_items, body$items)
    if (page >= body$totalPages) break
    page <- page + 1
  }

  if (length(all_items) == 0) {
    return(data.frame(
      id = character(0), name = character(0), type = character(0),
      description = character(0), schedule = character(0), owner = character(0),
      depends_on = I(list()), created = character(0), updated = character(0),
      stringsAsFactors = FALSE
    ))
  }

  id_map <- pl_build_flow_name_map(all_items)

  rows <- lapply(all_items, function(item) {
    dep_ids   <- pl_norm_dep_ids(item$depends_on)
    dep_names <- if (length(dep_ids) > 0) {
      vapply(dep_ids, function(id) pl_map_get(id_map, id) %||% id, character(1))
    } else {
      character(0)
    }
    list(
      id          = item$id %||% NA_character_,
      name        = item$name %||% NA_character_,
      type        = item$type %||% NA_character_,
      description = item$description %||% NA_character_,
      schedule    = item$schedule %||% NA_character_,
      owner       = item$owner %||% NA_character_,
      depends_on  = list(dep_names),
      created     = item$created %||% NA_character_,
      updated     = item$updated %||% NA_character_
    )
  })

  data.frame(
    id          = vapply(rows, `[[`, character(1), "id"),
    name        = vapply(rows, `[[`, character(1), "name"),
    type        = vapply(rows, `[[`, character(1), "type"),
    description = vapply(rows, `[[`, character(1), "description"),
    schedule    = vapply(rows, `[[`, character(1), "schedule"),
    owner       = vapply(rows, `[[`, character(1), "owner"),
    depends_on  = I(lapply(rows, function(r) r$depends_on[[1]])),
    created     = vapply(rows, `[[`, character(1), "created"),
    updated     = vapply(rows, `[[`, character(1), "updated"),
    stringsAsFactors = FALSE
  )
}
