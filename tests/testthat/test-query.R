test_that("pl_get_logs validates status argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_get_logs(conn, status = "INVALID"), "'status' must be one of")
})

test_that("pl_get_logs validates conn", {
  expect_error(pl_get_logs("not-a-conn"), "must be a connection list")
})

test_that("pl_format_timestamp handles POSIXct", {
  ts <- as.POSIXct("2024-06-15 08:30:00", tz = "UTC")
  result <- pl_format_timestamp(ts)
  expect_type(result, "character")
  expect_match(result, "2024-06-15")
})

test_that("pl_format_timestamp handles ISO 8601 string", {
  result <- pl_format_timestamp("2024-06-15T08:30:00Z")
  expect_equal(result, "2024-06-15T08:30:00Z")
})

test_that("pl_format_timestamp returns NULL for NULL input", {
  expect_null(pl_format_timestamp(NULL))
})

test_that("pl_build_filter returns NULL for no parts", {
  result <- pl_build_filter(NULL, NULL)
  expect_null(result)
})

test_that("pl_build_filter combines parts with &&", {
  result <- pl_build_filter('status = "ERROR"', 'flow.name = "myflow"')
  expect_equal(result, 'status = "ERROR" && flow.name = "myflow"')
})

test_that("pl_build_filter skips NULL parts", {
  result <- pl_build_filter('status = "ERROR"', NULL)
  expect_equal(result, 'status = "ERROR"')
})

test_that("pl_get_logs returns empty data.frame with correct columns when no results", {
  conn <- list(url = "https://x.io", token = "tok")
  mock_resp <- list(items = list(), totalPages = 1)

  result <- with_mocked_bindings(
    req_perform = function(req) structure(list(), class = "httr2_response"),
    resp_body_json = function(resp) mock_resp,
    .package = "httr2",
    pl_get_logs(conn)
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_true(all(c("id", "flow", "status", "message", "metadata", "created") %in% names(result)))
})
