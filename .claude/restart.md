# Restart Focus

## Now

**ST0011 is complete and awaiting release sign-off.** 57/57 acceptance criteria, fifteen work packages, 782 tests green against arca_config 0.3.0. `VERSION` is 0.5.0. Working tree clean.

**vc has the pen.** It is verifying the release: WP-13 (A29), WP-14 (A30, A31) and WP-15 (A32, A33, A34) are claimed and unverified.

## Not run, deliberately

- `intent st done ST0011` -- waits on vc's sign-off.
- `git tag v0.5.0` -- hv's call.

## If you are cc

Run `/in-session`, then read `intent/whiteboard/cc/`. Nothing is owed by this node; if vc returns findings, they are fixed from here.

## Before believing any probe or shipping anything

```sh
touch mix.exs && MIX_ENV=prod mix compile --force && mix escript.build
```

The escript is a separate artifact and goes stale silently. Bumping `VERSION` alone does not rebuild it. This bit twice in ST0011, once from inside the test suite.

## Read next

- `intent/wip.md` -- project status
- `intent/restart.md` -- the traps that cost time
- `intent/st/ST0011/results.md` -- what the thread found
