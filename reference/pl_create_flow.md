# Create a new flow

Registers a new flow in PocketBase. Errors if a flow with the same name
already exists. Validates that `depends_on` flows exist and that adding
them would not create a cycle in the DAG.

## Usage

``` r
pl_create_flow(
  conn,
  name,
  type,
  owner,
  description = NULL,
  schedule = NULL,
  metadata = NULL,
  depends_on = NULL
)
```

## Arguments

- conn:

  A connection object from
  [`pl_connect()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect.md).

- name:

  Unique flow identifier (e.g. `"ectrl_data_load"`).

- type:

  Flow type string. See
  [pl_flow_types](https://euctrl-pru.github.io/pocketlogR/reference/pl_flow_types.md)
  for defaults, but any string is accepted.

- owner:

  Free-text owner or responsible party (e.g. `"quinten"`,
  `"team-data"`).

- description:

  Optional human-readable description.

- schedule:

  Optional cron expression or human-readable schedule string.

- metadata:

  Optional named list of arbitrary data, serialised to JSON (e.g.
  `list(url = "https://...", region = "EU")`).

- depends_on:

  Optional character vector of upstream flow names.

## Value

Invisibly returns the created flow record as a list.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- pl_connect()
pl_create_flow(conn, "ectrl_data_load", type = "data_job", owner = "quinten",
               description = "Daily EUROCONTROL data import",
               schedule = "0 6 * * *")
} # }
```
