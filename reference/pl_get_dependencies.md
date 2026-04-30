# Get upstream dependencies of a flow

Returns a data.frame of upstream flows for the named flow.

## Usage

``` r
pl_get_dependencies(conn, flow, recursive = FALSE)
```

## Arguments

- conn:

  A connection object from
  [`pl_connect()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect.md).

- flow:

  Flow name.

- recursive:

  If `TRUE`, walks the full DAG upward and returns all transitive
  upstream dependencies. If `FALSE` (default), returns only direct
  (immediate) upstream dependencies.

## Value

A data.frame with columns: `name`, `type`, `description`, `schedule`,
`depth`.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- pl_connect()
pl_get_dependencies(conn, "ans_monthly_update")
pl_get_dependencies(conn, "ans_monthly_update", recursive = TRUE)
} # }
```
