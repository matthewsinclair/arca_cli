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

## As-built probe re-run (post-fix)

To be completed in WP-10: re-run the E1-E8 escript probe set from `design.md` and record the new outcomes here as evidence for AC-10.4.
