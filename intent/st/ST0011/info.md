---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
intent_version: 2.18.0
status: WIP
slug: fable-review-of-arca-cli-base-code
created: 20260804
completed:
---

# ST0011: Fable review of arca_cli base code

## Objective

Turn the Fable full-codebase review of arca_cli into a materially better 0.5.0 release: fix every confirmed correctness failure (exit codes, --version, config coercion, renderer side effects, escript-broken commands), delete the dead machinery, and collapse the duplicated concerns -- so the breaking change bundled around issue 0001 pays for itself once.

## Context

Issue 0001 (every command exits 0) exposed a failure archetype: correctness information destroyed mid-pipeline. The Fable audit (2026-08-04, full read of all 55 lib/ files at ca7ba57, findings probe-verified) found the same archetype in 11 further confirmed places, plus 10 dead-machinery clusters and 15 design-debt items. The complete catalogue with file:line evidence and probe transcripts is in `design.md`. Remediation is organised as WP-01..WP-10; sequencing and open hv decisions are in `tasks.md`; the draft acceptance contract is in `acceptance.md` (awaiting hv ratification).

Baseline: 493 tests passing, 0 failures, no compile warnings, at ca7ba57.

## Acceptance

Acceptance Criteria and Acceptance Tests for this steel thread live in `acceptance.md` (the single source of truth). Do not restate ACs here -- see that file for the ratified completeness boundary and live status.

## Related Steel Threads

- ST0010: HEREDOC injection for cli.script (the script executor WP-05 hardens)
- intent/issues/OPEN/0001: exit-code issue that triggered the review (closed by WP-01 + WP-10)

## Context for LLM

This document represents a single steel thread - a self-contained unit of work focused on implementing a specific piece of functionality. When working with an LLM on this steel thread, start by sharing this document to provide context about what needs to be done.

### How to update this document

1. Update the status as work progresses
2. Update related documents (design.md, impl.md, etc.) as needed
3. Mark the completion date when finished

The LLM should assist with implementation details and help maintain this document as work progresses.
