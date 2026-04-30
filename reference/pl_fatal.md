# Log a FATAL event

Convenience wrapper around
[`pl_log()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_log.md)
for unrecoverable failures.

## Usage

``` r
pl_fatal(conn, flow, message = NULL, metadata = NULL)
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
pl_fatal(conn, "ectrl_data_load", message = "Unrecoverable database error")
} # }
```
