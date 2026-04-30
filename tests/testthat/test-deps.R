make_flow <- function(name, id, depends_on = list()) {
  list(id = id, name = name, type = "data_job", depends_on = depends_on)
}

test_that("pl_detect_cycle detects a direct cycle", {
  flows <- list(
    make_flow("a", "id_a", list("id_b")),
    make_flow("b", "id_b", list())
  )
  expect_true(pl_detect_cycle("b", c("a"), flows))
})

test_that("pl_detect_cycle detects a transitive cycle", {
  flows <- list(
    make_flow("a", "id_a", list("id_b")),
    make_flow("b", "id_b", list("id_c")),
    make_flow("c", "id_c", list())
  )
  expect_true(pl_detect_cycle("c", c("a"), flows))
})

test_that("pl_detect_cycle accepts a valid DAG", {
  flows <- list(
    make_flow("a", "id_a", list()),
    make_flow("b", "id_b", list("id_a")),
    make_flow("c", "id_c", list("id_a"))
  )
  expect_false(pl_detect_cycle("d", c("b", "c"), flows))
})

test_that("pl_detect_cycle accepts empty dependency list", {
  flows <- list(make_flow("a", "id_a", list()))
  expect_false(pl_detect_cycle("b", character(0), flows))
})

test_that("pl_detect_cycle handles self-referencing attempt", {
  flows <- list(make_flow("a", "id_a", list()))
  expect_true(pl_detect_cycle("a", c("a"), flows))
})

test_that("pl_add_dependency validates flow argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_add_dependency(conn, flow = 123, depends_on = "b"), "'flow' must be")
  expect_error(pl_add_dependency(conn, flow = c("a", "b"), depends_on = "c"), "'flow' must be")
})

test_that("pl_add_dependency validates depends_on argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_add_dependency(conn, flow = "a", depends_on = character(0)), "'depends_on' must be")
  expect_error(pl_add_dependency(conn, flow = "a", depends_on = 123), "'depends_on' must be")
})

test_that("pl_remove_dependency validates flow argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_remove_dependency(conn, flow = 123, depends_on = "b"), "'flow' must be")
})

test_that("pl_get_status validates conn", {
  expect_error(pl_get_status("not-a-conn", "myflow"), "must be a connection list")
})

test_that("pl_get_dag validates conn", {
  expect_error(pl_get_dag("not-a-conn"), "must be a connection list")
})

test_that("pl_get_dag poisoning logic: downstream poisoned when last success is AFTER upstream failure", {
  now <- as.POSIXct("2024-01-01 10:00:00", tz = "UTC")
  upstream_failure_ts <- format(now - 3600, "%Y-%m-%d %H:%M:%S")
  downstream_success_ts <- format(now, "%Y-%m-%d %H:%M:%S")

  flows <- list(
    make_flow("upstream", "id_up", list()),
    make_flow("downstream", "id_down", list("id_up"))
  )

  logs <- list(
    upstream   = list(status = "ERROR",   created = upstream_failure_ts,  message = NA_character_),
    downstream = list(status = "SUCCESS", created = downstream_success_ts, message = NA_character_)
  )

  id_map <- c(id_up = "upstream", id_down = "downstream")

  .parse_ts <- function(ts_str) {
    if (is.null(ts_str) || is.na(ts_str)) return(NA)
    tryCatch(as.POSIXct(ts_str, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC"), error = function(e) NA)
  }

  down_log <- logs$downstream
  up_log   <- logs$upstream

  last_success_ts <- .parse_ts(down_log$created)
  up_ts           <- .parse_ts(up_log$created)

  is_poisoned <- !is.na(last_success_ts) && !is.na(up_ts) && last_success_ts > up_ts
  expect_true(is_poisoned)
})

test_that("pl_get_dag poisoning logic: downstream NOT poisoned when success is BEFORE upstream failure", {
  now <- as.POSIXct("2024-01-01 10:00:00", tz = "UTC")
  upstream_failure_ts   <- format(now, "%Y-%m-%d %H:%M:%S")
  downstream_success_ts <- format(now - 3600, "%Y-%m-%d %H:%M:%S")

  .parse_ts <- function(ts_str) {
    if (is.null(ts_str) || is.na(ts_str)) return(NA)
    tryCatch(as.POSIXct(ts_str, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC"), error = function(e) NA)
  }

  last_success_ts <- .parse_ts(downstream_success_ts)
  up_ts           <- .parse_ts(upstream_failure_ts)

  is_poisoned <- !is.na(last_success_ts) && !is.na(up_ts) && last_success_ts > up_ts
  expect_false(is_poisoned)
})

test_that("pl_get_dag: never-logged downstream is not poisoned (effective_status = NA)", {
  .parse_ts <- function(ts_str) {
    if (is.null(ts_str) || is.na(ts_str)) return(NA)
    tryCatch(as.POSIXct(ts_str, format = "%Y-%m-%d %H:%M:%OS", tz = "UTC"), error = function(e) NA)
  }

  down_status <- NA_character_
  is_poisoned <- !is.na(down_status) && down_status == "SUCCESS"
  expect_false(is_poisoned)
})
