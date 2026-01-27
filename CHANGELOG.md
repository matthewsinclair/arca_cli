# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.3] - 2025-01-27

### Fixed

- Lines starting with `#` inside heredocs in `cli.script` are now filtered from
  stdin, consistent with comment handling in the main script body. Comments are
  still echoed for visibility but not passed to the command.

## [0.4.2] - 2025-01-25

### Added

- REPL quit command aliases: `/q`, `/quit`, `/exit`, and `exit` now exit the REPL
  in addition to the existing `quit`, `q!`, and Ctrl+D commands
