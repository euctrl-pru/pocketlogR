# Delete a flow (admin only)

Deletes a flow by name. Requires a superuser connection. Because
PocketBase enforces referential integrity, any log entries referencing
the flow must be deleted first. Use `force = TRUE` to do this
automatically.

## Usage

``` r
pl_delete_flow(conn, flow, force = FALSE)
```

## Arguments

- conn:

  A superuser connection object from
  [`pl_connect_admin()`](https://your-org.github.io/pocketlogR/reference/pl_connect_admin.md).

- flow:

  Flow name (character).

- force:

  If `TRUE`, deletes all log entries for this flow before deleting the
  flow itself. If `FALSE` (default), errors if log entries exist.

## Value

Invisibly returns `NULL`.

## Examples

``` r
if (FALSE) { # \dontrun{
conn_admin <- pl_connect_admin()
pl_delete_flow(conn_admin, "old_flow", force = TRUE)
} # }
```
