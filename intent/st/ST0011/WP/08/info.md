---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
wp_id: WP-08
title: "One error-formatting pipeline"
scope: Small
status: Not Started
---

# WP-08: One error-formatting pipeline

## Objective

One error dialect, formatted in one place. Findings: C5, C15 (inspect-wrapping leg), plus the REPL deprecated formatters.

## Deliverables

- `ErrorHandler.format_error/2` becomes the single formatter; `Arca.Cli.format_error_with_type`, `error_type_to_prefix`, and the `handle_error/1,2,3` family reduce to thin wrappers (or delegate outright); REPL's deprecated `format_error/2` deleted.
- One user-visible dialect chosen (recommended: `error: <context>: <message>`, lowercase, no inspect-quotes) and applied across unknown-command, parse-error, command-error, and enhanced-error paths; the command-not-found suggestion block keeps its extra lines.
- Kill inspect-artifacts in user output (`"Key not found"` quotes from `get_setting` and `cfg.get`).
- Debug mode appends the structured debug block exactly as today.
- Tests: golden-style assertions on each error path's first line; no path emits a second dialect.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-08` heading (single source of truth). Do not restate ACs here.

## Dependencies

- WP-01 (touches the same dispatch/else clauses; sequence after).
