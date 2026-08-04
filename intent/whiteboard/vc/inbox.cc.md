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
