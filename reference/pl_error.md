# Log an ERROR event

Convenience wrapper around
[`pl_log()`](https://your-org.github.io/pocketlogR/reference/pl_log.md)
for recoverable errors.

## Usage

``` r
pl_error(conn, flow, message = NULL, metadata = NULL)
```

## Arguments

- conn:

  A connection object from
  [`pl_connect()`](https://your-org.github.io/pocketlogR/reference/pl_connect.md).

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
pl_error(conn, "ans_website_online",
         message = "HTTP 503 returned",
         metadata = list(http_status = 503))
} # }
```
