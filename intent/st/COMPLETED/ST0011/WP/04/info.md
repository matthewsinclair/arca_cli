---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
wp_id: WP-04
title: "Pure renderers: one style detector, correct io"
scope: Small
status: Done
---

# WP-04: Pure renderers: one style detector, correct io

## Objective

Rendering must never change what a command DOES, and the output medium must get the right bytes: unicode content survives pipes, ANSI decoration does not. Findings: A6, A12, C7, C13.

## Deliverables

- Spinner/progress purity: `{:spinner, label, fun}` / `{:progress, label, fun}` executed in the COMMAND layer (or at Ctx build time) with the result stored; renderers only draw. All styles produce the same side effects. Breaking change documented for downstream Ctx users.
- One style detector: `Output.determine_style/1` is the single authority; `AnsiRenderer.check_tty` deleted; `main/1`'s unconditional `ansi_enabled: true` removed -- ANSI on TTY only (honouring NO_COLOR / ARCA_STYLE as today).
- Escript unicode io: set stdio encoding (escript `emu_args` or `:io.setopts`) so emoji/unicode print correctly on TTY and piped.
- Dedupe Ansi/Plain shared logic (table option wrangling, `remove_header_lines`, `safe_to_string`) into one helper; fix drift: `{:list, items}` 2-tuple parity, `{:json, ...}` added to `Ctx.output_item` type and `Ctx.to_string`.
- Tests: piped output contains no ANSI escapes and intact UTF-8; spinner side effect observable under plain and json styles.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-04` heading (single source of truth). Do not restate ACs here.

## Dependencies

- WP-01 (shares `main/1` surgery; sequence after to avoid conflict).
