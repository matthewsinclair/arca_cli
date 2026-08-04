---
verblock: "04 Aug 2026:v0.1: matts - Initial version"
wp_id: WP-07
title: "Dead code purge and dependency prune"
scope: Small
status: Not Started
---

# WP-07: Dead code purge and dependency prune

## Objective

Delete the machinery that provably does nothing, so the surviving code is the system. Findings: B1-B10, C10.

## Deliverables

- Delete the dead config-callback subsystem (`load_config_phase`, `register_config_callbacks`, `handle_config_change`, `apply_display_settings`, `register_specific_callbacks`) and the `Multiplyer.Config.Server` reference. (If WP-06 makes cli.debug load persisted settings at startup, keep exactly the minimal loader it needs -- built fresh, not this subsystem.)
- Delete the seven legacy unregistered command modules (Flush, Get, History, Redo, Status, Sys, Settings) and the example SubCommand/OneCommand pair (move the example into docs); changelog maps each to its registered replacement.
- Delete the unused ErrorHandler location macros + `__using__`.
- Delete the `REPL_MODE` branches (application start + runtime.exs) or wire the flag properly from `ReplCommand` -- decide with hv; recommended: delete, revisit file-logging as its own feature if wanted.
- Delete `:is_repl_mode`, `use OK.Pipe` (both sites), commented-out blocks, vestigial `intro/2` params.
- Prune deps: remove `table_rex`, `pathex`, `elixir_uuid`, `ucwidth`, `certifi`, `castore`, `dotenv`, and `:ok` unless a real usage is found at removal time (`mix xref` check per dep before deletion).
- Remove or deprecate Utils HTTP residue (`form_encoded_body`, `parse_json_body`, `fetch_body`, `decode_json`) -- public API, so deprecation note in changelog; `form_encoded_body`'s missing URL-encoding documented as the reason it must not be used.
- mix.exs hygiene: drop the no-op `mix_tasks:` project key and `ansi_enabled:` application key.
- Gate: full suite green after every deletion batch; `mix xref graph` sanity check.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-07` heading (single source of truth). Do not restate ACs here.

## Dependencies

- Best sequenced after WP-01..WP-06 land (deletions shrink their conflict surface only if done first, but the safer order is fixes-then-purge so nothing half-dead is being edited).
- Decisions needed from hv: REPL_MODE delete-vs-wire; deprecate-vs-delete for public Utils/commands.
