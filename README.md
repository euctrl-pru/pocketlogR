# pocketlogR

> Log application events to PocketBase from R

[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

`pocketlogR` is an R package for unified operational monitoring. It logs events from data pipelines, website checks, email confirmations, and database freshness checks to a [PocketBase](https://pocketbase.io) instance hosted on [PocketHost](https://pockethost.io).

**Use cases:**

- Data job / ETL pipeline logging
- Website uptime monitoring
- Data freshness validation
- Email receipt confirmation
- Website update status tracking

The package writes to two PocketBase collections — `pl_flows` (a registry of your monitored processes) and `pl_logs` (log entries). Flows can declare upstream dependencies, forming a DAG that lets you see cascading failures at a glance. For daily operations, the package authenticates as a regular service account user — superuser credentials are only needed once, during initial setup.

---

## Admin Setup Guide

This section is for the PocketBase administrator who sets up the instance. End users only need [User Setup](#user-setup-guide).

### Step 1 — Create a PocketHost instance

1. Go to [pockethost.io](https://pockethost.io), create an account, and create a new instance.
2. Note the instance URL — it will look like `https://myapp.pockethost.io`.
3. Access the admin dashboard at `https://myapp.pockethost.io/_/`.

### Step 2 — Create a service account

The R package authenticates as a regular PocketBase user, not as the superuser. Create a dedicated service account:

1. In the PocketBase dashboard, go to **Collections → users**.
2. Click **New record**.
3. Set an email (e.g. `pocketlog-service@yourorg.com`) and a strong password.
4. Save the record.

> **Do not share your superuser credentials with end users.** The service account is what gets distributed.

### Step 3 — Run initial setup from R

Install the package (see [Installation](#installation)) and run `pl_setup()` with your superuser credentials. This creates the `pl_flows` and `pl_logs` collections with the correct schema and API rules.

```r
library(pocketlogR)

conn_admin <- pl_connect_admin(
  url      = "https://myapp.pockethost.io",
  email    = "admin@yourorg.com",
  password = "your-superuser-password"
)

pl_setup(conn_admin)
```

`pl_setup()` is idempotent — safe to run multiple times.

### Step 4 — Verify (optional)

In the PocketBase dashboard, open **Collections → pl_flows** (or `pl_logs`), click the gear icon, and go to **API Rules**:

| Rule   | Expected value              |
|--------|-----------------------------|
| List   | `@request.auth.id != ""`    |
| View   | `@request.auth.id != ""`    |
| Create | `@request.auth.id != ""`    |
| Update | *(locked — superuser only)* |
| Delete | *(locked — superuser only)* |

### Step 5 — Distribute credentials to users

Share with your team:

- The PocketBase URL (`https://myapp.pockethost.io`)
- The service account email and password

Users set these as environment variables — see [User Setup](#user-setup-guide) below.

---

## User Setup Guide

Set three environment variables so pocketlogR can connect without hardcoding credentials.

| Variable             | Description              | Example                             |
|----------------------|--------------------------|-------------------------------------|
| `POCKETLOG_URL`      | PocketBase instance URL  | `https://myapp.pockethost.io`       |
| `POCKETLOG_EMAIL`    | Service account email    | `pocketlog-service@yourorg.com`     |
| `POCKETLOG_PASSWORD` | Service account password | `your-password`                     |

### R `.Renviron` — recommended for R users

Edit your `~/.Renviron` (use `usethis::edit_r_environ()` to open it):

```
POCKETLOG_URL=https://myapp.pockethost.io
POCKETLOG_EMAIL=pocketlog-service@yourorg.com
POCKETLOG_PASSWORD=your-password
```

Restart your R session after saving.

### macOS / Linux (zsh)

```zsh
echo 'export POCKETLOG_URL="https://myapp.pockethost.io"' >> ~/.zshrc
echo 'export POCKETLOG_EMAIL="pocketlog-service@yourorg.com"' >> ~/.zshrc
echo 'export POCKETLOG_PASSWORD="your-password"' >> ~/.zshrc
source ~/.zshrc
```

### macOS / Linux (bash)

```bash
echo 'export POCKETLOG_URL="https://myapp.pockethost.io"' >> ~/.bashrc
echo 'export POCKETLOG_EMAIL="pocketlog-service@yourorg.com"' >> ~/.bashrc
echo 'export POCKETLOG_PASSWORD="your-password"' >> ~/.bashrc
source ~/.bashrc
```

### Windows (PowerShell)

```powershell
[System.Environment]::SetEnvironmentVariable("POCKETLOG_URL", "https://myapp.pockethost.io", "User")
[System.Environment]::SetEnvironmentVariable("POCKETLOG_EMAIL", "pocketlog-service@yourorg.com", "User")
[System.Environment]::SetEnvironmentVariable("POCKETLOG_PASSWORD", "your-password", "User")
```

### Windows (Command Prompt)

```cmd
setx POCKETLOG_URL "https://myapp.pockethost.io"
setx POCKETLOG_EMAIL "pocketlog-service@yourorg.com"
setx POCKETLOG_PASSWORD "your-password"
```

> Restart R/RStudio after running `setx` for changes to take effect.

---

## Installation

```r
# install.packages("devtools")
devtools::install_github("euctrl-pru/pocketlogR")
```

---

## Quick Start

```r
library(pocketlogR)

# Connect — reads POCKETLOG_URL, POCKETLOG_EMAIL, POCKETLOG_PASSWORD from env
conn <- pl_connect()

# Register your flows once
pl_create_flow(conn, "ectrl_data_load", type = "data_job",
               description = "Daily EUROCONTROL data import",
               schedule = "0 6 * * *")

pl_create_flow(conn, "data_services_email", type = "email_check",
               description = "Check data services confirmation email received")

# This flow depends on both the data load AND the email confirmation
pl_create_flow(conn, "ans_data_freshness", type = "db_check",
               description = "Verify ansperformance.eu datasets are current",
               depends_on = c("ectrl_data_load", "data_services_email"))

pl_create_flow(conn, "ans_website_online", type = "website_online",
               description = "Check ansperformance.eu is reachable")

pl_create_flow(conn, "ans_monthly_update", type = "website_status",
               description = "Check ansperformance.eu monthly update",
               schedule = "0 8 1 * *",
               depends_on = c("ans_data_freshness", "ans_website_online"))

# Log outcomes from your scripts (log_type is required)
pl_success(conn, "ectrl_data_load",
           log_type = "data_job",
           message  = "Loaded 14,230 rows",
           metadata = list(rows = 14230, duration_s = 45.2))

pl_error(conn, "ans_website_online",
         log_type = "website_online",
         message  = "HTTP 503 returned",
         metadata = list(http_status = 503, response_time_ms = 12040))

# Check the full dependency chain for a downstream flow
pl_get_status(conn, "ans_monthly_update")

# Query recent errors
pl_get_logs(conn, status = "ERROR", limit = 20)
```

---

## Dependencies & DAG

Flows can declare upstream dependencies at creation time or later, forming a directed acyclic graph (DAG). The package validates and rejects cycles.

```
ectrl_data_load ──┐
                  ├──► ans_data_freshness ──┐
data_services_email ──┘                    ├──► ans_monthly_update
ans_website_online ────────────────────────┘
```

Define dependencies at creation:

```r
pl_create_flow(conn, "ans_data_freshness", type = "db_check",
               depends_on = c("ectrl_data_load", "data_services_email"))
```

Add or remove them later:

```r
pl_add_dependency(conn, "ans_data_freshness", "another_upstream")
pl_remove_dependency(conn, "ans_data_freshness", "another_upstream")
```

`pl_get_status()` walks the full upstream chain and returns the latest log status for each flow:

```r
pl_get_status(conn, "ans_monthly_update")
#>                  flow           type  status depth
#>    ans_monthly_update website_status SUCCESS     0
#>    ans_data_freshness       db_check SUCCESS     1
#>    ans_website_online website_online   ERROR     1
#>       ectrl_data_load       data_job SUCCESS     2
#>   data_services_email    email_check SUCCESS     2
```

`pl_get_dag()` returns the full picture across all flows, including cascade ("poisoned") status — a flow is marked `POISONED` if it ran successfully *after* an upstream failure, meaning its last result is stale:

```r
dag <- pl_get_dag(conn)
#>                  flow           type raw_status effective_status poisoned_by
#>       ectrl_data_load       data_job    SUCCESS          SUCCESS          []
#>   data_services_email    email_check    SUCCESS          SUCCESS          []
#>    ans_data_freshness       db_check    SUCCESS         POISONED [ectrl_...]
#>    ans_website_online website_online      ERROR            ERROR          []
#>    ans_monthly_update website_status    SUCCESS         POISONED [ans_da...]
```

Dependencies are purely informational — logging is never blocked by upstream status.

---

## Function Reference

### Daily use (regular user connection)

| Function                  | Description                                                         |
|---------------------------|---------------------------------------------------------------------|
| `pl_connect()`            | Connect as a regular user                                           |
| `pl_create_flow()`        | Register a new flow                                                 |
| `pl_get_flows()`          | List flows, optionally filtered by name or type                     |
| `pl_add_dependency()`     | Add upstream dependencies to an existing flow                       |
| `pl_remove_dependency()`  | Remove upstream dependencies from an existing flow                  |
| `pl_get_dependencies()`   | List direct or transitive upstream dependencies                     |
| `pl_get_status()`         | Full dependency chain health for a single flow                      |
| `pl_get_dag()`            | Full DAG overview with raw and cascade-aware effective status        |
| `pl_log()`                | Log an event (`SUCCESS`, `ERROR`, or `FATAL`) with a required `log_type` |
| `pl_success()`            | Shorthand for `pl_log(..., status = "SUCCESS")`                     |
| `pl_error()`              | Shorthand for `pl_log(..., status = "ERROR")`                       |
| `pl_fatal()`              | Shorthand for `pl_log(..., status = "FATAL")`                       |
| `pl_get_logs()`           | Query log entries with optional filters                             |
| `pl_flow_types`           | Character vector of the five default flow type strings              |
| `pl_log_types`            | Character vector of the five default log type strings               |

### Admin only (superuser connection)

| Function                  | Description                                                         |
|---------------------------|---------------------------------------------------------------------|
| `pl_connect_admin()`      | Connect as a superuser                                              |
| `pl_setup()`              | Create collections and API rules (one-time)                         |
| `pl_delete_flow()`        | Delete a flow by name, optionally force-deleting its logs first     |
| `pl_delete_logs()`        | Delete log entries, optionally filtered by flow, status, or date    |

---

## Flow Types

The `type` field on a flow describes what kind of process it is. Five built-in values for consistency — any string accepted.

| Type             | Description                                                    |
|------------------|----------------------------------------------------------------|
| `data_job`       | Data load / ETL process                                        |
| `website_status` | Periodic check whether a website has had its expected update   |
| `email_check`    | Check whether an expected email was received                   |
| `db_check`       | Database freshness check — is the data up to date?             |
| `website_online` | Uptime check — is the website responding?                      |

## Log Types

Every log entry carries a `log_type` — a required field describing what kind of check or run the entry represents. This is separate from the flow's `type` and can vary per log entry. Five built-in values for consistency — any string accepted.

| Log type         | Description                                                    |
|------------------|----------------------------------------------------------------|
| `data_job`       | Data load / ETL run                                            |
| `website_status` | Check whether a website has had its expected update            |
| `email_check`    | Check whether an expected email was received                   |
| `db_check`       | Database freshness check                                       |
| `website_online` | Uptime check                                                   |

```r
pl_success(conn, "my_flow", log_type = "data_job", message = "Done")
pl_error(conn,   "my_flow", log_type = "website_online", message = "Timeout")
```

---

## Admin Operations

These functions require a superuser connection (`pl_connect_admin()`) and are intended for maintenance — not day-to-day use.

### Deleting a flow

Flows can only be deleted by a superuser. PocketBase enforces referential integrity, so any log entries for the flow must be removed first. Use `force = TRUE` to do both in one call:

```r
conn_admin <- pl_connect_admin()

# Safe delete — removes logs then the flow
pl_delete_flow(conn_admin, "old_flow", force = TRUE)

# Without force — errors if logs exist
pl_delete_flow(conn_admin, "empty_flow")
```

### Pruning log entries

```r
conn_admin <- pl_connect_admin()

# Delete logs older than 90 days
pl_delete_logs(conn_admin, before = Sys.time() - 90 * 86400)

# Delete all error logs for a specific flow
pl_delete_logs(conn_admin, flow = "ectrl_data_load", status = "ERROR")

# Delete all logs for a flow (e.g. before removing it)
pl_delete_logs(conn_admin, flow = "old_flow")

# Delete everything (use with care)
pl_delete_logs(conn_admin)
```

---

## Running Tests Against a Live Database

The unit tests run without a network connection. To also run integration tests against a real PocketBase instance, set these additional environment variables before running the test suite:

| Variable                   | Description                        |
|----------------------------|------------------------------------|
| `POCKETLOG_URL`            | PocketBase instance URL            |
| `POCKETLOG_EMAIL`          | Service account email              |
| `POCKETLOG_PASSWORD`       | Service account password           |
| `POCKETLOG_ADMIN_EMAIL`    | Superuser email (for setup tests)  |
| `POCKETLOG_ADMIN_PASSWORD` | Superuser password (for setup tests)|

Add them to a project-level `.Renviron` at the root of the repo (this file is gitignored):

```
POCKETLOG_URL=https://myapp.pockethost.io
POCKETLOG_EMAIL=pocketlog-service@yourorg.com
POCKETLOG_PASSWORD=your-password
POCKETLOG_ADMIN_EMAIL=admin@yourorg.com
POCKETLOG_ADMIN_PASSWORD=your-superuser-password
```

Integration tests are skipped automatically when these variables are absent, so the standard `testthat::test_dir()` / `devtools::test()` invocation always works offline.

---

## Documentation

Full function reference and articles are published as a pkgdown site on GitHub Pages:

> **https://euctrl-pru.github.io/pocketlogR**

To build the docs locally:

```r
# install.packages("pkgdown")
pkgdown::build_site()
```

The site is regenerated automatically on every push to `main` via the GitHub Actions workflow at `.github/workflows/pkgdown.yml`.
