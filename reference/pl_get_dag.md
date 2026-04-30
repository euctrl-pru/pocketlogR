# Get a full DAG overview of all flows and their health

Returns a tibble (data.frame) of ALL flows with both their raw (most
recent log) status and effective (cascade-aware) status. A flow is
considered "poisoned" if any upstream dependency has a more recent
ERROR/FATAL log than the flow's own last SUCCESS log — meaning the flow
ran successfully before the upstream broke.

## Usage

``` r
pl_get_dag(conn, since = NULL)
```

## Arguments

- conn:

  A connection object from
  [`pl_connect()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect.md).

- since:

  Optional `POSIXct` or ISO 8601 string. If provided, only considers log
  entries created after this timestamp.

## Value

A data.frame with columns:

- `flow` (character): flow name

- `type` (character): flow type

- `schedule` (character): schedule string

- `raw_status` (character): most recent log status (`NA` if never
  logged)

- `raw_status_time` (character): timestamp of most recent log

- `effective_status` (character): `"SUCCESS"`, `"ERROR"`, `"FATAL"`,
  `"POISONED"`, or `NA` if never logged

- `poisoned_by` (list-column): character vector of upstream flow names
  that caused poisoning

- `depends_on` (list-column): character vector of direct upstream flow
  names

- `is_root` (logical): `TRUE` if the flow has no upstream dependencies

## Details

**Poisoning rule:** A downstream flow is poisoned if:

1.  It has at least one upstream flow with an ERROR or FATAL log.

2.  The downstream's last SUCCESS log is MORE RECENT than that upstream
    failure. (i.e., the downstream ran successfully after the upstream
    had already broken.)

3.  The downstream itself is not already ERROR or FATAL.

If the downstream has never logged, `effective_status` is `NA`
(unknown), regardless of upstream status.

## Examples

``` r
if (FALSE) { # \dontrun{
conn <- pl_connect()
dag <- pl_get_dag(conn)
dag
} # }
```
