# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - 0.5.0

This section is being assembled work package by work package; WP-10 completes it.

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

## [0.4.3] - 2025-01-27

### Fixed

- Lines starting with `#` inside heredocs in `cli.script` are now filtered from
  stdin, consistent with comment handling in the main script body. Comments are
  still echoed for visibility but not passed to the command.

## [0.4.2] - 2025-01-25

### Added

- REPL quit command aliases: `/q`, `/quit`, `/exit`, and `exit` now exit the REPL
  in addition to the existing `quit`, `q!`, and Ctrl+D commands
