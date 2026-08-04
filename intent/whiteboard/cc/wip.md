---
node: cc
name: Control Claude
role: control
session_id: 73036f8b-63e9-4bf1-8d44-40bf1a20a17e
heartbeat_at: 2026-08-04T20:20Z
status: paused
focus: "ST0011 57/57, 782 green on arca_config 0.3.0; vc has the pen on the release"
claims: [ST0011]
---

# Control Claude (cc)

## DOING

- Nothing. ST0011 is at 57/57, fifteen WPs Done, issue 0001 closed, 782 green
  against arca_config 0.3.0, no OPEN ledger rows, working tree clean.
- **vc has the pen.** It is verifying the release now. `intent st done ST0011`
  and the `v0.5.0` tag are not run: vc's sign-off, then hv's release call.

## TODO

- Nothing owed by this node. If vc returns findings, they are fixed from here.
- Open with vc, both its call: its harness wants a BADCFG row (config present but
  unparseable -- fires on both pins), and its artifact header stamps "A29 rows
  CANNOT fire" on pinned runs, which is false for that trigger.

## Watch-outs

Durable only. WP-specific ones are archived with the work.

- **The escript is a separate artifact and goes stale silently.** `touch mix.exs
  && MIX_ENV=prod mix compile --force && mix escript.build` before believing any
  probe and before any release. Bumping `VERSION` alone does not rebuild it. This
  bit twice, the second time from *inside* the suite:
  `cli_debug_persistence_test.exs` drives the built binary, so it kept failing
  after the source was already correct.
- `config/.env` is gitignored, holds live secrets, and `config/dotenv.exs` calls
  `System.put_env/2` under :dev and :test -- so it OVERWRITES
  `ARCA_CLI_CONFIG_PATH` from the parent environment and a child cannot be
  steered by exporting it. Set it inside evaluated code, after config evaluation.
- The arca_config coupling is asserted in `test/arca_cli/config_contract_test.exs`
  -- **add new coupling there, not to this list.**
- `handle_args/3` is shared by one-shot AND REPL paths; the string-returning
  adapters over `dispatch_args/3` are what keep the REPL working.
- Tests call `Arca.Cli.run/1`, never `main/1`: `main/1` halts and kills the test
  VM. Downstream wraps `main/1`, so the halt must stay there.
- Renderers must not execute anything. Deferred work resolves in
  `Ctx.add_output/2`, with `Ctx.resolve_output/1` as the safety net.
- Subprocess tests go through `test/support/cli_subprocess.ex`. `mix test` does
  NOT export MIX_ENV, and Mix writes its build-lock notice to stdout.
- **The environment of a test run is not an input to it.** Pin `:max_width` on
  any test reading positions out of a rendered line; run piped AND under a pty.
- Global state is shared across test modules (History, Arca.Config, app env), so
  a test asserting a count must establish the count it starts from.
- zsh does not word-split unquoted vars, and `grep --include=*.ex` needs quoting.
- `vc/` shows modified when vc clears my messages or when I run its harness.
  **Commit with an explicit pathspec, never `git add intent/`** -- I swept vc's
  in-progress probe scripts into `952667d` doing exactly that.
- Nothing is "remembered" in prose: every confirmed finding owns a ledger row AND
  an AC. `intent ac status` is the mechanical check.

## Decisions

**Migrated to the permanent record: `intent/st/ST0011/results.md`.** The thread's
durable findings -- the three archetypes, the one shape and its instances, and
what it learned about building and about claiming -- belong to the steel thread
rather than to this board. Read that file, not a copy here.

Live coordination state only, below.

- (2026-08-04) hv: arca_cli and arca_config **always ship together**. That closes
  the branch-dep-under-tag question, which was also wrong on its own terms --
  `mix.lock` is tracked, so a tag ships pinned to a SHA.
- (2026-08-04) hv: arca_notionex is out of scope, "literally nothing uses that".
  Nothing here references it, and its own lock pins a fixed SHA, so a release
  cannot reach it without a deliberate `deps.update` there.
- (2026-08-04) hv: one deps bump, everything together. Done -- arca_config 0.3.0
  is in, and WP-15 absorbed its new error contract.
- (2026-08-04) vc PASSed WP-01..12 on its own independent evidence. WP-13, WP-14
  and WP-15 are claimed and with vc now. ST-level sign-off is hv's.
