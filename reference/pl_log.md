# Log an event for a flow

Records a log entry for the named flow. On HTTP failure, retries up to 3
times with 2-second intervals. If all retries fail, emits a warning and
returns `NULL` invisibly — the calling script is never stopped.

## Usage

``` r
pl_log(conn, flow, status, message = NULL, metadata = NULL)
```

## Arguments

- conn:

  A connection object from
  [`pl_connect()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect.md).

- flow:

  Flow name (character).

- status:

  One of `"SUCCESS"`, `"ERROR"`, or `"FATAL"`.

- message:

  Optional human-readable log message.

- metadata:

  Optional named list, serialized to JSON.

## Value

Invisibly returns the created log record, or `NULL` on failure.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- pl_connect()
pl_log(conn, "ectrl_data_load", "SUCCESS",
       message = "Loaded 14230 rows",
       metadata = list(rows = 14230, duration_s = 45.2))
} # }
```
