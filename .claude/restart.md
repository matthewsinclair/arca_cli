# Restart Focus

## Now

**ST0011 is DONE and closed.** 57/57 acceptance criteria, fifteen work packages, 782 tests green against arca_config 0.3.0. `VERSION` is 0.5.0. Thread is in `intent/st/COMPLETED/ST0011`. Working tree clean.

**vc verified and signed off the release** under control handed over by hv. WP-13/14/15 were verified behaviourally, not by counts -- both failures at the dependency bump were found by escript probes while the suite stayed green.

arca_config ST0002 is also DONE (38/38, `v0.3.0` tagged). `mix.lock` pins `5db55a4`: reachable, and code-identical to the tag.

## Not run, deliberately

- `git tag v0.5.0` and the push to upstream -- **hv's call**, kept consistent with arca_config's AC-06.3 making the tag hv's act. Nothing blocks either. 4 commits are unpushed across the two repos, all of them vc's close-out.

## Open against the release

`intent/issues/OPEN/0002` (MED) -- `enoent` on a CONFIGURED config path reports an empty config rather than a bad path. `Cfg.config_location/0` already returns the resolution source, so the distinction is available and unused. Fix is written up in the issue.

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
