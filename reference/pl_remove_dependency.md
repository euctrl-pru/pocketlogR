# Remove upstream dependencies from a flow

Removes one or more upstream flows from the dependency list of the
target flow.

## Usage

``` r
pl_remove_dependency(conn, flow, depends_on)
```

## Arguments

- conn:

  A connection object from
  [`pl_connect()`](https://your-org.github.io/pocketlogR/reference/pl_connect.md).

- flow:

  Name of the flow to update.

- depends_on:

  Character vector of upstream flow names to remove.

## Value

Invisibly returns the updated flow record.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- pl_connect()
pl_remove_dependency(conn, "ans_data_freshness", "another_upstream_flow")
} # }
```
