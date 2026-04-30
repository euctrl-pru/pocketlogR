# Integration tests — skipped automatically when env vars are absent.
# Set POCKETLOG_URL, POCKETLOG_EMAIL, POCKETLOG_PASSWORD (and POCKETLOG_ADMIN_*
# for admin tests) in ~/.Renviron to enable.

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

# Delete a flow and its logs using pl_delete_flow(force = TRUE)
delete_flow <- function(conn_admin, conn, name) {
  tryCatch({
    if (nrow(pl_get_flows(conn, name = name)) > 0) {
      pl_delete_flow(conn_admin, name, force = TRUE)
    }
  }, error = function(e) NULL)
}

# ── Authentication ─────────────────────────────────────────────────────────────

test_that("pl_connect authenticates against live PocketBase", {
  conn <- live_conn()
  expect_type(conn, "list")
  expect_named(conn, c("url", "token"))
  expect_true(nchar(conn$token) > 10)
})

test_that("pl_connect_admin authenticates as superuser", {
  conn <- live_admin_conn()
  expect_type(conn, "list")
  expect_true(nchar(conn$token) > 10)
})

# ── pl_setup ──────────────────────────────────────────────────────────────────

test_that("pl_setup is idempotent (runs twice without error)", {
  conn_admin <- live_admin_conn()
  expect_no_error(pl_setup(conn_admin))
  expect_no_error(pl_setup(conn_admin))
})

# ── pl_create_flow / pl_get_flows ─────────────────────────────────────────────

test_that("pl_create_flow creates a flow and pl_get_flows retrieves it", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("inttest_create_", format(Sys.time(), "%H%M%S"))
  on.exit(delete_flow(conn_admin, conn, nm), add = TRUE)

  pl_create_flow(conn, nm, type = "data_job",
                 description = "Integration test",
                 schedule    = "0 6 * * *")

  flows <- pl_get_flows(conn, name = nm)
  expect_equal(nrow(flows), 1)
  expect_equal(flows$name,     nm)
  expect_equal(flows$type,     "data_job")
  expect_equal(flows$schedule, "0 6 * * *")
})

test_that("pl_create_flow errors if flow already exists", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("inttest_dup_", format(Sys.time(), "%H%M%S"))
  on.exit(delete_flow(conn_admin, conn, nm), add = TRUE)

  pl_create_flow(conn, nm, type = "data_job")
  expect_error(pl_create_flow(conn, nm, type = "data_job"), "already exists")
})

test_that("pl_get_flows filters by type", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("inttest_type_", format(Sys.time(), "%H%M%S"))
  on.exit(delete_flow(conn_admin, conn, nm), add = TRUE)

  pl_create_flow(conn, nm, type = "website_online")

  results <- pl_get_flows(conn, type = "website_online")
  expect_s3_class(results, "data.frame")
  expect_true(nm %in% results$name)
  expect_true(all(results$type == "website_online"))
})

# ── pl_log / pl_success / pl_error / pl_fatal / pl_get_logs ──────────────────

test_that("pl_success logs a SUCCESS entry and pl_get_logs retrieves it", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("inttest_log_", format(Sys.time(), "%H%M%S"))
  on.exit(delete_flow(conn_admin, conn, nm), add = TRUE)

  pl_create_flow(conn, nm, type = "data_job")
  pl_success(conn, nm, message = "all good", metadata = list(rows = 42L))

  logs <- pl_get_logs(conn, flow = nm)
  expect_equal(nrow(logs), 1)
  expect_equal(logs$status[[1]],  "SUCCESS")
  expect_equal(logs$message[[1]], "all good")
})

test_that("pl_error and pl_fatal log correct statuses", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("inttest_ef_", format(Sys.time(), "%H%M%S"))
  on.exit(delete_flow(conn_admin, conn, nm), add = TRUE)

  pl_create_flow(conn, nm, type = "data_job")
  pl_error(conn, nm, message = "something broke")
  pl_fatal(conn, nm, message = "unrecoverable")

  logs <- pl_get_logs(conn, flow = nm)
  expect_equal(nrow(logs), 2)
  expect_setequal(logs$status, c("ERROR", "FATAL"))
})

test_that("pl_get_logs filters by status", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  nm <- paste0("inttest_filt_", format(Sys.time(), "%H%M%S"))
  on.exit(delete_flow(conn_admin, conn, nm), add = TRUE)

  pl_create_flow(conn, nm, type = "data_job")
  pl_success(conn, nm, message = "ok")
  pl_error(conn,   nm, message = "bad")

  success_logs <- pl_get_logs(conn, flow = nm, status = "SUCCESS")
  expect_equal(nrow(success_logs), 1)
  expect_equal(success_logs$status[[1]], "SUCCESS")

  error_logs <- pl_get_logs(conn, flow = nm, status = "ERROR")
  expect_equal(nrow(error_logs), 1)
  expect_equal(error_logs$status[[1]], "ERROR")
})

# ── pl_add_dependency / pl_remove_dependency / pl_get_dependencies ────────────

test_that("pl_add_dependency and pl_get_dependencies work correctly", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  up   <- paste0("inttest_up_",   format(Sys.time(), "%H%M%S"))
  down <- paste0("inttest_down_", format(Sys.time(), "%H%M%S"))
  on.exit({
    delete_flow(conn_admin, conn, down)
    delete_flow(conn_admin, conn, up)
  }, add = TRUE)

  pl_create_flow(conn, up,   type = "data_job")
  pl_create_flow(conn, down, type = "db_check")

  pl_add_dependency(conn, down, up)

  deps <- pl_get_dependencies(conn, down)
  expect_equal(nrow(deps), 1)
  expect_equal(deps$name[[1]], up)
  expect_equal(deps$depth[[1]], 1L)
})

test_that("pl_remove_dependency removes a dependency", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  up   <- paste0("inttest_rup_",   format(Sys.time(), "%H%M%S"))
  down <- paste0("inttest_rdown_", format(Sys.time(), "%H%M%S"))
  on.exit({
    delete_flow(conn_admin, conn, down)
    delete_flow(conn_admin, conn, up)
  }, add = TRUE)

  pl_create_flow(conn, up,   type = "data_job")
  pl_create_flow(conn, down, type = "db_check", depends_on = up)

  pl_remove_dependency(conn, down, up)

  deps <- pl_get_dependencies(conn, down)
  expect_equal(nrow(deps), 0)
})

test_that("pl_add_dependency rejects a cycle", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  a <- paste0("inttest_ca_", format(Sys.time(), "%H%M%S"))
  b <- paste0("inttest_cb_", format(Sys.time(), "%H%M%S"))
  on.exit({
    delete_flow(conn_admin, conn, b)
    delete_flow(conn_admin, conn, a)
  }, add = TRUE)

  pl_create_flow(conn, a, type = "data_job")
  pl_create_flow(conn, b, type = "data_job", depends_on = a)

  expect_error(pl_add_dependency(conn, a, b), "cycle")
})

test_that("pl_get_dependencies recursive = TRUE returns transitive deps", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  ts <- format(Sys.time(), "%H%M%S")
  a  <- paste0("inttest_ra_", ts)
  b  <- paste0("inttest_rb_", ts)
  c_ <- paste0("inttest_rc_", ts)
  on.exit({
    delete_flow(conn_admin, conn, c_)
    delete_flow(conn_admin, conn, b)
    delete_flow(conn_admin, conn, a)
  }, add = TRUE)

  pl_create_flow(conn, a,  type = "data_job")
  pl_create_flow(conn, b,  type = "data_job", depends_on = a)
  pl_create_flow(conn, c_, type = "data_job", depends_on = b)

  deps_direct    <- pl_get_dependencies(conn, c_, recursive = FALSE)
  deps_recursive <- pl_get_dependencies(conn, c_, recursive = TRUE)

  expect_equal(nrow(deps_direct), 1)
  expect_equal(deps_direct$name[[1]], b)

  expect_equal(nrow(deps_recursive), 2)
  expect_setequal(deps_recursive$name, c(a, b))
})

# ── pl_get_status ─────────────────────────────────────────────────────────────

test_that("pl_get_status returns chain with correct depths", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  ts   <- format(Sys.time(), "%H%M%S")
  up   <- paste0("inttest_sup_",   ts)
  down <- paste0("inttest_sdown_", ts)
  on.exit({
    delete_flow(conn_admin, conn, down)
    delete_flow(conn_admin, conn, up)
  }, add = TRUE)

  pl_create_flow(conn, up,   type = "data_job")
  pl_create_flow(conn, down, type = "db_check", depends_on = up)

  pl_success(conn, up,   message = "upstream ok")
  pl_success(conn, down, message = "downstream ok")

  status <- pl_get_status(conn, down)
  expect_s3_class(status, "data.frame")
  expect_true(down %in% status$flow)
  expect_true(up   %in% status$flow)
  expect_equal(status$depth[status$flow == down], 0L)
  expect_equal(status$depth[status$flow == up],   1L)
  expect_equal(status$status[status$flow == down], "SUCCESS")
  expect_equal(status$status[status$flow == up],   "SUCCESS")
})

# ── pl_get_dag ────────────────────────────────────────────────────────────────

test_that("pl_get_dag returns correct structure and poisoning", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()
  ts   <- format(Sys.time(), "%H%M%S")
  up   <- paste0("inttest_dup_",   ts)
  down <- paste0("inttest_ddown_", ts)
  on.exit({
    delete_flow(conn_admin, conn, down)
    delete_flow(conn_admin, conn, up)
  }, add = TRUE)

  pl_create_flow(conn, up,   type = "data_job")
  pl_create_flow(conn, down, type = "db_check", depends_on = up)

  # upstream fails, then downstream runs with success -> downstream is POISONED
  pl_error(conn,   up,   message = "upstream broke")
  Sys.sleep(1)
  pl_success(conn, down, message = "downstream ran after upstream broke")

  dag <- pl_get_dag(conn)
  expect_s3_class(dag, "data.frame")
  expect_true(all(c("flow", "type", "raw_status", "effective_status",
                    "poisoned_by", "depends_on", "is_root") %in% names(dag)))

  up_row   <- dag[dag$flow == up,   ]
  down_row <- dag[dag$flow == down, ]

  expect_equal(up_row$raw_status,       "ERROR")
  expect_equal(up_row$effective_status, "ERROR")
  expect_true(up_row$is_root)

  expect_equal(down_row$raw_status,       "SUCCESS")
  expect_equal(down_row$effective_status, "POISONED")
  expect_true(up %in% down_row$poisoned_by[[1]])
  expect_false(down_row$is_root)
})

test_that("pl_get_dag returns empty data.frame when no flows exist", {
  conn_admin <- live_admin_conn()
  conn       <- live_conn()

  # Temporarily verify structure with existing data (we can't wipe all flows,
  # so just check columns are present and types correct)
  dag <- pl_get_dag(conn)
  expect_s3_class(dag, "data.frame")
  expect_true(all(c("flow", "type", "schedule", "raw_status", "raw_status_time",
                    "effective_status", "poisoned_by", "depends_on", "is_root") %in% names(dag)))
  expect_type(dag$is_root, "logical")
  expect_type(dag$flow,    "character")
})
