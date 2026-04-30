# List flows

Returns a data.frame of flows, optionally filtered by type or name.

## Usage

``` r
pl_get_flows(conn, type = NULL, name = NULL)
```

## Arguments

- conn:

  A connection object from
  [`pl_connect()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect.md).

- type:

  Optional flow type to filter by.

- name:

  Optional flow name to filter by.

## Value

A data.frame with columns: `id`, `name`, `type`, `description`,
`schedule`, `owner`, `depends_on` (list-column of upstream flow names),
`created`, `updated`.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- pl_connect()
pl_get_flows(conn)
pl_get_flows(conn, type = "data_job")
pl_get_flows(conn, name = "ectrl_data_load")
} # }
```
