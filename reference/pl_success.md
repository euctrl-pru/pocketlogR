# Log a SUCCESS event

Convenience wrapper around
[`pl_log()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_log.md)
for successful outcomes.

## Usage

``` r
pl_success(conn, flow, message = NULL, metadata = NULL)
```

## Arguments

- conn:

  A connection object from
  [`pl_connect()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect.md).

- flow:

  Flow name (character).

- message:

  Optional human-readable log message.

- metadata:

  Optional named list, serialized to JSON.

## Value

Invisibly returns the created log record, or `NULL` on failure.

## Examples

``` r
if (FALSE) { # \dontrun{
pl_success(conn, "ectrl_data_load",
           message = "Loaded 14230 rows",
           metadata = list(rows = 14230))
} # }
```
