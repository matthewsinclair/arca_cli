---
verblock: "04 Aug 2026:v0.3: Matthew Sinclair - Rewritten for ST0011 / 0.5.0"
---

# Session Restart Context

Context for starting a new session. Deliberately short: coding rules live in `CLAUDE.md` and the `in-*` skills, project structure in `AGENTS.md`, and the full ST0011 record in `intent/st/ST0011/`. This file holds what a new session needs that is not already written down elsewhere.

## Where the project is

**Arca.Cli** -- a CLI framework for Elixir applications (REPL, dot-notation commands, `.cli` scripts, help discovery). It is a library: downstream applications wrap `Arca.Cli.main/1` as their escript entry point, which is why `main/1` must keep halting.

**0.5.0 is built and verified, not released.** ST0011 sits at 57/57 acceptance criteria, fifteen work packages, 782 tests green against arca_config 0.3.0. `intent st done ST0011` and the `v0.5.0` tag are deliberately not run -- they wait on vc's verification and hv's release call.

Read `intent/wip.md` for status and `intent/st/ST0011/results.md` for what the thread found.

## Start here

1. Run `/in-session`. It loads the coding skills, releases the prompt gate, and picks up the whiteboard.
2. Read your node's board under `intent/whiteboard/<node>/` and your inboxes. The whiteboard is the live channel; `intent/wip.md` is the snapshot.
3. `intent ac status ST0011` -- the mechanical check that no finding was dropped.

## Project-specific rules

Beyond `CLAUDE.md` and the skills:

1. **NEVER run `iex`.** Prefer tests or `mix run -e`.
2. **NO BACKWARDS COMPATIBILITY CODE** unless specifically instructed. 0.x permits removal; the changelog carries a replacement map.

## Things that will cost you time if you do not know them

- **The escript is a separate artifact and goes stale silently.** Run `touch mix.exs && MIX_ENV=prod mix compile --force && mix escript.build` before believing any probe and before any release. Bumping `VERSION` alone does not rebuild it: `mix.exs` reads that file at project-load time and Mix does not track it as an input. This cost real time twice in ST0011, the second time from inside the test suite -- `cli_debug_persistence_test.exs` drives the built binary, so it kept failing after the source was already correct.
- **`config/.env` holds live secrets and is gitignored.** `config/dotenv.exs` calls `System.put_env/2` under `:dev` and `:test`, so it OVERWRITES `ARCA_CLI_CONFIG_PATH` from the parent environment. A child process cannot be steered by exporting that variable; set it inside evaluated code, after config evaluation.
- **`mix test` does not export `MIX_ENV`**, and Mix writes its build-lock notice to stdout interleaved with a child's output. Subprocess tests go through `test/support/cli_subprocess.ex`, which handles both. Do not hand-roll another `System.cmd("mix", ...)`.
- **The arca_config coupling is asserted, not remembered**: `test/arca_cli/config_contract_test.exs`. arca_cli tracks arca_config by git branch, so every call resolves at runtime and a rename over there produces no compiler error here -- it produces a crash in a user's terminal after `mix deps.update`. New coupling goes in that file.
- **arca_cli and arca_config always ship together** (hv). The pair moved to arca_config 0.3.0 in WP-15.

## Working agreements

- Steel threads and work packages are created and closed through the `intent` CLI, **never by hand** -- no `mkdir` under `intent/st/`, no hand-edited `status:` fields. `intent wp done` enforces an acceptance close-gate.
- Every confirmed finding owns a ledger row in `tasks.md` AND a covering acceptance criterion. Prose is not a record.
- On the whiteboard you write only your own node's directory. **Commit with an explicit pathspec, never `git add intent/`** -- that sweeps other nodes' in-progress work, which happened once in ST0011.
