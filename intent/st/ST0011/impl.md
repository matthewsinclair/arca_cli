# Implementation - ST0011: Fable review of arca_cli base code

## Implementation

Status: audit phase complete, implementation not started. No production code has been changed under this steel thread yet.

Session 2026-08-04 (cc):

- Read all 55 files in `lib/` at `ca7ba57`. Catalogued findings in `design.md` as A (confirmed correctness failures), B (dead machinery), C (design debt).
- Verified findings by probe rather than by inspection alone -- 8 runtime probes under `mix run`, 8 escript probes against a freshly built `_build/escript/arca_cli`. Probe transcripts are in `design.md`'s Probe Appendix.
- One candidate finding was withdrawn after probing (P7: `Utils.decode_json` with map options works correctly).
- Elaborated WP-01..WP-10 with objectives, deliverables and a dependency DAG (`tasks.md`).
- Drafted the acceptance contract; hv ratified it in full along with all 7 open decisions on 2026-08-04.

## Code Examples

Not applicable yet -- no implementation. The shapes the WPs will build are described in `design.md` "Design Decisions" and in each WP's Deliverables.

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

## As-built probe re-run (post-fix)

To be completed in WP-10: re-run the E1-E8 escript probe set from `design.md` and record the new outcomes here as evidence for AC-10.4.
