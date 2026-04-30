# Query log entries

Returns a data.frame of log entries, optionally filtered. All filter
arguments are optional and combined with AND logic.

## Usage

``` r
pl_get_logs(
  conn,
  flow = NULL,
  status = NULL,
  from = NULL,
  to = NULL,
  limit = 50
)
```

## Arguments

- conn:

  A connection object from
  [`pl_connect()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect.md).

- flow:

  Optional flow name to filter by.

- status:

  Optional status to filter by (`"SUCCESS"`, `"ERROR"`, or `"FATAL"`).

- from:

  Optional start timestamp (`POSIXct` or ISO 8601 string).

- to:

  Optional end timestamp (`POSIXct` or ISO 8601 string).

- limit:

  Maximum number of records to return. Default 50.

## Value

A data.frame with columns: `id`, `flow` (flow name), `status`,
`message`, `metadata`, `created`.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- pl_connect()
pl_get_logs(conn)
pl_get_logs(conn, flow = "ectrl_data_load", status = "ERROR")
pl_get_logs(conn, from = Sys.time() - 86400, limit = 100)
} # }
```
