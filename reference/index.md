# Package index

## Connection

Establish a connection to PocketBase.

- [`pl_connect()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect.md)
  : Connect to PocketBase as a regular user
- [`pl_connect_admin()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect_admin.md)
  : Connect to PocketBase as a superuser (admin)

## Setup

One-time admin setup of PocketBase collections.

- [`pl_setup()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_setup.md)
  : Set up pocketlogR collections in PocketBase

## Flows

Register and query monitored processes.

- [`pl_create_flow()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_create_flow.md)
  : Create a new flow
- [`pl_get_flows()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_get_flows.md)
  : List flows

## Dependencies

Manage DAG-based upstream dependencies between flows.

- [`pl_add_dependency()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_add_dependency.md)
  : Add upstream dependencies to a flow
- [`pl_remove_dependency()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_remove_dependency.md)
  : Remove upstream dependencies from a flow
- [`pl_get_dependencies()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_get_dependencies.md)
  : Get upstream dependencies of a flow

## Status & DAG

Inspect health across the dependency graph.

- [`pl_get_status()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_get_status.md)
  : Get dependency chain health status for a flow
- [`pl_get_dag()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_get_dag.md)
  : Get a full DAG overview of all flows and their health

## Logging

Write log entries from your scripts and pipelines.

- [`pl_log()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_log.md)
  : Log an event for a flow
- [`pl_success()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_success.md)
  : Log a SUCCESS event
- [`pl_error()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_error.md)
  : Log an ERROR event
- [`pl_fatal()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_fatal.md)
  : Log a FATAL event

## Querying

Read log entries back for reporting or alerting.

- [`pl_get_logs()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_get_logs.md)
  : Query log entries

## Admin Operations

Superuser-only maintenance functions. Require a connection from
[`pl_connect_admin()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_connect_admin.md).

- [`pl_delete_flow()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_delete_flow.md)
  : Delete a flow (admin only)
- [`pl_delete_logs()`](https://euctrl-pru.github.io/pocketlogR/reference/pl_delete_logs.md)
  : Delete log entries (admin only)

## Constants

- [`pl_flow_types`](https://euctrl-pru.github.io/pocketlogR/reference/pl_flow_types.md)
  : Default flow types
