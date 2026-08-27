---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
wp_id: WP-05
title: "History and REPL integrity"
scope: Small
status: Done
---

# WP-05: History and REPL integrity

## Objective

History must degrade the way its error handling claims to, and non-interactive paths must be strict. Findings: A5, A7, C8, C9 (history_size leg), C14.

## Deliverables

- Replace illusory `try/rescue` around `GenServer.call` with exit-aware handling (`try/catch :exit` or a `whereis` guard) in all five History client wrappers and the same-pattern call sites (`cli_status`, `sys_flush`); the documented `{:error, :history_not_available, ...}` returns become real.
- Enforce `history_size` (default 100): History trims on push; setting read from config.
- Fix `should_push?` substring matching: exact first-token match against the non-history command set.
- Strict non-interactive execution: `cli.script` and `cli.redo`/`redo` bypass fuzzy matching (exact commands only); fuzzy matching remains a REPL-prompt convenience. Script executor gains stop-on-error default now that WP-01 gives it a real failure signal (flag to continue: `--keep-going`).
- Cover the latent REPL crashes: 3-tuple error clause in `repl/3`'s else and in `eval_for_redo`.
- Tests: killed History process yields the documented error tuple (not a crash); history bounded at configured size; `settings.get help_url` lands in history; script with a typo'd command fails instead of running a different command.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-05` heading (single source of truth). Do not restate ACs here.

## Dependencies

- WP-01 (stop-on-error needs the status signal).
