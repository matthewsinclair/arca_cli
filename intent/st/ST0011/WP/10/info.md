---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
wp_id: WP-10
title: "Docs, changelog, and 0.5.0 release"
scope: Small
status: Done
---

# WP-10: Docs, changelog, and 0.5.0 release

## Objective

Ship 0.5.0 with documentation that matches the as-built system and a migration note for every breaking change.

## Deliverables

- CHANGELOG: every WP's user-visible change, breaking changes flagged, deleted-module -> replacement map (WP-07), Laksa-facing note: exit codes now real, `Ctx.complete(:error)` now means what it says.
- Exit-code contract documented (user guide + reference guide + deployment guide): 0 success/warning, 1 failure; embedding guidance (`run/1` vs `main/1`).
- Fix doc lies found in audit: BaseCommand snake_case example (`GetDataCommand`/`:get_data`) either supported by WP-06 dispatch work or the doc corrected to the real constraint; BaseSubCommand `@sub_commands` doc; `cli_command_helper` nonexistent-command examples; typos (implementaiton, numver, coammd).
- VERSION -> 0.5.0; `intent issues close 0001` with Resolutions section pointing at this ST; `intent st` docs updated (`impl.md` as-built notes).
- Final gate: full suite green; escript smoke run of the E1-E8 probe set from `design.md` with expected-new outcomes recorded in `impl.md`.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-10` heading (single source of truth). Do not restate ACs here.

## Dependencies

- All prior WPs (WP-09 inclusion per hv scope ruling).
