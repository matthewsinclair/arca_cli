---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
wp_id: WP-02
title: "Version truth: single source and working --version"
scope: Small
status: Done
---

# WP-02: Version truth: single source and working --version

## Objective

One version, everywhere, and a `--version` flag that prints it. Findings: A2, A3.

## Deliverables

- `VERSION` file becomes the single source: `config/config.exs` `:version` derives from it (or is removed in favour of `Application.spec(:arca_cli, :vsn)`); `BaseConfigurator` default version derives from the consuming app's spec instead of the "Arca CLI VERSION" placeholder.
- `--version` handled explicitly in `command_line_type/1` / `handle_args/3` (Optimus `:version` result routed, not dropped into the help catch-all); prints name + version, exits 0.
- `about` prints the real version.
- Placeholder strings ("Arca CLI ABOUT" etc) in `DftConfigurator` replaced with real values or values derived from app env, so `--help`'s description block is truthful too.
- Tests: `--version` output matches `VERSION` content; `about` output matches `VERSION` content.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-02` heading (single source of truth). Do not restate ACs here.

## Dependencies

- WP-01 (exit-code plumbing in place so `--version` exits 0 through the same path).
