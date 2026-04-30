test_that("pl_connect errors on missing URL", {
  withr::with_envvar(
    c(POCKETLOG_URL = "", POCKETLOG_EMAIL = "a@b.com", POCKETLOG_PASSWORD = "pw"),
    expect_error(pl_connect(), "URL is required")
  )
})

test_that("pl_connect errors on missing email", {
  withr::with_envvar(
    c(POCKETLOG_URL = "https://x.pockethost.io", POCKETLOG_EMAIL = "", POCKETLOG_PASSWORD = "pw"),
    expect_error(pl_connect(), "Email is required")
  )
})

test_that("pl_connect errors on missing password", {
  withr::with_envvar(
    c(POCKETLOG_URL = "https://x.pockethost.io", POCKETLOG_EMAIL = "a@b.com", POCKETLOG_PASSWORD = ""),
    expect_error(pl_connect(), "Password is required")
  )
})

test_that("pl_connect_admin errors on missing admin email", {
  withr::with_envvar(
    c(POCKETLOG_URL = "https://x.pockethost.io", POCKETLOG_ADMIN_EMAIL = "", POCKETLOG_ADMIN_PASSWORD = "pw"),
    expect_error(pl_connect_admin(), "Admin email is required")
  )
})

test_that("pl_connect_admin errors on missing admin password", {
  withr::with_envvar(
    c(POCKETLOG_URL = "https://x.pockethost.io", POCKETLOG_ADMIN_EMAIL = "admin@b.com", POCKETLOG_ADMIN_PASSWORD = ""),
    expect_error(pl_connect_admin(), "Admin password is required")
  )
})

test_that("pl_validate_conn rejects non-list", {
  expect_error(pl_validate_conn("not-a-list"), "must be a connection list")
})

test_that("pl_validate_conn rejects list without url", {
  expect_error(pl_validate_conn(list(token = "abc")), "must be a connection list")
})

test_that("pl_validate_conn rejects list without token", {
  expect_error(pl_validate_conn(list(url = "https://x.io")), "must be a connection list")
})

test_that("pl_validate_conn accepts valid connection", {
  conn <- list(url = "https://x.io", token = "mytoken")
  expect_invisible(pl_validate_conn(conn))
})
