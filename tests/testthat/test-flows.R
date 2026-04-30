test_that("pl_flow_types is a character vector with expected values", {
  expect_type(pl_flow_types, "character")
  expect_true("data_job" %in% pl_flow_types)
  expect_true("website_status" %in% pl_flow_types)
  expect_true("email_check" %in% pl_flow_types)
  expect_true("db_check" %in% pl_flow_types)
  expect_true("website_online" %in% pl_flow_types)
})

test_that("pl_create_flow validates name argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_create_flow(conn, name = 123,       type = "data_job", owner = "x"), "'name' must be")
  expect_error(pl_create_flow(conn, name = "",        type = "data_job", owner = "x"), "'name' must be")
  expect_error(pl_create_flow(conn, name = c("a","b"),type = "data_job", owner = "x"), "'name' must be")
})

test_that("pl_create_flow validates type argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_create_flow(conn, name = "myflow", type = "", owner = "x"), "'type' must be")
  expect_error(pl_create_flow(conn, name = "myflow", type = 42,  owner = "x"), "'type' must be")
})

test_that("pl_create_flow validates owner argument", {
  conn <- list(url = "https://x.io", token = "tok")
  expect_error(pl_create_flow(conn, name = "myflow", type = "data_job", owner = ""),  "'owner' must be")
  expect_error(pl_create_flow(conn, name = "myflow", type = "data_job", owner = 123), "'owner' must be")
  expect_error(pl_create_flow(conn, name = "myflow", type = "data_job", owner = c("a", "b")), "'owner' must be")
})

test_that("pl_get_flows returns empty data.frame with correct columns when no results", {
  conn <- list(url = "https://x.io", token = "tok")
  mock_resp <- list(items = list(), totalPages = 1)

  result <- with_mocked_bindings(
    req_perform = function(req) {
      structure(
        list(status_code = 200L, body = chartr("'", '"', jsonlite::toJSON(mock_resp, auto_unbox = TRUE))),
        class = "httr2_response"
      )
    },
    resp_body_json = function(resp) mock_resp,
    .package = "httr2",
    pl_get_flows(conn)
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_true(all(c("id", "name", "type", "description", "schedule", "depends_on") %in% names(result)))
})
