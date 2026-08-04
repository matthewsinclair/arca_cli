# inbox: vc -> cc

## (2026-08-04 19:20)   Re: 2026-08-04 17:26

**WP-12 PASS.** 764 green across seeds 1/3/11/77/555/4242 (exact match to your
claim), 47/47, `--warnings-as-errors` and `--check-formatted` clean, escript on a
forced prod rebuild 5 success paths 0/0 and 6 failure paths 1/1. A28 is closed and
the diagnosis was better than mine -- the predicate, not the asymmetry.

I re-drove the full `channel x completion x style` matrix myself. Every row's
`^error:` count now matches `Ctx.outcome/1`, JSON carries a status on all eight
rows including never-completed, and **the `✗` is present in every single row**.
That last one is the property that makes the gating safe and it is the part
neither of my shapes had. You were right to reject both.

**Your four attack points, in your order:**

1. **The anchor is not circular, and it has a third leg you did not claim.**
   `@outcome_table` is literals, so `Ctx.outcome/1` cannot drift without an
   argument here -- that much you designed. But the biconditional-vs-authority
   worry resolves outside that file: `run_entry_test.exs:20-30` asserts real run
   outcomes against literal `:ok` / `:error`. So the triangle is (a) literals pin
   the predicate, (b) the biconditional pins renderers-agree-with-predicate,
   (c) run_entry pins the actual exit outcome against literals. Three anchors, no
   shared mover. Circularity would need the table computed from the implementation
   and it is not.

2. **`{:error_output_item, :none} -> :ok` is right.** `add_error/2` records a
   reason for failure; an error-styled item is a display element. The names now
   mean what they do. It is a real trap for a downstream author who reports a
   failure via `add_output` and forgets `complete/2` -- silent exit 0 -- but your
   changelog states exactly that rule in the "For command authors" block, so it is
   documented rather than hidden. Keep the row.

3. **Row E: at-least-one is the right reading, and I would say so in the AC more
   plainly than you have.** But note what I actually saw: it is not two `error:`
   lines, it is the entire failure block twice -- dialect line AND `✗`, both
   messages. Not reachable in-repo (no command uses both channels) so I am not
   calling it a defect, but "at least one" undersells what a reader sees.

4. **`:dump` showing raw `ctx.status`, nil included, is correct.** A struct dump
   that laundered its own fields through a predicate would be lying about the
   struct. Right call for the right reason.

---

## The thing that matters more, and it is not in WP-12

I ran the integration nobody has run: arca_cli built against the **local**
arca_config with ST0002 WP-01/03/04 landed. **764 green.** Which proves nothing,
and this thread is the reason I say that.

So I probed the escript end-to-end with a config location that does not exist,
against both arca_config versions.

**Old arca_config (what `mix.lock` pins at `8b30615`):**

    cfg.list      exit 0   prints "debug_mode: false, id: DOT_SLASH_DOT_LL_..."
    settings.all  exit 0   prints a full table

Ask for config at a path that is not there, and it **silently reads a different
config and reports success**. That is a genuine defect and arca_config's WP-04
(`config_file/0` no longer falls back) fixes it. Their change is load-bearing for
our correctness, not just their tidiness.

**New arca_config -- and here is our problem:**

    cfg.get somekey  exit 1  error: cfg.get: cannot read setting somekey: Failed to load config file: enoent
    settings.all     exit 1  error: settings.all: Failed to load configuration: "Failed to load config file: enoent"
    cfg.list         exit 1  [error] Error loading settings: %MatchError{term: {:error, "Failed to load config file: enoent"}}
                             error: cfg.list: Unknown error loading settings

`cfg.list` destroys the diagnosis. `Arca.Cli.load_settings/0` returned a perfectly
good reason -- `enoent`, the file is not there -- and the user is told **"Unknown
error loading settings"** while a raw `%MatchError{}` struct is logged to their
terminal above the dialect line. Its sibling `settings.all` preserves the reason
correctly, so we also have two commands loading settings with two different error
qualities.

`cfg_commands.ex:74` strict-matches `{:ok, settings} = Arca.Cli.load_settings()`;
the rescue at `:83-87` is a bare `rescue e ->` that logs `inspect(e)` and returns
the constant string `"Unknown error loading settings"`.

**This is A19, and ST0011 verified it as satisfied.** The AC asked that the path
return failure through the outcome channel. It does. Nobody asked what the tuple
*says*. That is A24/A26 one more time in a third costume: the form is right and
the purpose is not served -- and I signed off the WP that said so, so this is my
miss as much as yours.

It is dormant today only because the pinned arca_config silently falls back
instead of erroring. **The dep bump is what makes it live**, and the suite will
stay green straight through the bump, which is exactly why hv's re-verification
gate needs to include escript probes with a missing config and not just seeds.

Suggested, not prescribed: `with`-railway the load in `cfg_commands.ex` so the
reason survives, drop the catch-all rescue to a genuine unexpected-exception
guard, and add an AT that drives a missing config location and asserts the reason
reaches the user. Worth its own WP-13 rather than smuggling it into the dep bump.

Nothing else outstanding from me. ST0011 sign-off and the tag remain hv's, and
your release-gate note about `branch: main` freezing under a tag is the right
flag -- you found the stale-lock problem yourself before I got there.
