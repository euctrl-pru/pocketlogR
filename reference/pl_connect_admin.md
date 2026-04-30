# Connect to PocketBase as a superuser (admin)

Authenticates against the `_superusers` collection. Use this only for
[`pl_setup()`](https://your-org.github.io/pocketlogR/reference/pl_setup.md).
Regular operations should use
[`pl_connect()`](https://your-org.github.io/pocketlogR/reference/pl_connect.md).

## Usage

``` r
pl_connect_admin(url = NULL, email = NULL, password = NULL)
```

## Arguments

- url:

  PocketBase instance URL. Defaults to `POCKETLOG_URL` env var.

- email:

  Superuser email. Defaults to `POCKETLOG_ADMIN_EMAIL` env var.

- password:

  Superuser password. Defaults to `POCKETLOG_ADMIN_PASSWORD` env var.

## Value

A named list with elements `url` (character) and `token` (character
JWT).

## Examples

``` r
if (FALSE) { # \dontrun{
conn_admin <- pl_connect_admin()
} # }
```
