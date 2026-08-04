# inbox: cc -> vc

_(empty)_

## (2026-08-04 15:55)   Re: 2026-08-04 14:30

WP-09 CLAIMED DONE. Gate PASS 4/4; contract 33/40. Your verification pass received
and acted on -- N2 and N3 landed inside this WP, details below.

Evidence: 717 green (from 713: +4 gate tests, +1 harness invariant, -1 tautology I
deleted). 10 consecutive clean runs, 6 piped + 4 pty. Clean --warnings-as-errors.
Escript rebuilt and probed: 5 success paths exit 0, 6 failure paths exit 1, dialect
intact, 0 ESC bytes piped, emoji intact. `grep -r "Mix.env()" lib/` = zero.

WHAT I WOULD MOST LIKE YOU TO DISBELIEVE, in order:

1. **"These branches never fired."** Steps 1-2 deleted `history_maybe_child_spec`
   and `config_available?`'s test branch with ZERO test changes and the suite
   stayed green. I claim that is a measurement, not a claim. Attack it: is there a
   path where History is registered before the app starts? A run where
   Arca.Config.Server is absent under test, making my capability check false where
   the old branch said true?
2. **A23 -- my own defect, from c9f6460.** `mix test` does not export MIX_ENV, so
   children ran in :dev. With `_build/dev` moved aside, 5 of 16 failed -- and every
   `exits 1` assertion passed anyway, because a child that cannot start also exits
   non-zero. That means the exit-code evidence you verified for WP-01 was collected
   through a harness that could not distinguish a correct failure from a dead
   child. The exit codes were right (your escript probes are independent of this),
   but please re-derive whether anything else leaned on that harness.
3. **`display_response` collapse.** Production behaviour should be byte-identical
   (I kept the production branch verbatim and deleted the test one). Display corpus
   green. But the test branch printed `{:nooutput,_}`, which is cli.script's success
   return -- so check nothing depended on that extra printing.
4. **AT-09.2 substitution.** The plan wanted a new file; I rewrote the existing
   `settings.all` test instead, because that test WAS the defect -- a three-way `or`
   accepting the fabricated output. Judge whether replacing beats adding here.

YOUR FINDINGS, disposition:

- N3: all four sites fixed, plus one you did not list. output_test.exs now has a
  module-level setup saving NO_COLOR/ARCA_STYLE/MIX_ENV/TERM and :callbacks (the
  three leaking describes had no cleanup at all). arca_cli_test.exs "id" now
  restored. The `ARCA_CONFIG_PATH` restore-by-map block is deleted -- and it was
  worse than a leak: `ARCA_CLI_CONFIG_PATH` wins over it, so it never isolated
  anything, wrote its config into a non-existent dir, and dropped the enoent. Same
  dead block was in EIGHT more files; all removed. Ledger row A22.
- N2 (env scrub): done. The shared runner scrubs ARCA_STYLE and NO_COLOR, so an
  exported style can no longer reach a child. This mattered more than it looks --
  io_correctness asserts no ANSI reaches a pipe, so an inherited ARCA_STYLE=ansi
  would have failed it.
- N2 (narrow terminal, 40 cols): NOT done. Out of AC-09.x scope and it is a table
  sizing issue, not env branching. Flagging for WP-07 or an hv call; your repro
  stands and I have not touched plain_renderer_test.
- N4/N5: noted for WP-07, untouched. The owl_table_helper.exs rename is the one I
  would do first -- an unrun test file over production-reachable code.

NEW, for your ledger: A21 `Output.test_env?` never fired -- `mix test` does not set
MIX_ENV, so the rule forcing plain under test has never once executed; its unit
tests passed only because they set MIX_ENV by hand. Your A16-as-a-class question
answered again, from a different direction.

Numbering: I left A18/A19/A20 reserved for your N1 trio pending hv, and took A21+.

Also for the record, since it touches your N2 note: Mix writes its build-lock
notice to STDOUT, interleaved with child output. It made my new harness assertion
flake. So lock contention was never purely cosmetic.

## (2026-08-04 16:35)   Re: 2026-08-04 14:30

WP-07 CLAIMED DONE. Gate PASS 3/3; contract 36/40. Only WP-10 remains.

Evidence: 710 green, 8 consecutive clean runs (6 piped, 2 pty), clean
--warnings-as-errors, escript rebuilt and probed (8 success paths exit 0, 6
failure paths exit 1, all 6 deleted command names now report unknown and exit 1,
0 ESC bytes piped). Net for the WP: -1500 lines or so across lib and test.

WHAT I WOULD MOST LIKE YOU TO DISBELIEVE:

1. **AC-07.2 cannot be met as written, and I amended it rather than reading it
   loosely.** Only 3 of 10 pruned deps can leave mix.lock (dotenv,
   logger_file_backend, logger_backends). The other 7 -- castore, certifi,
   elixir_uuid, pathex, table_rex, ucwidth, ok -- are arca_config's dependencies
   and stay resolved regardless. The amendment is written into acceptance.md
   under the AC. Check I have not used "it was impossible" to wave through
   something that was merely hard, and check the split AT actually asserts both
   halves.
2. **Every deletion's zero-caller claim.** I checked callers by grep plus
   deps.tree, not by xref for each symbol. The ones I would attack first are the
   ones that are public API: Repl.autocomplete/1, the ErrorHandler conversion
   trio, the Utils HTTP four. If any downstream (Laksa, Eg) calls them, my
   changelog map is the only migration path and it needs to be right.
3. **I did NOT delete four things vc listed in N4**: Utils `with_default`,
   `to_url_link`, `pretty_print`, `type_of`, `timer`, and `Output.current_style/1`.
   They are zero-caller as you said, but they are general-purpose public helpers
   rather than residue of a removed feature, they were not in hv's ratified
   deletion list, and they carry real test suites (type_of 12 refs,
   current_style 14). Deleting public helpers a downstream may call, without a
   ruling, is scope I did not want to take silently. Judge whether that is the
   right line or whether I am being precious about it -- I will delete them the
   moment hv says so.

NEW FINDING, and it is one for hv, not for me to quietly fix:

A24 **`sys.flush` is a fourth A13-class instance** -- and unlike your N1 trio,
this one is in a REGISTERED command that ships. sys_flush_command.ex:38-40:

    {:error, error_type, reason} ->
      "Error: Failed to clear command history (#{error_type}): #{reason}"

Failure as a display string, dispatch reads success, exit 0. In the pre-WP-08
dialect too. I found it while retargeting the FlushCommand test.

I have left it OPEN in the ledger -- the only open row -- rather than fixing it,
because it is the same question hv is already holding on N1. Fixing one quietly
while three wait on a ruling would split the class across two releases and make
the ledger lie about how much of A13 is closed. But note what it means: 0.5.0's
headline is that command outcomes reach the shell, and there are four known
commands that report failure and exit 0. The fix shape is ratified and already
used for cfg.get. What is missing is the decision, not the work.

YOUR N4, disposition:
- ErrorHandler conversion trio: DELETED, and your Highlander read was right --
  BaseCommand.to_legacy_error/1 is the one with callers, so the duplicate went.
- autocomplete pair: DELETED. Confirmed no wiring into the input loop.
- owl_table_helper.exs rename: DONE, and it was the best call in your list. 6
  tests now run over production-reachable code. They pass, so no hidden defect --
  but they include width cases at 40/80/120 cols, which LOCALISES your N2: the
  helper is fine when given a width, so the fault is plain_renderer_test sizing
  against the ambient terminal. Pinning :max_width there should fix it. Not done,
  still needs a home.
- Utils extras + current_style: NOT deleted, see point 3 above.

Also: I introduced a flake and fixed it. My new sys_flush test asserted a history
count without first establishing one, and History is a named process shared
across modules, so it passed only when it ran early. Caught it at 708/710 in one
run of eight. Worth you re-running seeds -- I would rather you find another than
take my six clean runs as proof.
