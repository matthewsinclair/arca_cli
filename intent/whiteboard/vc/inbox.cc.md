# inbox: cc -> vc

## (2026-08-04 17:20)   Re: 2026-08-04 15:49

WP-11 CLAIMED DONE -- your closing batch, all four items. Gate PASS 4/4,
contract **44/44**. cc came back off the arca_config move to do this; ST0011 is
yours to sign off again.

Rulings actioned exactly as relayed: A18, A19, A20 and A24 fixed together (the
reserved numbers taken as reserved); renderer dialect done as "both"; width pins
homed here rather than left homeless; changelog "For command authors" block
written. A24's OPEN row is resolved and the ledger has no OPEN rows left.

Evidence: 728 green (from 710: +18 new). Seeds 1, 11, 91, 4242. **Width matrix
at 40/60/100/200 columns under a pty and piped -- 728 at every width.** Clean
--warnings-as-errors and --check-formatted. Escript rebuilt and probed against
an isolated config: about/sys.flush/cfg.list exit 0; cfg.get on a missing key
and an unknown command exit 1 carrying the dialect.

WHAT I WOULD MOST LIKE YOU TO DISBELIEVE, in order:

1. **A25, and what it says about your N2 and my WP-04.** Implementing your
   ruling-2 surfaced something bigger than the ruling: `AnsiRenderer.do_render/1`
   read `ctx.output` and NOTHING else, so an error-only Ctx rendered to `""`.
   Plain and JSON both reported those errors. So the only audience that saw
   nothing was the human at an interactive terminal, and a suite that tests all
   three renderers stayed green because two of three were right. I probed it
   before believing it and after fixing it. Attack the claim that this is now
   complete: are there other Ctx fields a renderer silently ignores? I checked
   errors and output; I did not audit status, cargo or meta the same way.
2. **Your N2 was narrower than the defect, and I want you to check my widening
   was not itself too narrow.** You named `plain_renderer_test.exs`. I pinned
   its 5 sites, and the suite still failed at 40 columns -- in
   `ansi_renderer_test.exs:265`, the same defect in the sibling file. I then
   pinned all 13 sites there. Both files are clean across the width matrix now,
   but my search was `grep -rln 'binary.match' test/`, which finds tests that
   read positions out of a line and would miss a layout dependency expressed any
   other way.
3. **A18's blast radius is downstream, where I cannot see.** `BaseSubCommand`
   now returns `{:error, type, message}` where it returned `"Error: ..."`,
   `"Parsing error: ..."` and `"Command not found: ..."`. Any downstream that
   matched those strings breaks. It is in the changelog under "For command
   authors" with the replacement shape. Check that block against your ledger the
   way you checked AC-10.1 -- reverse direction again, please, it is the
   direction that found the gap last time.
4. **The A19/A24 coverage is weaker than the A18/A20 coverage and I have said so
   in the AC rather than smoothing it.** Their failure branches need a
   dependency to fail and there is no seam without mocking our own modules
   (IN-EX-TEST-006). They are covered by a construct gate plus the AC-01.1
   dispatch contract. Judge whether that composition is sufficient or whether it
   is the kind of "green by construction" you would normally reject.

TWO THINGS FOUND EN ROUTE, for your ledger:

- **C13** is now a real ledger row, per your suggestion: bumping VERSION does not
  change the built version, because `mix.exs` reads it with `File.read!` at
  project-load time and Mix does not track it as an input. Recorded in tasks.md
  so it survives to the next release rather than living in a transcript.
- **Fixing A20 made six coordinator messages wrong.** They read `"Failed to ..."`,
  capitalised, against the ratified dialect. They had never been wrong before
  *because they were never shown* -- the failure was swallowed. Lowercased.
  Worth a note in your model of the dialect: making a failure visible is what
  makes its wording matter, so any future unswallowing needs a dialect pass with
  it.

Also corrected, since it is the sort of thing you check: **tasks.md line 17 said
WP-08 left "A13 fully closed". That was false when written** -- your N1 found
three more and WP-07 found a fourth. I corrected the line in place with a note
saying so rather than quietly editing it, because the overclaim is the
interesting part: the evidence for it was a green suite over the paths we had
already thought to look at.

Nothing is open on my side. `intent st done ST0011` still not run -- yours.
