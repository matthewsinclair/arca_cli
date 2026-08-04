---
id: "0002"
title: "enoent on a CONFIGURED config path is reported as an empty config, not a bad path"
date: 2026-08-04
reporter: vc
status: CLOSED
severity: medium
---

# 0002: enoent on a configured config path is reported as an empty config, not a bad path

## Tags

config, silent-failure, diagnosis, arca-config-0.3.0, release-0.5.0

## Summary

`Arca.Cli.load_settings/0` maps `{:error, {:config, :load_failed, :enoent}}` to `{:ok, %{}}` unconditionally (WP-15, `dadcb07`). A user who mistypes `ARCA_CLI_CONFIG_PATH` is therefore told their configuration is empty rather than that their path does not exist.

Measured on the 0.5.0 release build (`952667d`) against arca_config `5db55a4`, with `ARCA_CLI_CONFIG_PATH` pointing at a directory that does not exist:

```
cfg.list      exit=0  ^error:=0   "No configuration settings found."
settings.all  exit=0  ^error:=0   "⚠ No settings available"
```

Found by the deps-bump behaviour harness (`intent/whiteboard/vc/probes/`), not by the suite. The suite is 782 green either way -- no test drives this path.

## Why the current behaviour exists, and why it is not simply wrong

`run/1` loads settings for **every** command, so without that clause every invocation on a fresh install printed a warning about an entirely normal state. arca_config's ruling R4 says a missing file *is* an empty config for the first-run bootstrap caller. A config that exists and cannot be parsed still fails loudly carrying its reason, so finding A29 is not reopened by this.

It is also **strictly better than 0.4.x**, which on the same input exited 0 while printing a *different* config than the one asked for -- the silent CWD fallback that arca_config's WP-04 removed.

## Why it should still be fixed

`enoent` on a path the user explicitly named and `enoent` on the default path are different events, and **arca_config 0.3.0 already distinguishes them**. `Arca.Config.Cfg.config_location/0` returns:

```elixir
source: %{path: path_source, file: file_source}
```

(`arca_config/lib/config/cfg.ex:305-316`) -- built as AC-02.3 precisely so a consumer can tell where a resolution came from. The current clause discards a distinction that was deliberately provided.

This is the shape of finding A22, which cost this project a day: test isolation set an environment variable across nine files and silently never took effect, because the value was being resolved from somewhere else and nothing said so.

## Proposed fix

Treat enoent as an empty config **only when the location came from the default**, and report it when the user named the path:

- `source.path` is the default and the file is absent -> `{:ok, %{}}`, silent, first-run bootstrap
- `source.path` came from an environment variable or application config and the file is absent -> `{:error, ...}` naming the path that was configured and not found

Needs an AT that drives a *configured but nonexistent* path and asserts the reason reaches the user, distinct from the existing fresh-install case. The behaviour harness's `MISSCFG` rows (invariant D3) already assert the failing half and currently report 2 failures against the release build; they will go green when this lands.

## Evidence

- Report: `arca_config/intent/st/ST0002/vc-rebuild-report.md`, section "The one thing I would not ship silently"
- Harness: `intent/whiteboard/vc/probes/`, artifact `artifacts/release.behaviour.txt`, rows `MISSCFG`
- Reproduce: `intent/whiteboard/vc/probes/run.sh capture <label>` then `run.sh assert <label>`

## Resolution -- FIXED, 2026-08-04

Fixed rather than shipped. `Arca.Cli.load_settings/0` now routes an absent config through `absent_config_outcome/0`, which asks `Arca.Config.get_config_location/0` where the location resolved from:

- `source` is all-`:default` -> `{:ok, %{}}`, silent. Nobody named a location, so there is nothing to be wrong about, and `run/1` loads settings for every command.
- anything else -> `{:error, "configuration file not found: <path>"}`, naming the file the user actually configured.

The unreadable-location clause is deliberately lenient (answers empty, not error) and says why in the code: wrongly erroring breaks **every** command on a fresh install, while wrongly reporting empty costs one vague message. That asymmetry is the reason, not a preference for silence.

**Coverage, proven to discriminate.** Two tests in `test/arca_cli/config_diagnosis_test.exs`, describe "an absent config: fresh install vs a path nobody has", each driving a real subprocess. Mutation tested with the failing set predicted before the run: restoring the blanket `{:ok, %{}}` turns **exactly one** test red -- the configured-path one -- and it goes green again on restore.

**Verified by the harness that found it.** `intent/whiteboard/vc/probes/`, capture `issue-0002-fixed`, asserted at the strict `after` phase: **ASSERT: PASS**, D3 included. Before the fix the same gate reported 2 failures on the same rows. Suite 784 green (was 782, +2), ctx matrix PASS, ST0011 contract 57/57.

    MISSCFG  cfg.list      exit=1  ^error:=1  "configuration file not found: <path>/config.json"
    MISSCFG  settings.all  exit=1  ^error:=1  "configuration file not found: <path>/config.json"

A29 is unaffected: a config that exists and cannot be parsed still fails carrying its parse position.

Closed by vc under release control, 2026-08-04.
