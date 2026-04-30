# Set up pocketlogR collections in PocketBase

Creates the `pl_flows` and `pl_logs` collections with the correct schema
and API rules. Requires a superuser connection from
[`pl_connect_admin()`](https://your-org.github.io/pocketlogR/reference/pl_connect_admin.md).
This function is idempotent — safe to call multiple times.

## Usage

``` r
pl_setup(conn)
```

## Arguments

- conn:

  A superuser connection object from
  [`pl_connect_admin()`](https://your-org.github.io/pocketlogR/reference/pl_connect_admin.md).

## Value

Invisibly returns `NULL`.

## Examples

``` r
if (FALSE) { # \dontrun{
conn_admin <- pl_connect_admin()
pl_setup(conn_admin)
} # }
```
