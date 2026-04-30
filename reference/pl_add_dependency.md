# Add upstream dependencies to a flow

Adds one or more upstream flows as dependencies of the target flow.
Validates that all named flows exist and that no cycle would be created.

## Usage

``` r
pl_add_dependency(conn, flow, depends_on)
```

## Arguments

- conn:

  A connection object from
  [`pl_connect()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect.md).

- flow:

  Name of the flow to update.

- depends_on:

  Character vector of upstream flow names to add.

## Value

Invisibly returns the updated flow record.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- pl_connect()
pl_add_dependency(conn, "ans_data_freshness", "another_upstream_flow")
} # }
```
