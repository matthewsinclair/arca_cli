# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2026-08-04

A correctness release. An audit of the codebase found three recurring ways the
CLI lost information: command outcomes were discarded in transit, configuration
was read but not honoured, and behaviour changed depending on the environment.
0.5.0 fixes the patterns rather than the instances.

**This release contains breaking changes.** They are marked below, and every
removed public name is mapped to what replaces it.

### Fixed

#### Exit codes -- BREAKING for anything that branched on them

Every command exited 0, including failures. `main/1` hardcoded its result and
nothing called `System.halt/1`, so a shell or CI job could not tell success from
failure. Commands now exit 0 on success and 1 on failure.

This is breaking in the direction you want, but it is still breaking: a script
that ran `arca_cli some.command` and carried on regardless will now stop on
failure if it uses `set -e`. Warnings are successes carrying notes and exit 0.

Some commands were exiting 0 for a second, separate reason: they turned their own
failure into a display string, leaving the dispatch layer nothing to report.
`settings.get`, `cfg.get`, `cli.redo`, `cli.script` and `sys.cmd` all did this and
all now exit 1 on failure.

The same defect was then found in four more places and all four are fixed here:
`sys.flush`, `cfg.list`, `Arca.Cli.Command.BaseSubCommand` and
`Arca.Cli.Configurator.Coordinator.inject_subcommands/2`. `BaseSubCommand` is the
one that mattered most, because it is the shared base every subcommand inherits:
a failing subcommand exited 0 in every application built on it.

The coordinator case was not a display string but the same loss. A command whose
definition could not be read was skipped without a word and injection failure
returned the *original* configuration, so a broken command set produced a CLI
that started up and silently offered fewer commands than the application had
declared. Both now stop startup with the reason.

#### Errors were invisible in the ANSI renderer

A `Ctx` that failed with errors and no output rendered to the empty string under
the `:ansi` style. Plain and JSON both reported those errors, so the gap only
affected the interactive terminal -- the one place a human was reading. Errors
now render in both text styles, and both emit a line in the project dialect
(`error: <command>: <message>`) alongside the `✗` block, so a caller can grep
`^error:` for Ctx failures the same way it does for the string-returning paths.
JSON output is unchanged and stays structured.

#### Versions

- `--version` printed the entire help screen instead of a version.
- Three sources disagreed: `about` reported 0.1.0, `VERSION` said 0.4.3. The
  `VERSION` file is now the single source, read through the application spec.

#### Configuration

- An explicit `false` in configuration was coerced to `true`, so turning a
  feature off did nothing.
- A configurator that raised was silently replaced by the default one, so a
  broken CLI started up looking healthy. It now fails loudly.
- A command registered twice resolved to one implementation when parsing and a
  different one when dispatching. Last registration wins in both.
- `cli.debug on` saved the setting and nothing read it back at startup, so the
  next invocation had debug off while `cli.debug` cheerfully reported ON. The
  display and the behaviour were reading different variables.

#### Output -- BREAKING for anything parsing stdout

- ANSI colour codes were forced on unconditionally and leaked into pipes and
  files. Colour is now used only when stdout is a terminal.
- Piped unicode was mangled: an emoji arrived as the literal text `\x{1F4E6}`
  rather than its UTF-8 bytes.
- `Logger` wrote to stdout, so log lines were interleaved with command output for
  anything piping the CLI into another program, and the first line of a failed
  command could be a stack trace. Logger now writes to stderr.
- Error messages now use one dialect: `error: <context>: <message>`, lowercase,
  with no `inspect/1` quoting around the reason. Four formatters with four
  dialects have become one.
- The "did you mean" suggestion block for an unknown command existed, was tested,
  and had never once run for a user -- the unknown-command path never reached the
  code that consults it. `arca_cli sys.inf` now suggests `sys.info`.

#### Commands

- `sys.cmd` printed its output twice, joined its arguments into one string (so
  `sys.cmd ls -l -a` broke), discarded the OS exit status, and crashed with a
  `KeyError` when given no arguments.
- `dev.info` crashed in the built escript, and `dev.deps` printed a fabricated
  hardcoded dependency list with wrong versions. Both now report reality.
- Scripts and `cli.redo` ran user input through REPL fuzzy matching, so a typo
  silently executed a different command. A script line of `abut` ran `about`.
  Scripts are now strict and stop at the first failing command.
- Command history was unbounded and its rescue clause could not catch the failure
  it was written for, because a `GenServer` call exits rather than raising.

### Removed

Everything below was reachable from its own tests and from nothing else, or was
an unregistered duplicate of a command that ships. Removals are breaking, which
0.x permits, so each one names what to use instead.

#### Commands

Seven command modules were never registered by any configurator, so no user could
invoke them. Each duplicated a command that is registered:

| Removed module                     | Command it declared | Use instead        |
| ---------------------------------- | ------------------- | ------------------ |
| `Arca.Cli.Commands.FlushCommand`   | `flush`             | `sys.flush`        |
| `Arca.Cli.Commands.GetCommand`     | `get`               | `settings.get`     |
| `Arca.Cli.Commands.HistoryCommand` | `history`           | `cli.history`      |
| `Arca.Cli.Commands.RedoCommand`    | `redo`              | `cli.redo`         |
| `Arca.Cli.Commands.StatusCommand`  | `status`            | `cli.status`       |
| `Arca.Cli.Commands.SettingsCommand`| `settings`          | `settings.all`     |
| `Arca.Cli.Commands.SysCommand`     | `sys`               | `sys.info`, `sys.cmd` |

`Arca.Cli.Commands.SubCommand` and `Arca.Cli.Commands.OneCommand` were an example
pair, commented out of the default configurator. Use `Arca.Cli.Command.BaseSubCommand`
directly; the Eg.Cli fixture under `test/support` shows the shape.

#### Functions and macros

| Removed                                                             | Use instead                                          |
| ------------------------------------------------------------------- | ---------------------------------------------------- |
| `Arca.Cli.load_config_phase/0`                                       | nothing -- it was never called; no start_phases exist |
| `Arca.Cli.register_config_callbacks/0`                               | `Arca.Config.register_change_callback/2` directly     |
| `Arca.Cli.ErrorHandler.normalize_error/2`                            | `ErrorHandler.create_error/3`                         |
| `Arca.Cli.ErrorHandler.to_standard_error/1`                          | pattern match the tuple                               |
| `Arca.Cli.ErrorHandler.to_legacy_error/1`                            | `Arca.Cli.Command.BaseCommand.to_legacy_error/1`      |
| `Arca.Cli.ErrorHandler.err_cloc/3`, `err_cfloc/3`                    | `ErrorHandler.create_error/3` with `:error_location`  |
| `ErrorHandler.create_error_with_location/3` and its formatting twin  | as above                                              |
| `use Arca.Cli.ErrorHandler`                                          | nothing -- it imported only the macros above          |
| `Arca.Cli.Repl.autocomplete/1`, `find_namespace_completions/1`       | nothing -- no completion was ever wired into the loop |
| `Arca.Cli.Utils.form_encoded_body/1`                                 | `URI.encode_query/1`, which actually encodes          |
| `Arca.Cli.Utils.parse_json_body/1`, `fetch_body/1`, `decode_json/1`  | `Jason.decode/2` at the call site                     |

`Arca.Cli.Utils.form_encoded_body/1` joined pairs with `=` and `&` without
encoding either side, so any value containing those characters produced a
malformed body. `decode_json/1` decoded with `keys: :atoms`, which creates an
atom per key and is unsafe on input you do not control.

#### Configuration

- `REPL_MODE` file logging is gone, along with the `logger_file_backend` and
  `logger_backends` dependencies. It only ever activated if `REPL_MODE=true` was
  exported before the application started, which the `repl` command did not do.
  File logging can return as a feature in its own right.
- The `ansi_enabled: true` application key is gone. It forced colour on before
  anything could ask where output was going, which pushed escape codes into pipes
  and files.
- The `mix_tasks:` project key is gone; it was not a key Mix reads.

### Changed

- Dependencies no longer declared directly: `castore`, `certifi`, `elixir_uuid`,
  `pathex`, `table_rex`, `ucwidth`, `ok`, `dotenv`. None were used by this
  project's code. The first seven remain resolvable as dependencies of
  `arca_config`, so they stay in `mix.lock` until that project drops them.
- Production code no longer branches on the Mix environment. Settings come from
  the real configuration in every environment, including under test, so the test
  suite exercises the pipeline that ships.

### For embedders

If you wrap this CLI in your own escript, the exit-code fix arrives with a
dependency bump and no code change of your own, provided your `main_module`
delegates to `Arca.Cli.main/1`.

- `Arca.Cli.main/1` runs the CLI and **halts the VM** with the right exit status.
  Use it as an escript entry point.
- `Arca.Cli.run/1` is the same code path but returns `:ok`, `:warning` or
  `:error` instead of halting. Use it when embedding, and in tests. Calling
  `main/1` from a test will kill the test VM.
- A command returning `Ctx.complete(:error)` now means what it says: the process
  exits 1.

### For command authors

Changes that affect you if you write commands against this library, rather than
only running the CLI.

- **`Arca.Cli.execute_command/5` now returns `{:ok, outcome, output}`** instead of
  the output alone. Breaking for any direct caller. The outcome is what drives
  the exit status, so it has to leave the function for the caller to honour it.
- **`Arca.Cli.Command.BaseSubCommand` returns error tuples from `handle/3`.** It
  previously formatted every failure into a display string. If you matched on
  those strings (`"Error: ..."`, `"Parsing error: ..."`, `"Command not found: ..."`)
  match on `{:error, error_type, message}` instead. Failure messages are now
  lowercase and unprefixed, because the dispatch layer adds `error: <command>: `.
- **The `namespace_command` macro generates under the CALLER's namespace** and
  returns the block's value rather than `[do: value]`. Breaking if you use the
  helper: generated module names change, so configurator references to them move
  with the namespace.
- **Deferred output resolves when the context is built, not when it is
  rendered.** A `{:spinner, label, fun}` item has its function run inside
  `Ctx.add_output/2`, and renderers receive the resolved result. If you wrote a
  custom renderer that executed deferred items itself, it no longer needs to and
  must not: renderers are pure.
- **`cli.script` stops on the first failing command.** Use `--keep-going` for the
  old continue-past-failure behaviour. Scripts that relied on running to the end
  regardless need that flag.
- Minor: `BaseSubCommand` rebuilds its argument vector in the order arguments
  were *declared* rather than in map-key order, which only ever came out right
  for exactly two arguments. REPL history recording now matches command names
  exactly, so a name that merely contains another command's name is no longer
  mistaken for it.

### Known limitations

None outstanding for the exit-code contract. Every command's failure now reaches
the shell as a non-zero status, and `grep '^error:'` finds every reported
failure across the string-returning paths, the Ctx paths and both text styles.

## [0.4.3] - 2025-01-27

### Fixed

- Lines starting with `#` inside heredocs in `cli.script` are now filtered from
  stdin, consistent with comment handling in the main script body. Comments are
  still echoed for visibility but not passed to the command.

## [0.4.2] - 2025-01-25

### Added

- REPL quit command aliases: `/q`, `/quit`, `/exit`, and `exit` now exit the REPL
  in addition to the existing `quit`, `q!`, and Ctrl+D commands
