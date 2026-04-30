test_that("pl_delete_flow validates conn", {
  expect_error(pl_delete_flow("not-a-conn", "myflow"), "must be a connection list")
})

test_that("pl_delete_flow validates flow argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_delete_flow(conn, ""),    "'flow' must be")
  expect_error(pl_delete_flow(conn, 123),   "'flow' must be")
  expect_error(pl_delete_flow(conn, c("a", "b")), "'flow' must be")
})

test_that("pl_delete_logs validates conn", {
  expect_error(pl_delete_logs("not-a-conn"), "must be a connection list")
})

test_that("pl_delete_logs validates status argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_delete_logs(conn, status = "INVALID"), "'status' must be one of")
})

# ── Integration ───────────────────────────────────────────────────────────────

live_conn <- function() {
  url   <- Sys.getenv("POCKETLOG_URL",      unset = "")
  email <- Sys.getenv("POCKETLOG_EMAIL",    unset = "")
  pass  <- Sys.getenv("POCKETLOG_PASSWORD", unset = "")
  if (nchar(url) == 0 || nchar(email) == 0 || nchar(pass) == 0) {
    skip("Set POCKETLOG_URL, POCKETLOG_EMAIL, POCKETLOG_PASSWORD to run live tests")
  }
  pl_connect(url = url, email = email, password = pass)
}

live_admin_conn <- function() {
  url   <- Sys.getenv("POCKETLOG_URL",            unset = "")
  email <- Sys.getenv("POCKETLOG_ADMIN_EMAIL",    unset = "")
  pass  <- Sys.getenv("POCKETLOG_ADMIN_PASSWORD", unset = "")
  if (nchar(url) == 0 || nchar(email) == 0 || nchar(pass) == 0) {
    skip("Set POCKETLOG_URL, POCKETLOG_ADMIN_EMAIL, POCKETLOG_ADMIN_PASSWORD to run admin tests")
  }
  pl_connect_admin(url = url, email = email, password = pass)
}

test_that("pl_delete_flow errors on unknown flow", {
  conn_admin <- live_admin_conn()
  expect_error(pl_delete_flow(conn_admin, "nonexistent_flow_xyz"), "not found")
})

test_that("pl_delete_flow removes a flow with no logs", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("admin_del_", format(Sys.time(), "%H%M%S"))

  pl_create_flow(conn, nm, type = "data_job", owner = "test-owner")
  expect_equal(nrow(pl_get_flows(conn, name = nm)), 1)

  pl_delete_flow(conn_admin, nm)
  expect_equal(nrow(pl_get_flows(conn, name = nm)), 0)
})

test_that("pl_delete_flow errors when logs exist and force = FALSE", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("admin_noforce_", format(Sys.time(), "%H%M%S"))
  on.exit(pl_delete_flow(conn_admin, nm, force = TRUE), add = TRUE)

  pl_create_flow(conn, nm, type = "data_job", owner = "test-owner")
  pl_success(conn, nm, log_type = "data_job", message = "test log")

  expect_error(pl_delete_flow(conn_admin, nm, force = FALSE), "log entries")
})

test_that("pl_delete_flow with force = TRUE removes logs then flow", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("admin_force_", format(Sys.time(), "%H%M%S"))

  pl_create_flow(conn, nm, type = "data_job", owner = "test-owner")
  pl_success(conn, nm, log_type = "data_job", message = "will be deleted")
  pl_error(conn,   nm, log_type = "data_job", message = "this too")

  pl_delete_flow(conn_admin, nm, force = TRUE)

  expect_equal(nrow(pl_get_flows(conn, name = nm)), 0)
  expect_equal(nrow(pl_get_logs(conn, flow = nm)), 0)
})

test_that("pl_delete_logs removes logs matching flow filter", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("admin_dlog_", format(Sys.time(), "%H%M%S"))
  on.exit(pl_delete_flow(conn_admin, nm, force = TRUE), add = TRUE)

  pl_create_flow(conn, nm, type = "data_job", owner = "test-owner")
  pl_success(conn, nm, log_type = "data_job", message = "a")
  pl_error(conn,   nm, log_type = "data_job", message = "b")

  expect_equal(nrow(pl_get_logs(conn, flow = nm)), 2)

  n <- pl_delete_logs(conn_admin, flow = nm)
  expect_equal(n, 2L)
  expect_equal(nrow(pl_get_logs(conn, flow = nm)), 0)
})

test_that("pl_delete_logs respects status filter", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("admin_dstat_", format(Sys.time(), "%H%M%S"))
  on.exit(pl_delete_flow(conn_admin, nm, force = TRUE), add = TRUE)

  pl_create_flow(conn, nm, type = "data_job", owner = "test-owner")
  pl_success(conn, nm, log_type = "data_job", message = "keep me")
  pl_error(conn,   nm, log_type = "data_job", message = "delete me")

  n <- pl_delete_logs(conn_admin, flow = nm, status = "ERROR")
  expect_equal(n, 1L)

  remaining <- pl_get_logs(conn, flow = nm)
  expect_equal(nrow(remaining), 1)
  expect_equal(remaining$status[[1]], "SUCCESS")
})

test_that("pl_delete_logs respects before filter", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("admin_dbef_", format(Sys.time(), "%H%M%S"))
  on.exit(pl_delete_flow(conn_admin, nm, force = TRUE), add = TRUE)

  pl_create_flow(conn, nm, type = "data_job", owner = "test-owner")
  pl_success(conn, nm, log_type = "data_job", message = "old log")

  # A 'before' in the future should delete the log; in the past should not
  n_future <- pl_delete_logs(conn_admin, flow = nm, before = Sys.time() + 3600)
  expect_equal(n_future, 1L)
  expect_equal(nrow(pl_get_logs(conn, flow = nm)), 0)
})

test_that("pl_delete_logs returns 0 when nothing matches", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("admin_dnone_", format(Sys.time(), "%H%M%S"))
  on.exit(pl_delete_flow(conn_admin, nm, force = TRUE), add = TRUE)

  pl_create_flow(conn, nm, type = "data_job", owner = "test-owner")
  # no logs created

  n <- pl_delete_logs(conn_admin, flow = nm)
  expect_equal(n, 0L)
})
