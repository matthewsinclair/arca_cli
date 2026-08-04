---
verblock: "04 Aug 2026:v0.2: matts - As-built"
wp_id: WP-15
title: "Absorb the arca_config 0.3.0 error contract"
scope: Small
status: Done
---

# WP-15: Absorb the arca_config 0.3.0 error contract

## Objective

Take the arca_config 0.3.0 dependency bump and absorb its new error contract, so failures read as sentences to a person rather than as Elixir terms. Closes A32, A33 and A34.

## Deliverables

- `arca_cli.ex` `setting_error/2` -- matches `{:config, :not_found, _}` on the atom. The clause that classified a missing key by testing whether the message contained the words "not found" is deleted.
- `arca_cli.ex` `config_reason/1` -- one place that renders an arca_config failure for a person, delegating to `Arca.Config.Error.message/1`. Replaces `reason_text/1`, which did a subset of the same job.
- `arca_cli.ex` `load_settings/0` -- an absent configuration file reports `{:ok, %{}}` rather than an error, and the config-shaped error is rendered without a second prefix.
- `config_diagnosis_test.exs` -- a "states the reason once" assertion per command.

## Acceptance

Acceptance Criteria for this work package live in the steel thread's `acceptance.md`, under the `WP-15` heading (single source of truth). Do not restate ACs here.

## As built

**A32 -- arca_config's reasons became tuples, and we printed them at users.** 0.3.0 ratified one error shape, `{:error, {:config, reason, detail}}`, with `Arca.Config.Error.message/1` as the renderer. Anywhere arca_cli interpolated a reason straight into a message now printed a raw term: `settings.get nosuchkey` answered `cannot read setting nosuchkey: {:config, :not_found, ["nosuchkey"]}`.

Worth recording that arca_config's own rationale names this repository as the reason the type exists:

> our downstream CLI genuinely does `String.downcase(reason) =~ "not found"`, which means rewording a message was a silent breaking change to its behaviour

That was `arca_cli.ex:1108-1113` and it is now gone, replaced by a match on the atom. `Arca.Config.Cache` still answers a bare `:not_found` deliberately -- "not cached" is not the claim "no such key" -- so that clause stays.

**A33 -- a fresh install warned on every command.** Before the bump a missing config silently fell back to a different config and reported success; that was a real defect and arca_config's WP-04 removed it. After the bump a missing config reports `:enoent`, which is correct -- but `run/1` loads settings for every command, so every invocation on a fresh install printed a warning about an entirely normal state.

An absent configuration file is not a failure. A fresh install has no settings yet and "there are none" is the honest answer, so `load_settings/0` reports `{:ok, %{}}`. Nothing is swallowed: a config that EXISTS and cannot be parsed still fails loudly carrying its reason, which is the A29 case, and its tests drive it with an unparseable file rather than a missing one.

**A34 -- I introduced this one and the suite could not see it.** `Arca.Config.Error.message/1` renders a complete phrase including its own prefix. Wrapping that in ours printed the sentence twice: `failed to load configuration: failed to load configuration: Error parsing config at position: 2`.

The A29 tests drive a corrupt config through exactly this path and stayed green, because they assert that the reason *appears* -- and a doubled message still contains the reason. **Third time today an assertion has been satisfied by the malformed output it was meant to reject.** Found by escript probe, not by the suite.

## Verification

- 782 green across seeds 1/11/555 against arca_config head; `--check-formatted` and `--warnings-as-errors` clean; 57/57 AC. Independently reproduced by hv at the same count on the same dep.
- Escript probe over the three config states: absent (exit 0, silent), missing key (exit 1, one dialect line), unparseable (exit 1, reason stated once).
- The "reason once" tests proven to discriminate: restoring the double prefix turns exactly the two rows red.
- **The escript is the thing to rebuild.** `cli_debug_persistence_test.exs` drives the built binary, so it kept failing against a stale escript after the source was already correct. The release trap, inside the suite this time.

## Dependencies

- The arca_config 0.3.0 bump. `mix.lock` moved `8b30615` -> `03969fa`. This WP is the only one in ST0011 that depends on it.
