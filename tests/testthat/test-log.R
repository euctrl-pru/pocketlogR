test_that("pl_log validates status values", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_log(conn, "myflow", "INVALID"), "'status' must be one of")
  expect_error(pl_log(conn, "myflow", "success"), "'status' must be one of")
  expect_error(pl_log(conn, "myflow", ""), "'status' must be one of")
})

test_that("pl_log validates flow argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_log(conn, "", "SUCCESS"), "'flow' must be")
  expect_error(pl_log(conn, 123, "SUCCESS"), "'flow' must be")
  expect_error(pl_log(conn, c("a", "b"), "SUCCESS"), "'flow' must be")
})

test_that("pl_log validates conn", {
  expect_error(pl_log("not-a-conn", "myflow", "SUCCESS"), "must be a connection list")
})

test_that("pl_log warns and returns NULL after exhausting retries", {
  conn <- list(url = "https://x.io", token = "tok")
  call_count <- 0L

  mock_resolve <- function(conn, flow_name) {
    call_count <<- call_count + 1L
    stop("simulated HTTP error")
  }

  with_mocked_bindings(
    pl_resolve_flow_id = mock_resolve,
    {
      expect_warning(
        result <- pl_log(conn, "myflow", "SUCCESS"),
        "failed to log event"
      )
      expect_null(result)
      expect_equal(call_count, 3L)
    }
  )
})

test_that("pl_retry respects times parameter", {
  count <- 0L
  result <- pl_retry({
    count <<- count + 1L
    stop("always fails")
  }, times = 3, wait = 0)

  expect_equal(count, 3L)
  expect_s3_class(result, "error")
})

test_that("pl_retry returns value on success", {
  result <- pl_retry({ 42 }, times = 3, wait = 0)
  expect_equal(result, 42)
})

test_that("pl_retry stops early on success", {
  count <- 0L
  result <- pl_retry({
    count <<- count + 1L
    if (count < 2) stop("not yet")
    "done"
  }, times = 3, wait = 0)

  expect_equal(count, 2L)
  expect_equal(result, "done")
})

test_that("pl_success calls pl_log with SUCCESS", {
  conn <- list(url = "https://x.io", token = "tok")
  captured_status <- NULL

  with_mocked_bindings(
    pl_log = function(conn, flow, status, message = NULL, metadata = NULL) {
      captured_status <<- status
      invisible(NULL)
    },
    {
      pl_success(conn, "myflow")
      expect_equal(captured_status, "SUCCESS")
    }
  )
})

test_that("pl_error calls pl_log with ERROR", {
  conn <- list(url = "https://x.io", token = "tok")
  captured_status <- NULL

  with_mocked_bindings(
    pl_log = function(conn, flow, status, message = NULL, metadata = NULL) {
      captured_status <<- status
      invisible(NULL)
    },
    {
      pl_error(conn, "myflow")
      expect_equal(captured_status, "ERROR")
    }
  )
})

test_that("pl_fatal calls pl_log with FATAL", {
  conn <- list(url = "https://x.io", token = "tok")
  captured_status <- NULL

  with_mocked_bindings(
    pl_log = function(conn, flow, status, message = NULL, metadata = NULL) {
      captured_status <<- status
      invisible(NULL)
    },
    {
      pl_fatal(conn, "myflow")
      expect_equal(captured_status, "FATAL")
    }
  )
})
