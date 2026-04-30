# Connect to PocketBase as a regular user

Authenticates against a PocketBase `users` auth collection and returns a
connection object for use with all daily pocketlogR functions.

## Usage

``` r
pl_connect(url = NULL, email = NULL, password = NULL)
```

## Arguments

- url:

  PocketBase instance URL. Defaults to `POCKETLOG_URL` env var.

- email:

  Service account email. Defaults to `POCKETLOG_EMAIL` env var.

- password:

  Service account password. Defaults to `POCKETLOG_PASSWORD` env var.

## Value

A named list with elements `url` (character) and `token` (character
JWT).

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- pl_connect()
conn <- pl_connect(
  url      = "https://myapp.pockethost.io",
  email    = "service@example.com",
  password = "secret"
)
} # }
```
