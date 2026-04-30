# Get dependency chain health status for a flow

Walks the DAG upward (recursively through all upstream dependencies) and
collects the most recent log entry for each flow in the chain, including
the flow itself.

## Usage

``` r
pl_get_status(conn, flow, since = NULL)
```

## Arguments

- conn:

  A connection object from
  [`pl_connect()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect.md).

- flow:

  Flow name.

- since:

  Optional `POSIXct` or ISO 8601 string. If provided, only log entries
  created after this timestamp are considered. Flows with no logs since
  that time get `status = NA`.

## Value

A data.frame sorted by `depth` then `flow`, with columns: `flow`,
`type`, `status`, `message`, `created`, `depth`.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- pl_connect()
pl_get_status(conn, "ans_monthly_update")
pl_get_status(conn, "ans_monthly_update", since = Sys.time() - 86400)
} # }
```
