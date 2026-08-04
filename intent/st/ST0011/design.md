# Design - ST0011: Fable review of arca_cli base code

## Approach

Full-codebase audit of `lib/` (all 55 files read), triggered by issue 0001 (every command exits 0). The exit-code bug destroyed information mid-pipeline; the audit swept for the same failure family everywhere: information destroyed in flight, dead branches, environment-dependent behaviour, duplicated concerns, and API that does not do what it documents.

Every finding below is verified against the as-built code at `ca7ba57`, not the narrative. Runtime findings carry a probe reference: P-probes ran under `mix run` against the compiled library; E-probes ran against a freshly built escript. Baseline before any change: 493 tests passing (31 doctests, 462 tests), 0 failures. `mix compile --force` emits no warnings.

Verdict: the codebase is functionally rich but systematically loses correctness information at boundaries. Three loss archetypes recur: outcomes discarded (exit codes, Ctx.status, sys.cmd status), configuration read but never honoured (allow_unknown_args, history_size, debug_mode persistence), and behaviour that silently depends on environment (renderer side effects by TTY, test-only code paths, escript-only crashes). A 0.5.0 breaking release should fix the archetypes, not just the instances.

## Findings A: Confirmed correctness failures

All confirmed by probe. Severity: C = breaks correctness for users/automation, V = visibly wrong output.

| ID  | Sev | Finding                                                                  | Evidence                                                                                         | Probe   |
| --- | --- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------ | ------- |
| A1  | C   | Every command exits 0; outcome destroyed at 3 points                     | `lib/arca_cli.ex:321` hardcoded `:ok`; `:739` drops `ctx.status`; `:654-667` stringifies errors  | 8-cmd repro table, all exit=0 |
| A2  | C   | `--version` prints the help screen, not a version                        | no `:version` clause in `handle_args/3`; USAGE advertises the flag                                | E1      |
| A3  | V   | Three version sources disagree; `about` reports 0.1.0, real is 0.4.3     | `config/config.exs` `version: "0.1.0"`; `VERSION` 0.4.3; `dft_configurator.ex:36` "Arca CLI VERSION" | P8, E2  |
| A4  | C   | `allow_unknown_args: false` and `parse_double_dash: false` silently coerced to `true` | `base_configurator.ex:107-108` `\|\| true`; the identical bug was fixed for `sorted` at `:110-116` | P3 -> `{true, true, false}` |
| A5  | C   | History "graceful degradation" is illusory: `rescue` cannot catch GenServer exits | `history.ex:100-108` (+4 siblings); same pattern `cli_status_command.ex:57-64`, `sys_flush_command.ex:52-63` | P1 -> `{:caught, :exit, :noproc...}` |
| A6  | C   | Renderers execute business logic only in ANSI mode: `{:spinner, label, fun}` runs `fun` on TTY, silently skips it otherwise | `ansi_renderer.ex:251-261,282-298` executes; `plain_renderer.ex:156-161`, `json_renderer.ex:95-101` label-only | P5      |
| A7  | C   | Scripts and redo run through REPL fuzzy matching: a typo silently executes a different command | `cli_script_command.ex:205,218` -> `Repl.eval_for_redo` -> `repl.ex:597` `try_fuzzy_match`        | E8: script line `abut` ran `about` |
| A8  | C   | `dev.info` crashes in escript (`Mix.env` undefined); `dev.deps` prints a fabricated hardcoded dep list in escript | `dev_info_command.ex:16`; `dev_deps_command.ex:55-71` (wrong versions, missing real deps)         | E4, E5  |
| A9  | C   | `cli.debug on` persistence is inert: setting saved, nothing loads it at boot; next invocation has debug off while `cli.debug` reports ON | `cli_debug_command.ex:54-62`; no boot reader of `"debug_mode"` (grep)                             | E7      |
| A10 | C   | `sys.cmd`: output printed twice (2nd time as inspected tuple), multiple args joined into ONE OS arg, OS exit status printed bare then discarded | `sys_cmd_command.ex:47-51,54-68`; duplicate print via `utils.ex:257` `put_lines(tuple)->IO.inspect` | `echo hi` -> `hi` + `{"hi\n", 0}`; `ls -l -a` -> usage error; `false` -> cli exit 0 |
| A11 | C   | Ctx's own consumers hold it wrong: command atom passed as `args`, `ctx.command` stays nil, `ctx.args` is an atom not a map | `settings_all_command.ex:46,55,80`, `cli_history_command.ex:17`, `sys_info_command.ex:25` vs `ctx.ex:122-130` | P2 -> `{nil, :"sys.info"}` |
| A12 | V   | Piped output mangles unicode (emoji -> literal `\x{1F4E6}`) while ANSI colour codes leak INTO pipes (forced `ansi_enabled`) | escript io encoding unset; `arca_cli.ex:249` `Application.put_env(:elixir, :ansi_enabled, true)` unconditional | E3 hexdump; E4/E8 `[31m`/`[36m` in piped output |

| A13 | C   | Leaf commands discard their own outcome: a failure returned as a plain string is indistinguishable from success, so the command exits 0 even with the exit-code plumbing in place | `settings_get_command.ex:55-65` returns `message` on `{:error, message}`; `cli_script_command.ex` and `cli_redo_command.ex` do the same | escript after WP-01: `settings.get nosuchkey`, `cfg.get nosuchkey`, `cli.script /nonexistent`, `cli.redo 999` all still exit 0 |

### A-finding mechanics worth recording

- A13 detail: found by re-probing the repro set after WP-01 landed. A1 was the plumbing (outcome destroyed in transit); A13 is the same archetype one layer down (outcome never created). WP-01 fixed 7 of the 11 repro commands; the remaining 4 are commands that pattern-match their own failure and then flatten it to a display string, which `process_command_result/3` can only read as success. The `cli.script` leg is already AC-05.4 and the `sys.cmd` leg AC-06.2; `settings.get` / `cfg.get` / `cli.redo` had no home, so they are now AC-08.3 -- WP-08 is where the error dialect changes anyway, so fixing them there changes the display once rather than twice. Fixing them inside WP-01 would have violated the ratified AC-01.4 (display unchanged).
- A1 detail: `main/1:294-311` error branches are dead code -- `handle_subcommand/4` and `handle_args/3` stringify all errors upstream, so tuples can never reach them. `parse_command_line/3` returns a plain String for every failure mode (probed). `Ctx.complete/2` is documented, public, stores the status, and exactly one debug renderer ever reads it.
- A2 detail: Optimus's `:version` parse result falls through `handle_args`'s `_other ->` catch-all into `generate_filtered_help`. Even if routed, the Optimus version string is the placeholder "Arca CLI VERSION".
- A5 detail: `GenServer.call` to a dead/absent process raises an exit signal, not an exception. Every `try/rescue` wrapper in `history.ex` (get_state, push_cmd, get_history_length, get_history, flush_history) misses it. The REPL prompt path (`repl_prompt -> History.hlen`) therefore crashes rather than degrading if History dies.
- A6 detail: this makes command behaviour depend on output style. The same Ctx does its work on a TTY and silently does nothing under `ARCA_STYLE=plain`, in tests, in pipes, and in JSON mode. Renderers must be pure; execution belongs in the command layer.
- A12 detail: the two axes are inverted. Content (emoji) that should survive a pipe is destroyed; decoration (ANSI codes) that should be stripped in a pipe is forced on. `Output`'s careful TTY detection exists but is bypassed by the forced flag and by the legacy string path.

## Findings B: Dead machinery (grep-confirmed, zero callers)

| ID  | Finding                                                                                     | Evidence                                                                    |
| --- | ------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| B1  | Entire config-callback subsystem unreachable: `load_config_phase` has no caller (mix.exs has no `start_phases`), so `register_config_callbacks`, `handle_config_change`, `apply_display_settings`, subscriptions never run | `arca_cli.ex:150-235,1064-1097`                                              |
| B2  | Hardcoded foreign-project reference: `Multiplyer.Config.Server`                              | `arca_cli.ex:1056,1081`                                                      |
| B3  | Seven unregistered legacy command modules shipped as public API: Flush, Get, History, Redo, Status, Sys, Settings (+ example SubCommand/OneCommand); three generations of the same commands (bare / sys.* / cli.*, cfg.*, settings.*); `SysCommand` is a literal copy-paste of `SysCmdCommand` | `dft_configurator.ex:8-32` registers none of them                            |
| B4  | ErrorHandler location macros never used: `create_error_with_location`, `create_and_format_error_with_location`, `err_cloc`, `err_cfloc`, `__using__` | `error_handler.ex:18-32,342-429`; grep: zero call sites                      |
| B5  | `REPL_MODE` env var consumed in two places, set by nothing; the file-logging feature it gates is unreachable without an undocumented manual export | `arca_cli.ex:112`, `config/runtime.exs`                                      |
| B6  | `Process.put(:is_repl_mode, true)` written, never read                                       | `repl.ex:64`                                                                 |
| B7  | `use OK.Pipe` in two modules, zero `~>>` pipelines anywhere; `:ok` dep likely droppable      | `arca_cli.ex:85`, `utils.ex:18`                                              |
| B8  | Six unused runtime deps shipped to every consumer: `table_rex`, `pathex`, `elixir_uuid`, `ucwidth`, `certifi`, `castore` (only textual mention is dev.deps' fabricated list); `dotenv` dep unused beside the hand-rolled parser in `config/dotenv.exs` | grep across `lib/`                                                           |
| B9  | HTTP-client residue in Utils: `form_encoded_body` (does NOT URL-encode despite the name), `parse_json_body`, `fetch_body`, `decode_json` -- no callers in `lib/`, tests only | `utils.ex:50-113`                                                            |
| B10 | Commented-out blocks and vestigial params: `check_initialization_status`, `intro/2` ignoring both parameters | `arca_cli.ex:256-257,325-341,1214-1218`                                      |

## Findings C: Design debt and API traps

| ID  | Finding                                                                                    | Evidence                                                                        |
| --- | ------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| C1  | `namespace_command` macro generates `handle/3` returning `[do: result]` -- the keyword wrapper leaks into output; masked in tests by `=~` substring assertions. Also generates modules into `Arca.Cli.Commands.*` for EVERY consuming app -> cross-app collision | `namespace_command_helper.ex:84-87,102-104`; P4 -> `[do: "pong-payload"]`         |
| C2  | Dispatch resolves by module-name reconstruction, not registration: snake_case command names are impossible (BaseCommand's own doc example `GetDataCommand`/`:get_data` fails its own validation); hand-rolled CommandBehaviour modules bypass validation and become registered-but-undispatchable; name collisions resolve first-module-wins while Optimus config resolves last-wins -- parse and dispatch can disagree | `arca_cli.ex:554-578`; `base_command.ex:145-146,184-238`; `coordinator.ex:394-397` |
| C3  | Coordinator swallows configurator failure and silently replaces the app's ENTIRE command set with arca defaults | `coordinator.ex:73-77`                                                            |
| C4  | `BaseSubCommand.extract_arguments` rebuilds positional argv from `Map.values` order (term order, not declaration order) -- latent arg-reorder for multi-arg subcommands; moduledoc shows `@sub_commands` attribute style that the implementation ignores (reads config key) | `base_sub_command.ex:20-24,57,100-107,253-256`                                    |
| C5  | Error-format Highlander violation: 3+ user-visible dialects -- `"Error (type): msg"` (ErrorHandler), `"error: prefix: msg"` (Cli.handle_error family), raw unprefixed strings (commands returning error text), plus REPL's deprecated formatter set | `error_handler.ex:159`; `arca_cli.ex:891-907`; `repl.ex:173-181`                  |
| C6  | 13 `Mix.env()` sites in lib across 5 files; `settings.all` fabricates fake data under test; `main/1` displays through a test-only path; the suite partially exercises a pipeline production never runs. `Output.test_env?` checks the `MIX_ENV` OS var, which `mix test` does not set -- unreliable duplicate of the same idea | `settings_all_command.ex:42-49,68-85`; `arca_cli.ex:277-281,1035-1037,1117-1126,1175-1179`; `output.ex:160-165` |
| C7  | Style detection triplicated and disagreeing: `Output.determine_style` (TERM + ansi_enabled) vs `AnsiRenderer.check_tty` (TERM only) vs forced `ansi_enabled` in `main/1` | `output.ex:82-175`; `ansi_renderer.ex:58-64`; `arca_cli.ex:249`                   |
| C8  | `should_push?` uses substring matching: any command whose text CONTAINS history/redo/flush/help is silently excluded from REPL history (eg `settings.get help_url`) | `repl.ex:830,852`                                                                 |
| C9  | Dead knobs cluster: `history_size` default defined, never enforced (history unbounded); `debug_mode` persisted, never loaded (A9); `Ctx.status` stored, never acted on (A1) | `arca_cli.ex:1152`; `history.ex` (no trim)                                        |
| C10 | mix.exs junk keys silently ignored: `mix_tasks:` is not a Mix project key; `ansi_enabled:` is not an application key | `mix.exs:18-21,27-29`                                                             |
| C11 | `String.to_atom` on user input in help paths (7 sites) -- unbounded atom creation in a long REPL session | `arca_cli.ex:468`; `help.ex:81,217`; `ctx.ex:377` -- assigned to WP-06 as AC-06.7 (vc flagged it as the one confirmed finding without a home, 2026-08-04) |
| C12 | `put_lines(map/tuple) -> IO.inspect` as user-facing output (how sys.cmd's tuple reaches the screen) | `utils.ex:256-257`                                                                |
| C13 | Ansi/Plain renderer duplication (~120 lines of table-option wrangling + `remove_header_lines` + `safe_to_string`), already drifted: `{:list, items}` 2-tuple renders in ansi, silently dropped in plain; `{:json, ...}` items supported by all renderers but absent from `Ctx.output_item` type | `ansi_renderer.ex:113-247,416-441` vs `plain_renderer.ex:146-177,443-468`; `ctx.ex:65-74` |
| C14 | Latent REPL crashes: `repl/3` else lacks a 3-tuple error clause (WithClauseError if one ever arrives); `eval_for_redo` matches only 4-tuple errors | `repl.ex:139-158,964-969`                                                         |
| C15 | Minor hygiene: `Ctx.add_output` O(n) list append per item; `Help.normalize_app_name` `with` that can never fail (and would map a tuple into a line list if it did); inspect-wrapped values in user output (`"Key not found"` with quotes); doc typos (implementaiton, numver, coammd); `cli_command_helper` docs reference nonexistent `config.set` command | `ctx.ex:150-152`; `help.ex:267-303`; `arca_cli.ex:1135`                           |

## Design Decisions

The remediation is organised into 10 work packages (WP01-WP10, elaborated in `WP/` and sequenced in `tasks.md`). Ratified by hv 2026-08-04 together with the 7 open decisions tabulated in `tasks.md`; `acceptance.md` is RATIFIED. Key design rulings the fixes follow:

1. One status pipeline (WP01): commands report outcomes; the dispatcher carries `{status, output}`; string-returning legacy functions become thin adapters (Highlander-compliant). `System.halt` lives only at the process entry boundary (`main/1`); `run/1` is the pure embeddable API. Downstream inherits correct exit codes from a dep bump with zero code changes.
2. One version source (WP02): the `VERSION` file. App env, configurator default, and Optimus version all derive from it.
3. Config must be honoured or rejected, never coerced (WP03): explicit `false` survives; a broken configurator is a loud startup error, not a silent command-set swap.
4. Renderers are pure (WP04): rendering never executes command logic. Spinner/progress semantics move to the command layer; one style detector; ANSI decided by TTY, not forced; escript io set to unicode.
5. Interactive conveniences stay interactive (WP05): fuzzy matching prompts in the REPL only; scripts and redo are strict.
6. No test-only code paths in lib (WP09): the suite must exercise the production pipeline.

## Alternatives Considered

- Fix only issue 0001 and ship 0.4.4: rejected -- the same information-loss archetype recurs in at least 11 other confirmed places; a breaking 0.5.0 that fixes the archetypes is materially better and amortises one migration cost.
- Separate halting entry module (`Arca.Cli.CLI.main/1`) leaving `main/1` pure: rejected in favour of `main/1` halting + new pure `run/1`, because every downstream escript already points at `main/1`; the alternative forces all consumers to edit their escript config to get the fix.
- Deprecate rather than delete dead machinery (B1-B10): deletion chosen for a 0.x breaking release; modules with plausible downstream use (legacy command modules, Utils HTTP residue) get a deprecation note in the changelog listing replacements.

## Probe Appendix

Runtime probes (`mix run`, scratchpad `probe2.exs`):

| Probe | Question                                         | Result                                                        |
| ----- | ------------------------------------------------ | ------------------------------------------------------------- |
| P1    | Does History's rescue catch a dead-process call? | No -- `{:caught, :exit, {:noproc, ...}}` escaped the rescue    |
| P2    | Does Ctx.new misuse swap fields?                 | Yes -- `{command, args} = {nil, :"sys.info"}`                  |
| P3    | Are explicit `false` config values honoured?     | No -- `{allow_unknown_args, parse_double_dash, sorted} = {true, true, false}` |
| P4    | What does a namespace_command handle return?     | `[do: "pong-payload"]`                                         |
| P5    | Does spinner fun run in plain? in ansi?          | plain: `:not_ran`; ansi: `:ran`                                |
| P6    | Does fuzzy match rewrite typos?                  | `fuzzy_match("abut") = {:single, "about"}`                     |
| P7    | decode_json with map opts                        | Works (`{:ok, %{a: 1}}`) -- no finding, withdrawn              |
| P8    | App-env version vs VERSION file                  | `{"0.1.0", "0.4.3"}`                                           |

Escript probes (`_build/escript/arca_cli`):

| Probe | Command                                  | Result                                                                   |
| ----- | ---------------------------------------- | ------------------------------------------------------------------------ |
| E1    | `--version`                              | Prints full help screen                                                  |
| E2/E3 | `about` piped + hexdump                  | Literal bytes `\x{1F4E6}` instead of emoji; reports version 0.1.0        |
| E4    | `dev.info`                               | UndefinedFunctionError Mix.env, red ANSI stacktrace leaked into pipe     |
| E5    | `dev.deps`                               | Fabricated hardcoded list (wrong optimus version, missing real deps)     |
| E6    | `sys.cmd echo hi` / `ls -l -a` / `false` | `hi` then `{"hi\n", 0}` double print; joined `"-l -a"` breaks ls; OS exit 1 -> CLI exit 0 |
| E7    | `cli.debug on` then new invocation       | Reports ON, behaves OFF                                                  |
| E8    | script containing `abut`                 | Fuzzy-matched and executed `about`, debug log leaked in colour           |

Exit-code repro (all exit 0): `about` (correct), `settings.get nosuchkey`, `cfg.get nosuchkey`, `cli.error standard|raise|legacy`, `cli.script /nonexistent`, unknown command.
