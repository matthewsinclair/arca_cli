---
verblock: "04 Aug 2026:v0.7: Matthew Sinclair - ST0011 complete, awaiting release sign-off"
---

# Work In Progress

## Current Status

**ST0011 -- Fable review of arca_cli base code: COMPLETE, awaiting release sign-off (2026-08-04)**

Fifteen work packages, 57/57 acceptance criteria PASS, 782 tests green. Built and verified against arca_config 0.3.0. `VERSION` is 0.5.0.

Deliberately NOT done: `intent st done ST0011` and the `v0.5.0` tag. Sign-off is vc's verification plus hv's release call.

### What ST0011 was

A full-codebase audit of `lib/` turned into a breaking 0.5.0. It found three recurring loss archetypes rather than a list of bugs, and the release fixes the archetypes:

1. **Outcomes discarded in transit** -- every command exited 0, because failure was returned as display text that dispatch could only read as success.
2. **Configuration read but not honoured** -- an explicit `false` coerced to `true`; a broken configurator silently swapped for the default one.
3. **Environment-dependent behaviour** -- ANSI forced into pipes, test-env branches in `lib/`, output that depended on terminal width.

34 confirmed correctness findings (A1-A34), 10 dead-machinery clusters, 15 design-debt items. Every finding owns a ledger row and a covering acceptance criterion; `intent ac status ST0011` is the mechanical check that none was dropped.

### Work packages

| WP | Title                                                      | Status |
| -- | ---------------------------------------------------------- | ------ |
| 01 | Exit codes: propagate command outcome to the OS            | Done   |
| 02 | Version truth: single source and working --version         | Done   |
| 03 | Configurator truthfulness: honour config, fail loudly      | Done   |
| 04 | Pure renderers: one style detector, correct io             | Done   |
| 05 | History and REPL integrity                                 | Done   |
| 06 | Command hygiene: Ctx API, sys.cmd, dev.*, cli.debug        | Done   |
| 07 | Dead code purge and dependency prune                       | Done   |
| 08 | One error-formatting pipeline                              | Done   |
| 09 | Remove test-env branching from lib                         | Done   |
| 10 | Docs, changelog, and 0.5.0 release                         | Done   |
| 11 | Closing batch: A13 residue, renderer dialect, width pins   | Done   |
| 12 | One predicate for Ctx failure                              | Done   |
| 13 | Config load diagnosis survives to the user                 | Done   |
| 14 | Pin the arca_config contract                               | Done   |
| 15 | Absorb the arca_config 0.3.0 error contract                | Done   |

WP-12 through WP-15 all landed *after* the thread first looked finished: three were found by vc verifying a PASS, one was the dependency bump. That is the most useful thing this thread says about itself.

### Issue 0001

Closed. "Every command exits 0" was the presenting symptom of archetype 1. Reproduction re-verified against the built escript.

## What is next

1. **vc verifies the release.** WP-13, WP-14 and WP-15 are claimed and unverified. vc owns the deps-bump harness at `intent/whiteboard/vc/probes/`.
2. **`intent st done ST0011`** once vc signs off.
3. **Tag v0.5.0** -- hv's call. The tag is reproducible as-is: `mix.lock` is tracked, so it ships pinned to a SHA.

## Notes for whoever picks this up

- **The escript is a separate artifact and goes stale silently.** Run `touch mix.exs && MIX_ENV=prod mix compile --force && mix escript.build` before believing any probe and before any release. Bumping `VERSION` alone does not rebuild it. This cost real time twice, once from inside the test suite.
- **A green suite cannot tell you whether anything reaches the code it tests.** It answers "does this work", never "does anything get here". Most of this thread's findings were variations on that one point.
- **The dependency contract is asserted, not remembered**: `test/arca_cli/config_contract_test.exs`. New coupling to arca_config goes there, not into a prose list.

## Context for LLM

This document is the project-level snapshot. The live cross-session channel is `intent/whiteboard/`, one directory per node; `intent/st/ST0011/` holds the full contract, ledger and as-built record.
