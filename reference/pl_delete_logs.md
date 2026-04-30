# Delete log entries (admin only)

Deletes log entries. Requires a superuser connection. All filter
arguments are optional and combined with AND logic. Called with no
filters, deletes all log entries.

## Usage

``` r
pl_delete_logs(conn, flow = NULL, before = NULL, status = NULL)
```

## Arguments

- conn:

  A superuser connection object from
  [`pl_connect_admin()`](https://your-org.github.io/pocketlogR/reference/pl_connect_admin.md).

- flow:

  Optional flow name. If provided, only logs for that flow are deleted.

- before:

  Optional `POSIXct` or ISO 8601 string. If provided, only logs created
  before this timestamp are deleted.

- status:

  Optional status string (`"SUCCESS"`, `"ERROR"`, or `"FATAL"`). If
  provided, only logs with that status are deleted.

## Value

Invisibly returns the number of deleted records.

## Examples

``` r
if (FALSE) { # \dontrun{
conn_admin <- pl_connect_admin()

# Delete all logs older than 30 days
pl_delete_logs(conn_admin, before = Sys.time() - 30 * 86400)

# Delete all error logs for a specific flow
pl_delete_logs(conn_admin, flow = "ectrl_data_load", status = "ERROR")

# Delete all logs for a flow (used internally by pl_delete_flow(force=TRUE))
pl_delete_logs(conn_admin, flow = "old_flow")
} # }
```
