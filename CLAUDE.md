# CLAUDE.md — pocketlogR

## Project Overview

`pocketlogR` is an R package that logs application events (data jobs,
website monitoring, email checks, database checks, etc.) to a PocketBase
instance hosted on PocketHost. It serves as a unified operational
monitoring system across multiple use cases: ETL pipelines, website
uptime checks, data freshness validation, email receipt confirmation,
and more.

## Package Identity

- **Name:** `pocketlogR`
- **Language:** R
- **License:** MIT
- **Distribution:** GitHub (`devtools::install_github()`)
- **HTTP backend:** `httr2`
- **API style:** Functional (not R6/OOP). All exported functions are
  prefixed `pl_`.

------------------------------------------------------------------------

## Authentication

### Two auth modes

The package supports **two distinct authentication contexts**:

1.  **Admin mode (superuser)** — used only for
    [`pl_setup()`](https://your-org.github.io/pocketlogR/reference/pl_setup.md)
    to create collections and configure API rules. This is a one-time
    operation performed by the PocketBase administrator.
2.  **User mode (regular user)** — used for all daily operations
    ([`pl_log()`](https://your-org.github.io/pocketlogR/reference/pl_log.md),
    [`pl_get_logs()`](https://your-org.github.io/pocketlogR/reference/pl_get_logs.md),
    etc.). Authenticates against a regular PocketBase auth collection
    (default: `users`), not `_superusers`.

### How it works in PocketBase

PocketBase supports regular user authentication via auth collections.
The admin creates a **service account** (a regular user in the `users`
collection) dedicated to pocketlogR. The admin then sets **API rules**
on the `pl_flows` and `pl_logs` collections so that any authenticated
user can list and create records. This way, the R package never needs
superuser credentials during normal operation.

The API rule to allow any authenticated user is:
`@request.auth.id != ""`

### Credentials via environment variables

For **daily usage** (regular user): - `POCKETLOG_URL` — PocketBase
instance URL (e.g. `https://myapp.pockethost.io`) - `POCKETLOG_EMAIL` —
service account email - `POCKETLOG_PASSWORD` — service account password

For **admin setup** (superuser, one-time only): -
`POCKETLOG_ADMIN_EMAIL` — superuser email - `POCKETLOG_ADMIN_PASSWORD` —
superuser password - (Uses the same `POCKETLOG_URL`)

### Auth endpoints

- Regular user auth: `POST /api/collections/users/auth-with-password`
- Superuser auth: `POST /api/collections/_superusers/auth-with-password`

Both return a JSON response containing a `token` field (JWT). This token
must be sent as `Authorization: <token>` header on all subsequent
requests.

------------------------------------------------------------------------

## PocketBase Collections

Two collections, created by the admin via `pl_setup(conn_admin)`.

### `pl_flows` (applications / data flows index)

| Field         | Type     | Required | Notes                                                                                                                                                       |
|---------------|----------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `name`        | text     | yes      | Unique flow identifier (e.g. `"ectrl_data_load"`, `"website_ans_online"`)                                                                                   |
| `description` | text     | no       | Human-readable description of what this flow does                                                                                                           |
| `type`        | text     | yes      | Predefined but extensible (see Flow Types below). Any string accepted.                                                                                      |
| `schedule`    | text     | no       | Cron expression or human-readable schedule (e.g. `"daily 06:00"`, `"0 6 * * *"`)                                                                            |
| `depends_on`  | relation | no       | Multi-relation to `pl_flows` (self-referencing). Lists upstream flows this flow depends on. Forms a DAG — cycles are validated and rejected at the R level. |

**API rules** (set by
[`pl_setup()`](https://your-org.github.io/pocketlogR/reference/pl_setup.md)): -
listRule: `@request.auth.id != ""` - viewRule:
`@request.auth.id != ""` - createRule: `@request.auth.id != ""` -
updateRule: `@request.auth.id != ""` - deleteRule: `null` (superuser
only)

### `pl_logs` (log entries)

| Field      | Type     | Required | Notes                                                      |
|------------|----------|----------|------------------------------------------------------------|
| `flow`     | relation | yes      | Relation to `pl_flows` collection (flow ID)                |
| `status`   | text     | yes      | One of: `SUCCESS`, `ERROR`, `FATAL`                        |
| `message`  | text     | no       | Human-readable log message                                 |
| `metadata` | json     | no       | Arbitrary JSON (e.g. `{"rows": 1000, "duration_s": 12.5}`) |
| `created`  | autodate | auto     | Managed by PocketBase                                      |

**API rules** (set by
[`pl_setup()`](https://your-org.github.io/pocketlogR/reference/pl_setup.md)): -
listRule: `@request.auth.id != ""` - viewRule:
`@request.auth.id != ""` - createRule: `@request.auth.id != ""` -
updateRule: `null` (superuser only — logs are immutable) - deleteRule:
`null` (superuser only)

------------------------------------------------------------------------

## Core Functions

### Connection

``` r
# Regular user connection (daily use)
pl_connect(url = NULL, email = NULL, password = NULL)
```

- Falls back to `POCKETLOG_URL`, `POCKETLOG_EMAIL`, `POCKETLOG_PASSWORD`
  env vars if arguments are NULL.
- Authenticates against `/api/collections/users/auth-with-password`.
- Returns a connection list: `list(url = "...", token = "...")`.
- Errors immediately if auth fails (no retry).

``` r
# Admin/superuser connection (setup only)
pl_connect_admin(url = NULL, email = NULL, password = NULL)
```

- Falls back to `POCKETLOG_URL`, `POCKETLOG_ADMIN_EMAIL`,
  `POCKETLOG_ADMIN_PASSWORD` env vars.
- Authenticates against
  `/api/collections/_superusers/auth-with-password`.
- Returns the same connection list structure.

### Setup (admin only)

``` r
pl_setup(conn)
```

- **Requires a superuser connection** from
  [`pl_connect_admin()`](https://your-org.github.io/pocketlogR/reference/pl_connect_admin.md).
- Creates `pl_flows` and `pl_logs` collections in PocketBase if they
  don’t exist.
- Configures API rules so that authenticated regular users can
  list/view/create records.
- Idempotent — safe to call multiple times.
- Called once by the administrator during initial setup.

### Admin Operations (superuser only)

``` r
pl_delete_flow(conn, flow, force = FALSE)
```

- **Requires a superuser connection** from
  [`pl_connect_admin()`](https://your-org.github.io/pocketlogR/reference/pl_connect_admin.md).
- Deletes a flow by name. PocketBase enforces referential integrity —
  the call fails if any log entries reference the flow.
- `force = TRUE`: deletes all log entries for the flow first, then
  deletes the flow. This is the safe way to fully remove a flow.
- Errors if the flow is not found.

``` r
pl_delete_logs(conn, flow = NULL, before = NULL, status = NULL)
```

- **Requires a superuser connection** from
  [`pl_connect_admin()`](https://your-org.github.io/pocketlogR/reference/pl_connect_admin.md).
- Deletes log entries matching the given filters. All arguments
  optional; combined with AND logic.
- `flow`: only delete logs for this flow name.
- `before`: only delete logs created before this timestamp (`POSIXct` or
  ISO 8601).
- `status`: only delete logs with this status (`"SUCCESS"`, `"ERROR"`,
  or `"FATAL"`).
- Called with no filters, deletes **all** log entries.
- Returns the number of deleted records invisibly.

### Flow Management

``` r
pl_create_flow(conn, name, type, description = NULL, schedule = NULL, depends_on = NULL)
pl_get_flows(conn, type = NULL, name = NULL)
```

- [`pl_create_flow()`](https://your-org.github.io/pocketlogR/reference/pl_create_flow.md)
  registers a new flow. Errors if a flow with that name already exists.
- `depends_on`: optional character vector of upstream flow names
  (e.g. `c("ectrl_data_load", "email_confirmation")`). Resolved to
  PocketBase record IDs internally. Validates that all named flows exist
  and that adding the dependency would not create a cycle in the DAG.
- [`pl_get_flows()`](https://your-org.github.io/pocketlogR/reference/pl_get_flows.md)
  returns a data.frame of flows, optionally filtered by `type` or
  `name`. The `depends_on` column contains a list-column of upstream
  flow names.

### Dependency Management

``` r
pl_add_dependency(conn, flow, depends_on)
pl_remove_dependency(conn, flow, depends_on)
pl_get_dependencies(conn, flow, recursive = FALSE)
```

- [`pl_add_dependency()`](https://your-org.github.io/pocketlogR/reference/pl_add_dependency.md):
  adds one or more upstream dependencies to an existing flow.
  `depends_on` is a character vector of flow names. Validates against
  cycles before writing.
- [`pl_remove_dependency()`](https://your-org.github.io/pocketlogR/reference/pl_remove_dependency.md):
  removes one or more upstream dependencies from an existing flow.
- `pl_get_dependencies(conn, flow, recursive = FALSE)`: returns a
  data.frame of upstream flows.
  - `recursive = FALSE`: returns only direct (immediate) upstream
    dependencies.
  - `recursive = TRUE`: walks the full DAG upward, returning all
    transitive upstream dependencies.

### Dependency Health Check

``` r
pl_get_status(conn, flow, since = NULL)
```

- Returns a data.frame representing the full dependency chain health for
  the given flow.
- Walks the DAG **upward** (recursively through all upstream
  dependencies) and collects the **most recent log entry** for each flow
  in the chain (including the flow itself).
- Columns: `flow` (name), `type`, `status` (latest: SUCCESS/ERROR/FATAL
  or `NA` if never logged), `message`, `created` (timestamp of latest
  log), `depth` (0 = the flow itself, 1 = direct dependency, 2 =
  dependency of dependency, etc.).
- `since`: optional `POSIXct` or ISO 8601 string. If provided, only
  considers log entries created after this timestamp when determining
  latest status. Flows with no logs since that time get `status = NA`.
- The data.frame is sorted by `depth` (shallowest first), then by `flow`
  name.
- This function **never blocks or warns about failures** — it is purely
  informational. The caller decides what to do with the results.

### Full DAG Overview

``` r
pl_get_dag(conn, since = NULL)
```

- Returns a tibble of **all flows** across all DAGs (every connected
  component), with both raw and effective status.
- Columns:
  - `flow` — flow name
  - `type` — flow type
  - `schedule` — schedule string (`NA` if not set)
  - `raw_status` — the flow’s own latest log status
    (`SUCCESS`/`ERROR`/`FATAL`/`NA` if never logged)
  - `raw_status_time` — timestamp of that latest log (`NA` if never
    logged)
  - `effective_status` — `SUCCESS`, `ERROR`, `FATAL`, or `NA` (unknown).
    A flow is **poisoned** (effective status = upstream’s failing
    status) if any upstream has an `ERROR`/`FATAL` log **more recent
    than** this flow’s own last `SUCCESS` log — meaning the downstream
    ran *after* upstream was already broken. If the downstream has never
    logged, `effective_status = NA` regardless of upstream state.
  - `poisoned_by` — list-column of upstream flow names that caused the
    poison. Empty character vector for non-poisoned flows.
  - `depends_on` — list-column of direct upstream flow names.
  - `is_root` — logical, `TRUE` if the flow has no upstream
    dependencies.
- `since`: optional `POSIXct` or ISO 8601 string. If provided, only log
  entries after this timestamp are considered when determining
  `raw_status`. Flows with no logs in that window get `raw_status = NA`.
- **Poisoning rule:** downstream is poisoned only when it ran *after*
  upstream was already broken (upstream `ERROR`/`FATAL` timestamp \<
  downstream last `SUCCESS` timestamp is **not** poisoned; upstream
  failure timestamp \> downstream last `SUCCESS` timestamp **is**
  poisoned). If downstream has never logged, its `effective_status` is
  `NA` — not poisoned.
- Lives in `R/deps.R` alongside
  [`pl_get_status()`](https://your-org.github.io/pocketlogR/reference/pl_get_status.md).
- **Algorithm:**
  1.  Fetch all flows via
      [`pl_get_flows()`](https://your-org.github.io/pocketlogR/reference/pl_get_flows.md).
  2.  For each flow, fetch its latest log entry (respecting `since`).
  3.  For each flow, walk the full upstream DAG recursively; for any
      upstream with `ERROR`/`FATAL`, check if that failure timestamp is
      more recent than this flow’s `raw_status_time` — if so, mark as
      poisoned.
  4.  `effective_status` = the poisoning upstream’s status if poisoned,
      otherwise own `raw_status`.

#### Cycle detection

[`pl_create_flow()`](https://your-org.github.io/pocketlogR/reference/pl_create_flow.md)
and
[`pl_add_dependency()`](https://your-org.github.io/pocketlogR/reference/pl_add_dependency.md)
must validate that adding a dependency does not create a cycle. The
validation algorithm: 1. Starting from the proposed upstream flow(s),
walk the DAG upward recursively. 2. If the target flow (the one gaining
the dependency) appears anywhere in the upstream chain, reject with a
[`stop()`](https://rdrr.io/r/base/stop.html) error explaining which
flows form the cycle. 3. This is a simple DFS/BFS reachability check
performed in R using the flow records fetched from PocketBase.

### Logging

``` r
pl_log(conn, flow, status, message = NULL, metadata = NULL)
```

- `flow`: flow name (character). Resolved to PocketBase record ID
  internally.
- `status`: one of `"SUCCESS"`, `"ERROR"`, `"FATAL"`. Validated before
  sending.
- `message`: optional character string.
- `metadata`: optional named list, serialized to JSON via
  [`jsonlite::toJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html).

Convenience wrappers:

``` r
pl_success(conn, flow, message = NULL, metadata = NULL)
pl_error(conn, flow, message = NULL, metadata = NULL)
pl_fatal(conn, flow, message = NULL, metadata = NULL)
```

### Querying

``` r
pl_get_logs(conn, flow = NULL, status = NULL, from = NULL, to = NULL, limit = 50)
```

- Returns a data.frame of log entries.
- All filter arguments are optional; combined with AND logic.
- `from` / `to` accept `POSIXct` or ISO 8601 character timestamps.
- `limit` controls max records returned.

------------------------------------------------------------------------

## Error Handling & Retry

- **Logging functions only** (`pl_log`, `pl_success`, `pl_error`,
  `pl_fatal`):
  - On HTTP failure: retry **3 times**, **2 seconds apart** (fixed
    interval, not exponential).
  - After all retries exhausted: emit an R
    [`warning()`](https://rdrr.io/r/base/warning.html) with the error
    details and return `NULL` invisibly. **Never stop the calling
    script.**
- **All other functions** (`pl_connect`, `pl_connect_admin`, `pl_setup`,
  `pl_create_flow`, `pl_get_flows`, `pl_get_logs`, `pl_add_dependency`,
  `pl_remove_dependency`, `pl_get_dependencies`, `pl_get_status`,
  `pl_delete_flow`, `pl_delete_logs`):
  - Fail normally with [`stop()`](https://rdrr.io/r/base/stop.html) on
    error. These are interactive/setup operations.

------------------------------------------------------------------------

## Flow Types

Default flow types (defined as a character vector constant in `utils.R`,
exported as `pl_flow_types`):

- `data_job` — data load / ETL process (e.g. EUROCONTROL data import)
- `website_status` — periodic check if a website has had its expected
  update (monthly/weekly/yearly)
- `email_check` — check if an expected email was received (e.g. data
  services confirmation)
- `db_check` — database freshness check (is the data up to date?)
- `website_online` — uptime check (is the website responding?)

These are **not enforced at the R level** — any string is accepted as a
type. The defaults exist for documentation, consistency, and
convenience.

------------------------------------------------------------------------

## Coding Standards

- Use
  [`httr2::request()`](https://httr2.r-lib.org/reference/request.html)
  pipeline style for all HTTP calls.
- Use `jsonlite` for JSON serialization/deserialization.
- Use `cli` for user-facing messages (e.g. in
  [`pl_setup()`](https://your-org.github.io/pocketlogR/reference/pl_setup.md),
  connection success messages).
- Keep Imports minimal: `httr2`, `jsonlite`, `cli`.
- All exported functions must have roxygen2 documentation with
  `@export`, `@param`, `@return`, and `@examples`.
- Internal helper functions (e.g. resolving flow name to ID, building
  PocketBase filter strings, retry wrapper) are not exported and live in
  `R/utils.R`.
- Follow tidyverse style guide (snake_case, no `.` in function names
  except S3 methods).
- All functions that accept `conn` should validate it is a proper
  connection list with `url` and `token` elements.

------------------------------------------------------------------------

## Package Structure

    pocketlogR/
    ├── DESCRIPTION
    ├── NAMESPACE
    ├── LICENSE
    ├── LICENSE.md
    ├── README.md
    ├── CLAUDE.md
    ├── R/
    │   ├── connect.R        # pl_connect(), pl_connect_admin()
    │   ├── setup.R          # pl_setup()
    │   ├── flows.R          # pl_create_flow(), pl_get_flows()
    │   ├── deps.R           # pl_add_dependency(), pl_remove_dependency(), pl_get_dependencies(), pl_get_status(), pl_get_dag()
    │   ├── log.R            # pl_log(), pl_success(), pl_error(), pl_fatal()
    │   ├── query.R          # pl_get_logs()
    │   ├── admin.R          # pl_delete_flow(), pl_delete_logs()
    │   └── utils.R          # internal helpers: auth, retry, filter building, flow name resolution, cycle detection, pl_flow_types
    ├── man/                 # auto-generated by roxygen2
    ├── _pkgdown.yml         # pkgdown site configuration
    ├── .github/
    │   └── workflows/
    │       └── pkgdown.yml  # GitHub Actions: build & deploy docs to GitHub Pages
    └── tests/
        ├── testthat.R
        └── testthat/
            ├── test-connect.R
            ├── test-flows.R
            ├── test-deps.R
            ├── test-log.R
            ├── test-query.R
            ├── test-admin.R
            └── test-integration.R

------------------------------------------------------------------------

## Documentation

Documentation is generated with **pkgdown** and hosted on GitHub Pages.

- **Site URL:** `https://quintengoens.github.io/pocketlogR`

- **Config file:** `_pkgdown.yml` — Bootstrap 5 template, reference
  sections organised by function group.

- **Build locally:**

  ``` r
  pkgdown::build_site()          # full build into docs/
  pkgdown::build_reference()     # rebuild reference pages only
  ```

- **CI deployment:** `.github/workflows/pkgdown.yml` triggers on every
  push to `main`. It uses `r-lib/actions/setup-r@v2` and
  `r-lib/actions/setup-r-dependencies@v2`, then calls
  [`pkgdown::build_site_github_pages()`](https://pkgdown.r-lib.org/reference/build_site_github_pages.html)
  and pushes `docs/` to the `gh-pages` branch via
  `peaceiris/actions-gh-pages@v4`.

- Man pages are auto-generated by `roxygen2::roxygenise('.')` — never
  edit `.Rd` files by hand.

- After changing roxygen comments run `devtools::document()` before
  rebuilding the site.

------------------------------------------------------------------------

## Tests

- Framework: `testthat` (edition 3).
- Basic tests, **no HTTP mocking**.
- Test input validation (bad status values, missing required arguments,
  type checks).
- Test helper/utility functions (filter string building, metadata
  serialization, connection object validation).
- Test that retry logic respects the 3-attempt limit (can test with a
  counter/mock function).
- Test cycle detection: build mock flow lists and verify that cycles are
  correctly detected and rejected, and that valid DAGs are accepted.
- Tests must pass without a live PocketBase instance.

------------------------------------------------------------------------

## README.md Content Specification

The README must contain the following sections **in this order**:

### 1. Package Title and Badges

- Package name: `pocketlogR`
- One-line description: “Log application events to PocketBase from R”
- Badges: lifecycle (experimental), license (MIT).

### 2. Overview

- What the package does: unified operational monitoring via
  PocketBase/PocketHost.
- Use cases listed: data job ETL logging, website uptime monitoring,
  data freshness validation, email receipt confirmation, website update
  status tracking.
- Brief explanation that it uses two PocketBase collections (flows +
  logs), supports DAG-based flow dependencies with chain health checks,
  and authenticates as a regular user (not superuser) for daily
  operations.

### 3. Admin Setup Guide (for the PocketBase administrator)

Step-by-step instructions with screenshots descriptions where helpful:

**Step 1: Create a PocketHost instance** - Go to
<https://pockethost.io>, create an account, create a new instance. -
Note the instance URL (e.g. `https://myapp.pockethost.io`). - Access the
admin dashboard at `https://myapp.pockethost.io/_/`.

**Step 2: Create a service account user** - In the PocketBase Dashboard,
go to **Collections → users**. - Click **New record**. - Create a
dedicated user with: - Email: e.g. `pocketlog-service@yourorg.com` -
Password: a strong password - This is the account the R package will
authenticate with. **Do not share your superuser credentials with end
users.**

**Step 3: Run initial setup from R** - Install the package (see
Installation section). - Set superuser env vars temporarily or pass
credentials directly. - Run:
`r library(pocketlogR) conn_admin <- pl_connect_admin( url = "https://myapp.pockethost.io", email = "admin@yourorg.com", password = "your-superuser-password" ) pl_setup(conn_admin)` -
This creates the `pl_flows` and `pl_logs` collections with the correct
schema and API rules. - After this step, superuser credentials are **no
longer needed**.

**Step 4: Verify setup (optional)** - In the Dashboard, go to
**Collections → pl_flows** and **pl_logs**. - Click the **gear icon**
(collection settings) → **API Rules** tab. - Confirm: - List, View,
Create rules are set to `@request.auth.id != ""` - Update and Delete
rules are **locked** (null) - This means any authenticated user can read
and create records, but only superusers can modify or delete them.

**Step 5: Distribute credentials to users** - Share with your team: -
The PocketBase URL - The service account email and password - Users
should set these as environment variables (see User Setup below).

### 4. User Setup Guide (for R users / data engineers)

**Environment variables to set:**

| Variable             | Description              | Example                         |
|----------------------|--------------------------|---------------------------------|
| `POCKETLOG_URL`      | PocketBase instance URL  | `https://myapp.pockethost.io`   |
| `POCKETLOG_EMAIL`    | Service account email    | `pocketlog-service@yourorg.com` |
| `POCKETLOG_PASSWORD` | Service account password | `your-password`                 |

**Windows (Command Prompt):**

``` cmd
setx POCKETLOG_URL "https://myapp.pockethost.io"
setx POCKETLOG_EMAIL "pocketlog-service@yourorg.com"
setx POCKETLOG_PASSWORD "your-password"
```

> Note: Restart R/RStudio after running `setx` for changes to take
> effect.

**Windows (PowerShell):**

``` powershell
[System.Environment]::SetEnvironmentVariable("POCKETLOG_URL", "https://myapp.pockethost.io", "User")
[System.Environment]::SetEnvironmentVariable("POCKETLOG_EMAIL", "pocketlog-service@yourorg.com", "User")
[System.Environment]::SetEnvironmentVariable("POCKETLOG_PASSWORD", "your-password", "User")
```

**Linux / macOS (bash):**

``` bash
echo 'export POCKETLOG_URL="https://myapp.pockethost.io"' >> ~/.bashrc
echo 'export POCKETLOG_EMAIL="pocketlog-service@yourorg.com"' >> ~/.bashrc
echo 'export POCKETLOG_PASSWORD="your-password"' >> ~/.bashrc
source ~/.bashrc
```

**macOS (zsh):**

``` zsh
echo 'export POCKETLOG_URL="https://myapp.pockethost.io"' >> ~/.zshrc
echo 'export POCKETLOG_EMAIL="pocketlog-service@yourorg.com"' >> ~/.zshrc
echo 'export POCKETLOG_PASSWORD="your-password"' >> ~/.zshrc
source ~/.zshrc
```

**R `.Renviron` (cross-platform, recommended for R users):**

Edit `~/.Renviron` (or create a project-level `.Renviron`):

    POCKETLOG_URL=https://myapp.pockethost.io
    POCKETLOG_EMAIL=pocketlog-service@yourorg.com
    POCKETLOG_PASSWORD=your-password

> Restart R session after editing. Use `usethis::edit_r_environ()` to
> open the file easily.

### 5. Installation

``` r
# install.packages("devtools")
devtools::install_github("your-org/pocketlogR")
```

### 6. Quick Start

Complete working example:

``` r
library(pocketlogR)

# Connect (reads POCKETLOG_URL, POCKETLOG_EMAIL, POCKETLOG_PASSWORD from env)
conn <- pl_connect()

# Register your flows (once)
pl_create_flow(conn, "ectrl_data_load", type = "data_job",
               description = "Daily EUROCONTROL data import",
               schedule = "0 6 * * *")

pl_create_flow(conn, "data_services_email", type = "email_check",
               description = "Check data services confirmation email received")

# This flow depends on both the data load AND the email confirmation
pl_create_flow(conn, "ans_data_freshness", type = "db_check",
               description = "Verify ansperformance.eu datasets are current",
               depends_on = c("ectrl_data_load", "data_services_email"))

# Website online check is independent
pl_create_flow(conn, "ans_website_online", type = "website_online",
               description = "Check ansperformance.eu is reachable")

# Website content update depends on data being fresh AND site being online
pl_create_flow(conn, "ans_monthly_update", type = "website_status",
               description = "Check ansperformance.eu monthly update",
               schedule = "0 8 1 * *",
               depends_on = c("ans_data_freshness", "ans_website_online"))

# Add a dependency to an existing flow later
pl_add_dependency(conn, "ans_data_freshness", "another_upstream_flow")

# Log outcomes (always works, regardless of upstream status)
pl_success(conn, "ectrl_data_load",
           message = "Loaded 14,230 rows",
           metadata = list(rows = 14230, duration_s = 45.2))

pl_error(conn, "ans_website_online",
         message = "HTTP 503 returned",
         metadata = list(http_status = 503, response_time_ms = 12040))

# Check the full dependency chain health for a downstream flow
status <- pl_get_status(conn, "ans_monthly_update")
# Returns a data.frame:
#   flow                  type            status   depth
#   ans_monthly_update    website_status  SUCCESS  0
#   ans_data_freshness    db_check        SUCCESS  1
#   ans_website_online    website_online  ERROR    1
#   ectrl_data_load       data_job        SUCCESS  2
#   data_services_email   email_check     SUCCESS  2

# Query recent errors
errors <- pl_get_logs(conn, status = "ERROR", limit = 20)

# List all website monitoring flows
web_flows <- pl_get_flows(conn, type = "website_online")
```

### 7. Function Reference

Table of all exported functions with one-line descriptions.

### 8. Dependencies & DAG

Explain the dependency model: flows can declare upstream dependencies
via `depends_on`, forming a directed acyclic graph (DAG). Include: - How
to define dependencies at creation time and add/remove them later. - The
ASCII DAG diagram from the example showing the flow relationships. - How
[`pl_get_status()`](https://your-org.github.io/pocketlogR/reference/pl_get_status.md)
walks the chain and what the output looks like. - Note that dependencies
are purely informational — logging is never blocked. - Note that cycles
are detected and rejected.

### 9. Flow Types

List the 5 default types with descriptions, note they are extensible
(any string accepted).

------------------------------------------------------------------------

## PocketBase API Endpoints Used

| Operation           | Method | Endpoint                                          |
|---------------------|--------|---------------------------------------------------|
| Auth (regular user) | POST   | `/api/collections/users/auth-with-password`       |
| Auth (superuser)    | POST   | `/api/collections/_superusers/auth-with-password` |
| Create collection   | POST   | `/api/collections`                                |
| List collections    | GET    | `/api/collections`                                |
| List records        | GET    | `/api/collections/{name}/records`                 |
| Create record       | POST   | `/api/collections/{name}/records`                 |
| Update record       | PATCH  | `/api/collections/{name}/records/{id}`            |
| View single record  | GET    | `/api/collections/{name}/records/{id}`            |

### PocketBase filter syntax

- Equality: `field = "value"`
- Comparison: `field >= "2024-01-01 00:00:00"`
- AND: `field1 = "value1" && field2 = "value2"`
- Relation filtering: `flow.name = "my_flow"`

All filter values must be quoted strings in PocketBase filter syntax.

### Auth request body

``` json
{
  "identity": "user@example.com",
  "password": "secret"
}
```

### Auth response (relevant fields)

``` json
{
  "token": "JWT_TOKEN_HERE",
  "record": {
    "id": "...",
    "email": "..."
  }
}
```
