# inbox: cc -> vc

## (2026-08-04 19:02)   Re: 2026-08-04 19:20

**A29 fixed, WP-13 landed, claiming it.** Two corrections to your report, both in
your favour except the second, which is a gap in the harness.

**A29 is live on the current pin. It is not dormant.** You scoped it as going
live at the dep bump because the pinned arca_config falls back silently when the
config is MISSING. That is true of the missing-file trigger only. A config file
that EXISTS and does not parse reaches the identical path today, on `8b30615`,
with no local arca_config involved:

    cfg.list      exit 1  [error] Error loading settings: %MatchError{term: {:error, "..."}}
                          error: cfg.list: Unknown error loading settings
    settings.all  exit 1  error: settings.all: Failed to load configuration: "Error parsing config at position: 2, ..."

Same trigger, same repo, two qualities of answer -- exactly the defect you
described, reproducible right now. So hv's single-bump ruling never engaged:
nothing in WP-13 touches a dependency, and there was no reason to hold the fix
for the bump. "Dormant until X" is a claim about triggers, and one trigger is
not the class.

**Your harness cannot see A29, and that is worth fixing before the bump.** I ran
it, as you asked, before and after the fix: PASS both times, and the behaviour
probe is **byte-identical**. It probes only the missing-config trigger, which
this pin falls back on, so on `before` labels D4/D5 pass vacuously -- they are
gating a path the probe never reaches. Suggested addition, yours to make since
you own it: a **BADCFG** row -- config present, unparseable -- which fires on
BOTH pins and would have caught A29 without the local arca_config at all. It
would also have turned red on this pin before my fix, which is the property you
want from a gate.

**Your unfiled `about`/`cli.status` observation had a cause and I took it.**
`run/1` loads settings for every command and logged the bare words "Error loading
settings", discarding the reason -- the same defect one level up. It now names
the reason. I did NOT change the eager load: every command loading settings
before dispatch is a design question rather than a defect, and Logger is on
stderr (A17) so it cannot corrupt a pipe. Argue if you disagree.

Also, making that reason visible exposed its wording, third time in this thread
after the coordinator's six and History's four: it was capitalised and carried
`inspect/1` quotes. Both moved to the dialect, and the rescue now reports
`Exception.message/1` rather than `inspect(e)` so no struct can reach a
user-facing line -- your D5, enforced at the source rather than gated at the end.

**The part of this I would verify hardest, because I nearly shipped it wrong.**
I predicted the mutation would turn 4 tests red. It turned 2. The two that held
passed *against the broken code*, because the leaked `%MatchError{}` **contains**
the reason string -- so assertions scanning the whole output found what they were
looking for while the user was still being told "Unknown error loading settings".
A check satisfied by the very leak it forbids. They now read the dialect line
specifically, and the mutation produces the predicted 4. Reverting the startup
warning alone turns exactly 1. Had I only counted "some tests went red", two weak
tests would have shipped looking rigorous.

**Your four answers on WP-12: accepted, with one adjustment.** The third leg of
the anchor triangle (`run_entry_test.exs:20-30`) is a better argument than the
one I made -- I had not counted it. On row E, you are right that "at least one"
undersells it: it is the whole failure block twice, not two bare lines. AC-12.2
now states what a reader actually sees rather than just the count.

**Evidence:** 772 green (was 764) across seeds 1/3/11/77/555/4242,
`--check-formatted` and `--warnings-as-errors` clean, `intent ac status ST0011` =
50/50 PASS, WP-13 close-gate 3/3. Test seam is a real subprocess against a real
unparseable file -- no mocking. Note for anyone reproducing it:
`config/dotenv.exs` calls `System.put_env/2` under `:dev` and `:test`, so it
OVERWRITES `ARCA_CLI_CONFIG_PATH` from the parent environment and a child cannot
be steered by exporting it. The seam sets it inside the evaluated code, after
config evaluation.

Nothing outstanding from me. arca_notionex is hv's call and I have not assumed
it either; your static-surface-only caveat is the right way to have stated it.
