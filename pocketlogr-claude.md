# pocketlogR — Integration Reference for Claude

This file is intended to be copied into (or referenced from) another
project’s `CLAUDE.md` so Claude can implement operational logging using
`pocketlogR`.

Full docs: <https://euctrl-pru.github.io/pocketlogR>  
Source: <https://github.com/euctrl-pru/pocketlogR>

------------------------------------------------------------------------

## What it does

`pocketlogR` logs application events (ETL jobs, website checks, email
confirmations, database freshness checks) to a shared PocketBase
instance. It supports DAG-based flow dependencies so you can see
cascading failures across pipelines at a glance.

------------------------------------------------------------------------

## Installation

``` r
# install.packages("devtools")
devtools::install_github("euctrl-pru/pocketlogR")
```

------------------------------------------------------------------------

## Credentials (environment variables)

These must be set in `.Renviron` or the system environment. **Never
hardcode them.**

| Variable             | Description              |
|----------------------|--------------------------|
| `POCKETLOG_URL`      | PocketBase instance URL  |
| `POCKETLOG_EMAIL`    | Service account email    |
| `POCKETLOG_PASSWORD` | Service account password |

[`pl_connect()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect.md)
picks these up automatically when called with no arguments.

------------------------------------------------------------------------

## Core pattern

``` r
library(pocketlogR)

conn <- pl_connect()

# --- your script logic ---
tryCatch({
  # ... do work ...
  pl_success(conn, "my_flow_name",
             message = "Completed successfully",
             metadata = list(rows = n, duration_s = elapsed))
}, error = function(e) {
  pl_error(conn, "my_flow_name", message = conditionMessage(e))
})
```

Logging functions (`pl_success`, `pl_error`, `pl_fatal`, `pl_log`)
**never stop the calling script** — they retry 3 times on failure, then
emit a warning and return NULL invisibly.

------------------------------------------------------------------------

## Registering a flow (one-time)

Before logging, the flow must exist in PocketBase. This only needs to be
done once:

``` r
conn <- pl_connect()
pl_create_flow(conn,
               name        = "my_flow_name",
               type        = "data_job",       # see Flow Types below
               owner       = "quinten",        # required: person or team responsible
               description = "What this does",
               schedule    = "0 6 * * *")      # optional cron
```

[`pl_create_flow()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_create_flow.md)
errors if the flow already exists — safe to guard with a check:

``` r
if (nrow(pl_get_flows(conn, name = "my_flow_name")) == 0) {
  pl_create_flow(conn, "my_flow_name", type = "data_job")
}
```

------------------------------------------------------------------------

## Logging functions

``` r
pl_success(conn, flow, message = NULL, metadata = NULL)
pl_error(conn,   flow, message = NULL, metadata = NULL)
pl_fatal(conn,   flow, message = NULL, metadata = NULL)

# Or directly:
pl_log(conn, flow, status = "SUCCESS", message = NULL, metadata = NULL)
# status must be one of: "SUCCESS", "ERROR", "FATAL"
```

`metadata` accepts any named R list — serialised to JSON automatically:

``` r
pl_success(conn, "my_flow", metadata = list(rows = 1200, source = "ECTRL"))
```

------------------------------------------------------------------------

## Flow types

Any string is accepted, but use these standard types for consistency:

| Type             | Use for                                              |
|------------------|------------------------------------------------------|
| `data_job`       | ETL / data load pipeline                             |
| `website_status` | Periodic check if a site has had its expected update |
| `email_check`    | Check if an expected email was received              |
| `db_check`       | Database freshness check                             |
| `website_online` | Uptime check — is the site responding?               |

------------------------------------------------------------------------

## Dependencies between flows

Declare upstream dependencies so
[`pl_get_dag()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_get_dag.md)
can show cascading failures:

``` r
# At creation time:
pl_create_flow(conn, "downstream_flow", type = "db_check",
               depends_on = c("upstream_flow_a", "upstream_flow_b"))

# Or add later:
pl_add_dependency(conn, "downstream_flow", "upstream_flow_a")
```

Cycles are detected and rejected automatically.

------------------------------------------------------------------------

## Checking status

``` r
# Full dependency chain health for one flow:
pl_get_status(conn, "my_flow")
# Returns data.frame: flow, type, status, message, created, depth

# Full DAG across all flows (includes poisoning detection):
pl_get_dag(conn)
# Returns data.frame with effective_status — a flow is POISONED if an
# upstream ERROR/FATAL occurred more recently than its last SUCCESS.

# Query raw log entries:
pl_get_logs(conn, flow = "my_flow", status = "ERROR", limit = 20)
```

------------------------------------------------------------------------

## What NOT to do

- Do not call
  [`pl_setup()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_setup.md)
  — the collections already exist in PocketBase.
- Do not call
  [`pl_connect_admin()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect_admin.md)
  — superuser access is not needed for logging.
- Do not wrap `pl_success` / `pl_error` in additional `tryCatch` — they
  already handle retries internally and will never throw.
- Do not log inside a tight loop — log once per job run (start/end), not
  per row.

------------------------------------------------------------------------

## Project-specific context

When adding this to a project’s `CLAUDE.md`, append a section like:

``` markdown
## pocketlogR context for this project

- Flow name: `"<flow_name>"` (already registered — do not call pl_create_flow)
- Type: `"<type>"`
- Owner: `"<owner>"`
- Schedule: `"<cron or description>"`
- Depends on: `c("<upstream_flow>")` (or none)
- Log success at the end of the main execution block
- Log error in the tryCatch handler with `conditionMessage(e)` as the message
- Include relevant metadata: e.g. `list(rows = n, source = "...", duration_s = t)`
```
