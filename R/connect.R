#' Connect to PocketBase as a regular user
#'
#' Authenticates against a PocketBase `users` auth collection and returns a
#' connection object for use with all daily pocketlogR functions.
#'
#' @param url PocketBase instance URL. Defaults to `POCKETLOG_URL` env var.
#' @param email Service account email. Defaults to `POCKETLOG_EMAIL` env var.
#' @param password Service account password. Defaults to `POCKETLOG_PASSWORD` env var.
#'
#' @return A named list with elements `url` (character) and `token` (character JWT).
#'
#' @examples
#' \dontrun{
#' conn <- pl_connect()
#' conn <- pl_connect(
#'   url      = "https://myapp.pockethost.io",
#'   email    = "service@example.com",
#'   password = "secret"
#' )
#' }
#' @export
pl_connect <- function(url = NULL, email = NULL, password = NULL) {
  url      <- url      %||% Sys.getenv("POCKETLOG_URL",      unset = NA)
  email    <- email    %||% Sys.getenv("POCKETLOG_EMAIL",    unset = NA)
  password <- password %||% Sys.getenv("POCKETLOG_PASSWORD", unset = NA)

  if (is.na(url) || nchar(url) == 0)
    stop("PocketBase URL is required. Set POCKETLOG_URL or pass 'url'.")
  if (is.na(email) || nchar(email) == 0)
    stop("Email is required. Set POCKETLOG_EMAIL or pass 'email'.")
  if (is.na(password) || nchar(password) == 0)
    stop("Password is required. Set POCKETLOG_PASSWORD or pass 'password'.")

  url <- sub("/$", "", url)
  token <- pl_auth(url, "users", email, password)
  cli::cli_alert_success("Connected to PocketBase at {.url {url}}")
  list(url = url, token = token)
}

#' Connect to PocketBase as a superuser (admin)
#'
#' Authenticates against the `_superusers` collection. Use this only for
#' [pl_setup()]. Regular operations should use [pl_connect()].
#'
#' @param url PocketBase instance URL. Defaults to `POCKETLOG_URL` env var.
#' @param email Superuser email. Defaults to `POCKETLOG_ADMIN_EMAIL` env var.
#' @param password Superuser password. Defaults to `POCKETLOG_ADMIN_PASSWORD` env var.
#'
#' @return A named list with elements `url` (character) and `token` (character JWT).
#'
#' @examples
#' \dontrun{
#' conn_admin <- pl_connect_admin()
#' }
#' @export
pl_connect_admin <- function(url = NULL, email = NULL, password = NULL) {
  url      <- url      %||% Sys.getenv("POCKETLOG_URL",            unset = NA)
  email    <- email    %||% Sys.getenv("POCKETLOG_ADMIN_EMAIL",    unset = NA)
  password <- password %||% Sys.getenv("POCKETLOG_ADMIN_PASSWORD", unset = NA)

  if (is.na(url) || nchar(url) == 0)
    stop("PocketBase URL is required. Set POCKETLOG_URL or pass 'url'.")
  if (is.na(email) || nchar(email) == 0)
    stop("Admin email is required. Set POCKETLOG_ADMIN_EMAIL or pass 'email'.")
  if (is.na(password) || nchar(password) == 0)
    stop("Admin password is required. Set POCKETLOG_ADMIN_PASSWORD or pass 'password'.")

  url <- sub("/$", "", url)
  token <- pl_auth(url, "_superusers", email, password)
  cli::cli_alert_success("Connected to PocketBase (superuser) at {.url {url}}")
  list(url = url, token = token)
}
