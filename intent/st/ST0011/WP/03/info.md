---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
wp_id: WP-03
title: "Configurator truthfulness: honour config, fail loudly"
scope: Small
status: Done
---

# WP-03: Configurator truthfulness: honour config, fail loudly

## Objective

Configuration that is set must take effect; configuration that is broken must fail loudly. Findings: A4, C3, C2 (collision policy leg).

## Deliverables

- Fix the `|| true` coercions in `BaseConfigurator.__before_compile__` for `allow_unknown_args` and `parse_double_dash` (same nil-only-default treatment the `sorted` fix already has).
- Coordinator: configurator setup failure raises (or exits non-zero with a clear message) instead of silently substituting `DftConfigurator`'s command set.
- Duplicate command names across configurators: pick ONE policy (recommended: last-registered wins in BOTH Optimus config and dispatch) and enforce it in `handler_for_command` so parse and dispatch cannot disagree; upgrade the duplicate warning to include the winner.
- Tests: explicit-false configurator options observable in `config/0` and in Optimus behaviour; broken configurator surfaces an error; duplicate command resolves to the same module in parse and dispatch.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-03` heading (single source of truth). Do not restate ACs here.

## Dependencies

- None (parallel-safe with WP-01/WP-02).
