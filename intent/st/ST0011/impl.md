# Implementation - ST0011: Fable review of arca_cli base code

## Implementation

Status: WP-01 complete. WP-02..WP-10 not started.

### WP-01 as-built -- exit codes (issue 0001)

The shape is a status-carrying core with display-only adapters over it, so nothing downstream or in the REPL had to change:

- Every function named `dispatch*` returns `{outcome, output}`: `dispatch/3`, `dispatch_args/3`, `dispatch_subcommand/4`, `dispatch_command_help/2`. `outcome` is `:ok | :error | :warning`.
- `parse_command_line/3`, `handle_args/3`, `handle_subcommand/4` and `handle_command_help/2` are now one-line adapters (`dispatch*(...) |> elem(1)`) keeping their historical string-returning contracts. The REPL calls `handle_args/3` and was untouched.
- `execute_command/5` returns `{:ok, outcome, output}` on success (error tuples unchanged). This is a breaking change to a public function -- it needs a CHANGELOG entry in WP-10.
- `process_command_result/3` folds the context status in, making `Ctx.complete/2` load-bearing for the first time. `ctx_outcome/1` takes an explicit status when set, and otherwise treats a context carrying errors as a failure rather than a success.
- `Arca.Cli.run/1` is the new pure entry point: parses, dispatches and displays exactly as before, returns the outcome, never halts.
- `Arca.Cli.main/1` is now `argv |> run() |> halt_for()`. `halt_for/1` halts with 1 on `:error` only; `:ok` and `:warning` return normally so the escript exits 0 through normal shutdown. This satisfies AC-01.3 ("halts only for non-`:ok`") while leaving the success path byte-identical for embedders.
- The dead error branches at `arca_cli.ex:294-311` are deleted, as is the duplicated USAGE-line rewriting (extracted to `rewrite_usage_app_name/2`).
- `cli.error` gained `ctx` and `warning` modes so the context status channel is exerciseable from the shell, not just from tests.
- `lib/arca_cli/testing/cli_command_helper.ex` ran commands through `main/1`; switched to `run/1`, since it executes inside the host test VM.
- 22 in-repo test call sites migrated from `main/1` to `run/1`. `Eg.Cli` keeps `main/1 -> Arca.Cli.main/1` (it documents the downstream escript pattern) and gained a `run/1` passthrough for in-VM tests.

Verification: 520 tests pass (was 493 at `ca7ba57`), no compile warnings under `--warnings-as-errors`. 7 of the 11 repro commands now exit correctly; the remaining 4 are finding A13, assigned to AC-08.3 / AC-05.4 / AC-06.2.

### WP-02 as-built -- version truth

- `VERSION` is the single source. `config/config.exs`'s hardcoded `version: "0.1.0"` is deleted; `Arca.Cli.version/0` reads an app-configured `:version` when one exists and otherwise resolves `Application.spec(:arca_cli, :vsn)`, which mix generates from `VERSION`. No hardcoded fallback -- a string that can drift is worse than none.
- `BaseConfigurator` resolves an undeclared `:version` from the app spec at runtime via the new `app_version/1`, so a downstream configurator reports its own app's version rather than a placeholder.
- `DftConfigurator`'s four placeholder strings are gone; branding now comes from app config via `Application.compile_env/3`, and `:version` is deliberately not declared so the app-spec default applies.
- `dispatch_args/3` gained a `:version` clause. Optimus reports `--version` as a bare atom, which previously fell through the catch-all into the help screen.
- Three tests and one golden fixture asserted `arca_cli 0.1.0` -- they were pinning the defect. They now read `VERSION` at compile time (the fixture uses the framework's digit pattern), so a release bump does not falsify them.

### WP-03 as-built -- configurator truthfulness

- The `|| true` coercions are gone. Defaults now live in exactly one place: `config/2` records only what a configurator actually declared, and `__before_compile__` supplies defaults through `attribute_or_default/3`. Previously both sites carried defaults, which is what made an explicit `false` indistinguishable from unset.
- Unrecognised configurator options now raise a compile-time `IO.warn` instead of being silently dropped, so a typo cannot quietly disable an option.
- `Coordinator.setup/1` raises instead of falling back to `DftConfigurator`. The old fallback replaced the app's entire command set on any configurator error, producing a CLI that ran and did the wrong thing rather than one that refused to start.
- `handler_for_command/2` searches from the end of the command list, so dispatch resolves a duplicate command name to the same registration Optimus's last-wins merge picks. Parse and dispatch can no longer disagree about what a command means.
- `update_command_names/3` now appends rather than prepends. The accumulated list is read as registration order when reporting a duplicate, and prepending made its last element the *first* registration -- the "last registered wins" warning was naming the wrong module until this was fixed.

### WP-04 as-built -- pure renderers and correct io

- Spinner/progress purity (A6): `Ctx.add_output/2` now runs a `{:spinner, label, fun}`'s function when the item is added and stores `{:spinner, label, result}`. Renderers only draw. `Output.render/1` also calls the new `Ctx.resolve_output/1` as a safety net, so a context built as a struct literal can never hand a function to a renderer either. Resolving twice is a no-op, since a resolved item no longer holds a function.
- Plain and JSON renderers now show the spinner's *result*, not just its label -- previously the information existed only in ANSI output.
- One style detector (A12): `AnsiRenderer.check_tty/1` is deleted. It was a second, differently-written TTY check (TERM only) that could disagree with `Output.determine_style/1`, which is now the sole authority.
- Escript unicode (A12): `configure_io/0` sets `:io.setopts(:standard_io, encoding: :unicode)`. An escript's stdio defaults to latin1, which rendered any codepoint above 255 as literal `\x{...}` text.
- ANSI in pipes (A12): the fix was to *remove* `Application.put_env(:elixir, :ansi_enabled, true)`, not to replace it. The runtime already determines at boot whether stdout is a terminal and sets that flag correctly; the bug was overriding it unconditionally.
- `Output.tty?/0` is public and asks `:prim_tty.isatty(:stdout)`. Two rejected alternatives are recorded in its docstring: `TERM` is inherited by piped processes and so describes the launching terminal rather than the destination, and `:io.columns/1` reports `:enotsup` under `-noinput` even on a real terminal, which would have disabled colour everywhere.
- Renderer parity (AC-04.4): `{:list, items}` as a 2-tuple was ANSI-only and fell through the plain renderer's catch-all to `nil`; `{:json, ...}` was implemented in both renderers but missing from the `output_item` type. Both fixed, and a parity test now walks every item type against every style.

Five pre-existing renderer tests asserted the defect directly ("renders spinner with function execution"). They now assert the new contract: renderers receive resolved items and execute nothing.

### WP-05 as-built -- History and REPL integrity

- A5, real exit handling: `GenServer.call/2` to a dead or absent process *exits* the caller rather than raising, so the `try/rescue` in all five History clients could never catch it -- the documented graceful degradation never happened and the caller died instead. Since the REPL prompt asks for the history length on every redraw, a History crash took the whole session with it. All five now go through one private `call/3` using `catch :exit`, replacing five copies of an ineffective wrapper with a single working one.
- A5 cost: five near-identical try/rescue blocks collapsed into one helper -- the duplication is what let all five be wrong in the same way without anyone noticing.
- AC-05.2, bounded history: `history_size` (default 100, `config :arca_cli, history_size: n`) is enforced on push. The index is now tracked in state as `next_index` rather than derived from list length -- once history is full the length stops growing, so derived indices would repeat and `cli.redo` could no longer tell entries apart.
- AC-05.3, exact exclusion: `should_push?/1` matched the exclusion list with `=~`, dropping any command that merely *contained* `history`, `redo`, `flush` or `help`. `settings.get help_url` was never recorded. Now matches the first token exactly. The list form also joined arguments with `""` rather than `" "`, which manufactured matches out of adjacent words.
- A7 and the A13 `cli.script` leg: scripts and redo now use the new `Repl.eval_strict/3` -- exact command names, no fuzzy matching, no history push, and it returns `{outcome, output}`. Fuzzy matching stays a convenience of the interactive prompt, where a human can see the substitution. `cli.script` stops at the first failure unless `--keep-going`, and returns an error tuple so the outcome reaches the exit status.
- Escript re-probe: a script containing `abut` now prints `error: Unknown command: abut` and exits 1, where it previously ran `about` and exited 0. A missing script file exits 1.

Three pre-existing tests changed. Two asserted the old behaviour directly (a script continuing past failures, an unreadable file returning a display string); the third compared the whole History struct and so was disturbed by the new `next_index` field -- it now asserts the history itself.

### A14, found during WP-02

Rewriting the `about` golden fixture to use `{{\d+}}` (so it would stop breaking on version bumps) exposed that the pattern never worked. The replacement keys in `cli_fixtures_test.ex` were ordinary double-quoted strings, where `"\d"` is Elixir's DEL escape (0x7F) and `"\w"` silently drops the backslash -- so `String.replace` was looking for keys no fixture file could contain, and both patterns fell through to literal comparison. Verified directly: `byte_size("{{\d+}}") == 6`, and `"{{\w+}}" == "{{w+}}"`. Fixed with `~S` sigils; all five documented patterns now carry positive and negative cases. Same family as A9's inert `cli.debug`: documented behaviour that quietly does not happen.

Session 2026-08-04 (cc):

- Read all 55 files in `lib/` at `ca7ba57`. Catalogued findings in `design.md` as A (confirmed correctness failures), B (dead machinery), C (design debt).
- Verified findings by probe rather than by inspection alone -- 8 runtime probes under `mix run`, 8 escript probes against a freshly built `_build/escript/arca_cli`. Probe transcripts are in `design.md`'s Probe Appendix.
- One candidate finding was withdrawn after probing (P7: `Utils.decode_json` with map options works correctly).
- Elaborated WP-01..WP-10 with objectives, deliverables and a dependency DAG (`tasks.md`).
- Drafted the acceptance contract; hv ratified it in full along with all 7 open decisions on 2026-08-04.

## Code Examples

The halt boundary, kept as small as it can be so that everything above it stays pure and testable:

```elixir
@spec main([String.t()]) :: :ok | no_return()
def main(argv) do
  argv
  |> run()
  |> halt_for()
end

@spec halt_for(outcome()) :: :ok | no_return()
defp halt_for(:error), do: System.halt(1)
defp halt_for(outcome) when outcome in [:ok, :warning], do: :ok
```

The adapter pattern that let 462 existing tests and the REPL keep working while the outcome channel was threaded underneath them:

```elixir
# Canonical: carries the outcome
@spec dispatch_subcommand(atom(), map(), map(), term()) :: dispatch_result()
def dispatch_subcommand(cmd, args, settings, optimus) do
  with {:ok, handler} <- find_command_handler(cmd),
       {:ok, outcome, result} <- execute_command(cmd, args, settings, optimus, handler) do
    {outcome, result}
  else
    {:error, error_type, reason, debug_info} ->
      {:error, handle_error({:error, error_type, reason, debug_info})}

    {:error, error_type, reason} ->
      {:error, handle_error({:error, error_type, reason})}
  end
end

# Adapter: the historical display-only contract
def handle_subcommand(cmd, args, settings, optimus) do
  dispatch_subcommand(cmd, args, settings, optimus) |> elem(1)
end
```

Making `Ctx.complete/2` load-bearing, with a no-silent-errors fallback for contexts that carry errors but never called it:

```elixir
@spec ctx_outcome(Ctx.t()) :: outcome()
defp ctx_outcome(%Ctx{status: status}) when status in [:ok, :error, :warning], do: status
defp ctx_outcome(%Ctx{errors: [_ | _]}), do: :error
defp ctx_outcome(%Ctx{}), do: :ok
```

## Technical Details

Constraints discovered during the audit that bind the implementation:

- `handle_args/3` is shared by the one-shot dispatch path AND the REPL (`repl/repl.ex:599,615`). Its string-returning contract must survive as an adapter over any new status-carrying implementation (WP-01), or the REPL breaks.
- ~20 in-repo test call sites invoke `Arca.Cli.main/1` inside `capture_io`. These must migrate to the new pure `run/1` BEFORE `main/1` gains `System.halt`, or `mix test` kills its own VM.
- Downstream projects wrap rather than call directly: `Eg.Cli.main/1 -> Arca.Cli.main/1`, with the downstream project's own `escript: [main_module: ...]` (`test/arca_cli/eg/eg_cli_test.exs:14`). Laksa follows the same pattern. Halting must therefore live in `main/1` so downstream inherits correct exit codes from a dep bump alone.
- `main/1:294-311` error branches are unreachable: `handle_subcommand/4` and `handle_args/3` stringify every error upstream. Probed -- `parse_command_line/3` returns a plain String for every failure mode tested.
- The test suite currently depends on lib's `Mix.env()` branches (fabricated `settings.all` data, test-only display path in `main/1`, `:test_settings` app-env store). WP-09's purge therefore carries real test-rework cost; it is deliberately sequenced late.

## Challenges & Solutions

| Challenge                                                             | Resolution                                                                                     |
| --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Distinguishing real defects from plausible-looking ones                | Every A-finding backed by a runtime or escript probe; one candidate withdrawn when it passed     |
| Adding an outcome channel without breaking the REPL or 462 tests       | Status-carrying implementation + one-line string-returning adapters (Highlander-compliant)       |
| Making exit codes work downstream without forcing consumer code edits  | `main/1` halts (downstream already points at it); new pure `run/1` for tests and embedding       |
| zsh does not word-split unquoted vars -- first repro run was misleading | Re-ran with a shell function taking `"$@"`; corrected results recorded in the probe appendix     |
| Proving "display unchanged" rather than asserting it                    | Built a git worktree at `ca7ba57`, ran the same corpus through both checkouts, diffed (WP-01)    |
| The same zsh trap recurred while building that corpus harness           | Rewrote the harness as a bash script with `read -r -a`; the zsh run had passed multi-word commands as one argv entry |
| Test suite killed its own VM the moment `main/1` gained `System.halt`   | Predicted on the board; migrated 22 call sites to `run/1`, and the in-lib test helper with them  |

## AC-01.5 evidence -- halt does not truncate piped stdout

`System.halt/1` flushes pending IO before exiting (it is `:erlang.halt/1`, whose default options enable flushing), so no flush-safe variant was needed. Measured two ways.

Volume probe -- 50,000 lines then halt, under each redirection mode:

| Mode              | Lines expected | Lines observed | Exit |
| ----------------- | -------------- | -------------- | ---- |
| `cmd \| wc -l`    | 50000          | 50000          | 0    |
| `cmd \| wc -l` (halt 1) | 50000    | 50000          | 1    |
| `cmd > file`      | 50000          | 50000          | 1    |

Real escript, comparing byte counts against the unredirected run:

| Command                              | Bytes | Exit |
| ------------------------------------ | ----- | ---- |
| `arca_cli --help` (direct)           | 1025  | 0    |
| `arca_cli --help \| cat`             | 1025  | 0    |
| `arca_cli --help > file`             | 1025  | 0    |
| `arca_cli cli.error standard \| cat` | 62    | 1    |
| `arca_cli cli.error standard > file` | 62    | 1    |

No truncation in any mode, including the paths that halt with a non-zero status.

## AC-01.4 evidence -- display unchanged from 0.4.3

A worktree at `ca7ba57` and the current tree were each run over a 17-command corpus (the E-probe repro set plus the common success paths), same config dir, `NO_COLOR=1`, MIX_ENV=dev. The captures were diffed.

Result: zero differences in command output. The only diffs were the `exit=` markers, plus timestamps and stack-frame line numbers inside the `Logger.error` diagnostic that `cli.error raise` writes (an internal log line, not command output).

Exit-code deltas, all in the correct direction:

| Command                  | 0.4.3 | 0.5.0-dev | Verdict                    |
| ------------------------ | ----- | --------- | -------------------------- |
| `about`                  | 0     | 0         | unchanged                  |
| `--help`                 | 0     | 0         | unchanged                  |
| `help settings.all`      | 0     | 0         | unchanged                  |
| `settings.all`           | 0     | 0         | unchanged                  |
| `cli.error success`      | 0     | 0         | unchanged                  |
| `sys.info`               | 0     | 0         | unchanged                  |
| `help`                   | 0     | 1         | fixed (invalid subcommand) |
| `settings.get`           | 0     | 1         | fixed (missing argument)   |
| `cli.error standard`     | 0     | 1         | fixed                      |
| `cli.error legacy`       | 0     | 1         | fixed                      |
| `cli.error raise`        | 0     | 1         | fixed                      |
| `nosuchcommand`          | 0     | 1         | fixed                      |
| `help nosuchcommand`     | 0     | 1         | fixed                      |
| `settings.get nosuchkey` | 0     | 0         | finding A13 -> AC-08.3     |
| `cfg.get nosuchkey`      | 0     | 0         | finding A13 -> AC-08.3     |
| `cli.redo 999`           | 0     | 0         | finding A13 -> AC-08.3     |
| `cli.script /nonexistent`| 0     | 0         | finding A13 -> AC-05.4     |

## AC-01.4 re-baseline -- WP-06

Per the ratified clarification, the display corpus re-baselines at each WP whose ACs change output, and the diff is recorded here. WP-06 is such a WP: AC-06.1, AC-06.2 and AC-06.3 all require different output from 0.4.3.

A worktree at `828e20f` (the WP-05 close) and the current tree were each run over a 26-command corpus -- the previous 17 plus the WP-06 targets -- with the same config dir, `NO_COLOR=1`, MIX_ENV=dev, and the captures diffed after normalising log timestamps, stack-frame line numbers and the embedded version string.

Result: 18 of 26 command blocks byte-identical; 8 changed, every one of them a WP-06 target.

| Command                 | Changed | Why                                                                    |
| ----------------------- | ------- | ---------------------------------------------------------------------- |
| `about`                 | no      |                                                                        |
| `help`                  | no      |                                                                        |
| `help settings.all`     | no      |                                                                        |
| `settings.all`          | no      |                                                                        |
| `settings.get`          | no      |                                                                        |
| `settings.get nosuchkey`| no      |                                                                        |
| `cfg.get nosuchkey`     | no      |                                                                        |
| `cli.error standard`    | no      |                                                                        |
| `cli.error legacy`      | no      |                                                                        |
| `cli.error raise`       | no      |                                                                        |
| `cli.error success`     | no      |                                                                        |
| `cli.script /nonexistent`| no     |                                                                        |
| `cli.redo 999`          | no      |                                                                        |
| `nosuchcommand`         | no      |                                                                        |
| `help nosuchcommand`    | no      |                                                                        |
| `sys.info`              | no      |                                                                        |
| `cli.debug`             | no      |                                                                        |
| `cli.history`           | no      |                                                                        |
| `--help`                | yes     | one line: `dev.deps` about text now describes what it reports (AC-06.3) |
| `dev.info`              | yes     | table of facts readable in every deployment format (AC-06.3)           |
| `dev.deps`              | yes     | real loaded applications, not the mix dependency list (AC-06.3)        |
| `sys.cmd echo hello`    | yes     | the `{output, status}` tuple no longer printed after the output (AC-06.1) |
| `sys.cmd expr 1 + 1`    | yes     | `2` instead of `1 + 1` -- arguments no longer joined (AC-06.1)         |
| `sys.cmd false`         | yes     | names the exit status, exit 0 -> 1 (AC-06.2)                           |
| `sys.cmd nosuchbinary`  | yes     | one clean error, exit 0 -> 1 (AC-06.1, AC-06.2)                        |
| `sys.cmd`               | yes     | "no OS command given" instead of a `KeyError` stack trace (A15)        |

A note on the harness, because it cost time and will cost it again. `config/dotenv.exs` loads `config/.env`, which is gitignored, and that file sets `ARCA_CLI_CONFIG_PATH`. Being loaded during config evaluation, it overrides any value exported by the shell -- so the corpus harness's config isolation silently does not apply, and a fresh `git worktree` (which has no `config/.env`) resolves a different config path than the working tree. The first run of this comparison therefore showed a spurious `settings.all` difference. Both checkouts need the same `config/.env` for the comparison to mean anything.

## Escript gate -- WP-06

Rebuilt and re-run over the smoke set, from a scratch working directory so settings writes stay out of the repository:

| Command                | Exit | First line                                    |
| ---------------------- | ---- | --------------------------------------------- |
| `sys.cmd echo hello`   | 0    | `hello`                                       |
| `sys.cmd expr 1 + 1`   | 0    | `2`                                           |
| `sys.cmd ls -l -a`     | 0    | listing includes dotfiles, so `-a` took effect |
| `sys.cmd false`        | 1    | `✗ false exited with status 1`                |
| `sys.cmd nosuchbinary` | 1    | `✗ command not found: nosuchbinary`           |
| `sys.cmd`              | 1    | `✗ no OS command given`                       |
| `dev.info`             | 0    | reports `Deployment: escript`, no crash       |
| `dev.deps`             | 0    | reports `arca_config 0.2.0`, absent from the fabricated list |
| `cli.debug on`         | 0    | `Debug mode is now ON`                        |
| `cli.debug` (next run) | 0    | `Debug mode is currently ON`                  |

## AC-01.4 re-baseline -- WP-08

WP-08 changes error text by construction: AC-08.1 ratifies one dialect and AC-08.3 changes three commands from printing a message to reporting a failure. Corpus re-run against `65d253a` (the WP-06 close), 28 commands, same method as before.

Result: 17 blocks byte-identical, 11 changed -- every one of them an error path. No success path moved.

| Command                  | Was                                                              | Now                                                        |
| ------------------------ | ---------------------------------------------------------------- | ---------------------------------------------------------- |
| `nosuchcommand`          | `error: Unknown command: nosuchcommand`                          | `error: nosuchcommand: unknown command`                    |
| `sys`                    | `error: Unknown command: sys`                                    | + namespace listing (A16: previously unreachable)          |
| `sys.inf`                | `error: Unknown command: sys.inf`                                | + "Did you mean" block (A16)                               |
| `help nosuchcommand`     | `error: unknown command: nosuchcommand`                          | `error: nosuchcommand: unknown command`                    |
| `settings.get nosuchkey` | `Failed to get setting nosuchkey: "Key not found"`               | `error: settings.get: setting not found: nosuchkey`        |
| `cfg.get nosuchkey`      | `Failed to get setting nosuchkey: "Key not found"`               | `error: cfg.get: setting not found: nosuchkey`             |
| `cli.redo 999`           | `error: invalid command index: 999`                              | `error: cli.redo: no command at history index 999`         |
| `cli.error standard`     | `Error (invalid_argument): ...`                                  | `error: cli.error: ...`                                    |
| `cli.error legacy`       | `Error (command_failed): ...`                                    | `error: cli.error: ...`                                    |
| `cli.error raise`        | `Error (command_failed): Error executing command cli.error: ...` | `error: cli.error: ...`                                    |
| `cli.script /nonexistent`| `Error (script_not_readable): ...`                               | `error: cli.script: ...`                                   |

Two changes in that table are worth calling out because neither was in the plan.

The `sys` and `sys.inf` rows are finding A16. The suggestion machinery -- `find_similar_commands/1`, the "Did you mean" block, the namespace listing -- was unreachable. The unknown-command path called `handle_error/1` with a list, which takes the list clause; only the string clause consults the suggestions. The feature had unit tests and had never fired for a user. Routing the path through `handle_error(cmd, "unknown command", :command_not_found)` was needed for the dialect anyway, and lit it up as a side effect.

The `cli.error raise` row is smaller than it looks and larger than it looks. The dialect line changed once; but the `Logger.error` diagnostic that preceded it was on **stdout**, so the first line of a failed command was a stack trace, and a caller piping the CLI got log lines mixed into the data. That is finding A17, and it is the same defect family as A12: pipes must carry content, not diagnostics. Logger is now configured to stderr, which is what makes AC-08.1's "first output line" true for this path.

Evidence, from a scratch working directory, on the built escript:

    $ arca_cli cli.error raise 2>/dev/null
    error: cli.error: This is a test exception from CliErrorCommand
    $ arca_cli cli.error raise 2>&1 >/dev/null | head -1
    14:41:09.661 [error] Error executing command cli.error: %RuntimeError{...}

Moving Logger to stderr made log output visible in the test run, because ExUnit's stdout capture no longer intercepts it. `ExUnit.start(capture_log: true)` is the right answer: it holds log output per test and prints it only for a failing one.

## AC-08.3 evidence -- finding A13 closed

The three commands named in the AC, plus the two legs closed earlier, all exit non-zero at a real process boundary:

| Command                   | 0.4.3 | WP-08 | Leg closed in |
| ------------------------- | ----- | ----- | -------------- |
| `settings.get nosuchkey`  | 0     | 1     | WP-08          |
| `cfg.get nosuchkey`       | 0     | 1     | WP-08          |
| `cli.redo 999`            | 0     | 1     | WP-08          |
| `cli.script /nonexistent` | 0     | 1     | WP-05          |
| `sys.cmd false`           | 0     | 1     | WP-06          |

The shared root was one habit, not three bugs: a command that had already turned its failure into a display string had nothing left to report. Fixing the dispatch plumbing in WP-01 could not help, because there was no outcome to propagate.

## WP-09 as-built -- the environment branches, and what was hiding behind them

Twelve sites, removed in six steps with the suite green between each, so a red suite could only ever mean the step just taken.

| Site                                          | What it did                                       | Disposition                                    |
| --------------------------------------------- | ------------------------------------------------- | ---------------------------------------------- |
| `arca_cli.ex` `history_maybe_child_spec`      | skipped the supervisor when History was up        | deleted -- never fired (proven in WP-05)       |
| `arca_cli.ex` `config_available?`             | answered `true` under test without looking        | deleted -- other two branches were identical   |
| `arca_cli.ex` commented `check_initialization` | nothing                                           | deleted                                        |
| `arca_cli.ex` `display_response`              | printed everything under test                     | collapsed onto the production branch           |
| `arca_cli.ex` `load_settings`/`get`/`save`    | read and wrote `:test_settings` app env           | deleted -- settings go through Arca.Config     |
| `settings_all_command.ex` (x2)                | answered a fabricated "test/true" table           | deleted with `build_test_context`              |
| `output.ex` `test_env?`                       | forced plain when `MIX_ENV=test`                  | deleted -- never fired (A21)                   |
| `cli_fixtures_test.ex` (x2)                   | refused to eval `setup.exs` outside `:test`       | asks ExUnit whether a run is in progress        |

The ordering was the whole risk. Every one of these deletions is safe only once the test suite has a real configuration to read, so making the isolation genuine came first and nothing was deleted until it did. Steps 1 and 2 -- the branches proven dead -- then landed with **no test changes at all**, which is what makes "these never fired" a measurement rather than a claim.

### What the branches were concealing

Each removal exposed something the branch had been standing in front of.

- `config_available?` had three branches where two were byte-identical and the third guessed. Once the guess was gone, the capability check had to actually hold under test -- probed first, and it does: module loaded, function exported, server running.
- `display_response`'s test branch printed `{:nooutput, _}` responses, which production skips. That is `cli.script`'s success return, so the suite had been watching a display path no user has ever seen.
- Deleting `Output.test_env?` left one test ("uses plain style in test environment") passing for an entirely different reason -- TTY detection rather than the deleted rule -- which would have failed under a pty. A test that keeps passing after you delete what it covers is not evidence of anything.

### The isolation that was not

`Arca.Config.Cfg.config_pathname/0` resolves `ARCA_CLI_CONFIG_PATH` before `ARCA_CONFIG_PATH`, and `config/.env` sets the former. Every test setup in the suite set the latter. The block also wrote its config file into a directory that does not exist and dropped the `{:error, :enoent}`, and restored itself with `System.put_env(map)`, which cannot delete a variable that was previously unset. It appeared in nine files and did nothing in all nine.

It is now done once, in `test_helper.exs`, with `Arca.Config.switch_config_location/1` -- which re-points the already-booted server *and* sets the app-specific variables, so subprocesses inherit the same location instead of reaching for the repository's tracked config.

### The subprocess harness (A23)

`mix test` does not export `MIX_ENV`. The children therefore ran in `:dev` against `_build/dev` -- and with `_build/dev` moved aside, **5 of 16 failed**. The shape of that failure is the point:

| Assertion class      | Child cannot start | Reads as        |
| -------------------- | ------------------ | --------------- |
| `assert exit == 1`   | still passes       | correct failure |
| `assert exit == 0`   | fails              | CLI defect      |

So a broken harness looks like a product bug, and half the suite goes on passing for a reason unrelated to the CLI. The three files now share one runner (`test/support/cli_subprocess.ex`) that pins `MIX_ENV`, scrubs `ARCA_STYLE`/`NO_COLOR` so ambient state cannot decide what a child prints, and fails loudly with "harness failure" when the child never reached the CLI. One test asserts the child's `--version` output exactly, so the harness itself is covered rather than assumed.

Mix writes its build-lock notice to **stdout**, interleaved with the child's real output, which made that new assertion intermittently fail. Worth stating plainly: the lock contention was never only cosmetic, and the previous silence was bought by running children against a build nobody had compiled. The runner strips that one line and nothing else.

## As-built probe re-run (post-fix) -- AC-10.4

The E1-E8 set from `design.md`, re-run against the built 0.5.0 escript. Same probes, same order, run from a scratch directory with its own config so nothing in the repository is read or written.

| Probe | 0.4.3                                                              | 0.5.0                                                             |
| ----- | ------------------------------------------------------------------ | ----------------------------------------------------------------- |
| E1    | `--version` printed the whole help screen                          | `arca_cli 0.5.0`, exit 0                                          |
| E2    | `about` reported version 0.1.0                                     | reports 0.5.0, matching VERSION and the app spec                   |
| E3    | piped emoji arrived as the literal text `\x{1F4E6}`                | arrives as its UTF-8 bytes `f0 9f 93 a6`; 0 ESC bytes in the pipe |
| E4    | `dev.info` raised UndefinedFunctionError, red ANSI into the pipe    | renders its table, exit 0                                         |
| E5    | `dev.deps` printed a fabricated list with wrong versions           | reports what is loaded: jason 1.4.5, optimus 0.5.1, owl 0.13.1     |
| E6    | `sys.cmd echo hi` printed `hi` then `{"hi\n", 0}`; `false` exited 0 | raw output is exactly `hi\n` (3 bytes); `false` exits 1            |
| E7    | `cli.debug on` reported ON while behaving OFF                      | survives the process boundary: ON, shows debug detail, OFF sticks  |
| E8    | script line `abut` silently ran `about`                            | `error: abut: unknown command`, script stops, exit 1               |

E6 is the one worth reading twice. The old double-print was a tuple leaking to the user; the fix is not that the tuple is now formatted nicely, it is that there is nothing extra to format. `xxd` on the piped output shows three bytes.

### Release-process trap found here

Bumping `VERSION` alone does not change the built version. `mix.exs` reads it with `File.read!("VERSION")` at project-load time, but Mix does not track `VERSION` as an input to `mix.exs`, so nothing looks stale and no recompile is triggered. The first probe run reported `arca_cli 0.4.3` from an escript built after the bump.

`touch mix.exs && mix compile --force` before `mix escript.build`. This is a real way to ship a release whose binary reports the previous version, which is the same class of defect as A3 -- a version that is true in one place and stale in another.

## WP-11 escript probe -- both failure channels, both outcomes

Run against the built escript from a scratch directory with its own config, after the A26 and A27 fixes. The `^error:` column is the count of lines matching `^error:` in combined stdout+stderr, which is the property AC-11.2 actually claims.

| Command                 | exit | `^error:` | first line                                          |
| ----------------------- | ---- | --------- | --------------------------------------------------- |
| `about`                 | 0    | 0         | `📦 Arca CLI`                                        |
| `sys.flush`             | 0    | 0         | `Command history cleared successfully`               |
| `cfg.list`              | 0    | 0         | `Configuration Settings:`                            |
| `cli.error success`     | 0    | 0         | `Success: No error occurred`                         |
| `cli.error warning`     | 0    | 0         | `⚠ This is a context warning test`                   |
| `cli.error ctx`         | 1    | 1         | `error: cli.error: This is a context error test`     |
| `cli.error standard`    | 1    | 1         | `error: cli.error: This is a standard error tuple test` |
| `cli.error legacy`      | 1    | 1         | `error: cli.error: This is a legacy error tuple test` |
| `sys.cmd false`         | 1    | 1         | `error: sys.cmd: false exited with status 1`         |
| `cfg.get nosuchkey_xyz` | 1    | 1         | `error: cfg.get: setting not found: nosuchkey_xyz`   |
| `nosuchcommand`         | 1    | 1         | `error: nosuchcommand: unknown command`              |

`cli.error ctx` is the row that matters: it reports through `Ctx.add_output({:error, _})` rather than `Ctx.add_error/2`, and before A27 it exited 1 with **zero** matches. `cli.error warning` is the negative control -- a warning is a success carrying notes, so it must stay at exit 0 with no dialect line.

### The first run of this table was worthless and looked perfect

Written as `run $c` with `$c` holding `"cli.error ctx"`. zsh does not word-split unquoted variables, so every multi-word probe was passed as a single argument and ran as an unknown command. Every failure row read `exit=1`, `^error:=1` -- uniformly correct-looking numbers, all of them measuring `unknown command` instead of the behaviour under test. The table above comes from a re-run with explicit arguments.

Third instance of this class in the thread, after A23 (subprocess tests running against an uncompiled build while every `exits 1` assertion passed anyway) and A26 (a gate that could only see the absence of the old string). **When every row of a result table agrees, check that the harness can produce disagreement.**
