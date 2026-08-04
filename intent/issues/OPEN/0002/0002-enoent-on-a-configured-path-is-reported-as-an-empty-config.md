---
id: "0002"
title: "enoent on a CONFIGURED config path is reported as an empty config, not a bad path"
date: 2026-08-04
reporter: vc
status: OPEN
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

## Shipped anyway

Filed rather than blocking the 0.5.0 release: it fails no test, it is a narrower failure mode than the one 0.3.0 removed, and the fix is identified above. Recorded by vc under release control, 2026-08-04.
