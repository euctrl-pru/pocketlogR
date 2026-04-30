test_that("pl_log validates status values", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_log(conn, "myflow", "INVALID", log_type = "data_job"), "'status' must be one of")
  expect_error(pl_log(conn, "myflow", "success", log_type = "data_job"), "'status' must be one of")
  expect_error(pl_log(conn, "myflow", "",        log_type = "data_job"), "'status' must be one of")
})

test_that("pl_log validates flow argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_log(conn, "",        "SUCCESS", log_type = "data_job"), "'flow' must be")
  expect_error(pl_log(conn, 123,       "SUCCESS", log_type = "data_job"), "'flow' must be")
  expect_error(pl_log(conn, c("a","b"),"SUCCESS", log_type = "data_job"), "'flow' must be")
})

test_that("pl_log validates log_type argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_log(conn, "myflow", "SUCCESS", log_type = ""),        "'log_type' must be")
  expect_error(pl_log(conn, "myflow", "SUCCESS", log_type = 123),       "'log_type' must be")
  expect_error(pl_log(conn, "myflow", "SUCCESS", log_type = c("a","b")),"'log_type' must be")
})

test_that("pl_log validates conn", {
  expect_error(pl_log("not-a-conn", "myflow", "SUCCESS", log_type = "data_job"), "must be a connection list")
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
        result <- pl_log(conn, "myflow", "SUCCESS", log_type = "data_job"),
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
  captured <- list()

  with_mocked_bindings(
    pl_log = function(conn, flow, status, log_type, message = NULL, metadata = NULL) {
      captured$status   <<- status
      captured$log_type <<- log_type
      invisible(NULL)
    },
    {
      pl_success(conn, "myflow", log_type = "data_job")
      expect_equal(captured$status,   "SUCCESS")
      expect_equal(captured$log_type, "data_job")
    }
  )
})

test_that("pl_error calls pl_log with ERROR", {
  conn <- list(url = "https://x.io", token = "tok")
  captured <- list()

  with_mocked_bindings(
    pl_log = function(conn, flow, status, log_type, message = NULL, metadata = NULL) {
      captured$status   <<- status
      captured$log_type <<- log_type
      invisible(NULL)
    },
    {
      pl_error(conn, "myflow", log_type = "website_online")
      expect_equal(captured$status,   "ERROR")
      expect_equal(captured$log_type, "website_online")
    }
  )
})

test_that("pl_fatal calls pl_log with FATAL", {
  conn <- list(url = "https://x.io", token = "tok")
  captured <- list()

  with_mocked_bindings(
    pl_log = function(conn, flow, status, log_type, message = NULL, metadata = NULL) {
      captured$status   <<- status
      captured$log_type <<- log_type
      invisible(NULL)
    },
    {
      pl_fatal(conn, "myflow", log_type = "data_job")
      expect_equal(captured$status,   "FATAL")
      expect_equal(captured$log_type, "data_job")
    }
  )
})

test_that("pl_log_types is a character vector with expected values", {
  expect_type(pl_log_types, "character")
  expect_true("data_job"       %in% pl_log_types)
  expect_true("website_online" %in% pl_log_types)
  expect_true("website_status" %in% pl_log_types)
  expect_true("email_check"    %in% pl_log_types)
  expect_true("db_check"       %in% pl_log_types)
})
