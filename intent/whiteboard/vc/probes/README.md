# Deps-bump verification harness (vc)

The instrument for the single deps bump. hv ruled one bump, not several: when arca_config's ST0002 completes, everything lands at once. That makes the bump the riskiest single event in this thread -- arca_config's eight behaviour changes, the A29 fix, ST0011's whole surface and the 0.5.0 tag all arrive together, and the first moment they are exercised as a set is the same moment they are signed off.

This harness exists so that moment runs an instrument that already works, rather than one written under pressure.

Owned by `vc`. Anyone may run it; only vc edits it.

## Why counts cannot do this job

arca_cli held at **764 green** while built against arca_config with WP-01/03/04 landed, yet its missing-config behaviour changed materially. Nothing in the suite reaches that path. A seed sweep answers order-independence and a suite answers "the paths I exercise still work" -- neither can see a change on a path nobody exercises. Only probes can, so this harness drives the real escript and reads what a user would read.

## Use at the bump

```sh
cd intent/whiteboard/vc/probes

./run.sh capture before-bump        # baseline, on the current pin
# ... mix deps.update arca_config, land the A29 fix, whatever else the bump carries
./run.sh capture after-bump         # a label starting "after"/"post" makes D3 a hard gate
./run.sh diff before-bump after-bump
```

## READ THIS BEFORE MEASURING AN A29 FIX

```sh
./run.sh capture my-fix --local-config    # builds against ../arca_config
```

**Against the pinned arca_config the A29 rows cannot fire.** A missing config silently falls back and reports success, so `cfg.list` never reaches the branch under test and a broken fix measures identically to a correct one. `--local-config` temporarily repoints the dep at `../arca_config`, runs, and restores `mix.exs`/`mix.lock` (restore is trapped, so an interrupt does not strand a path dep). It also forces `phase=after`, because with the local dep those rows are live and must be hard gates.

This was prose in an earlier version of this README and it cost a real non-discriminating run: cc measured an A29 fix against the pinned dep, got clean-looking output, and the artifact said nothing about the fix. That is the harness's fault, not the reader's -- hence the flag, and hence the header below.

Every artifact now states what it actually built:

```
# arca_config BUILT: PINNED @ 8b30615  <-- A29 rows CANNOT fire; the fallback hides them
# arca_config BUILT: LOCAL ../arca_config @ 7b00d31  <-- A29 rows ARE reachable
```

If an artifact says `PINNED`, it carries no information about A29 either way.

`capture` rebuilds the escript first (the release trap: bumping VERSION alone does not rebuild, and a stale binary makes every row a confident lie), runs three probes, writes `artifacts/<label>.{behaviour,ctx,suite}.txt`, and asserts the invariants. `diff` shows behaviour change as a diff rather than as an inference.

## What it probes

| Probe | File | What it answers |
| ----- | ---- | --------------- |
| behaviour | `behaviour_probe.sh` | What the escript actually does: exit codes, dialect lines, cross marks, and the text of the diagnosis |
| ctx matrix | `ctx_matrix.exs` | Does `^error:` still appear **iff** `Ctx.outcome/1` says the command failed, across channel x completion x style |
| suite | (inline) | Compile, format, six seeds, contract status |

## Invariants

- **D1** every SUCCESS row exits 0 with zero dialect lines
- **D2** every FAILURE row exits 1 with exactly one dialect line
- **D3** every MISSCFG row exits 1 with exactly one dialect line
- **D3b** every MISSOK row exits 0 -- config-independent commands must not start needing config
- **D4** no load failure reports `Unknown error loading settings` (the A29 gate)
- **D5** no exception struct leaks into user-facing output

**D3 is the one that flips.** Before the bump the pinned arca_config silently falls back to a different config and reports success, so MISSCFG rows are red *by design* -- that redness is the defect the bump removes. The harness classifies them as `EXPECTED-PRE-BUMP` on a "before" label and as hard failures on an "after" label. Override with `PHASE=before|after` if a label is ambiguous.

## Proven to discriminate

A harness that has never gone red proves nothing, so this one was run in both directions before being committed.

- **`before-bump`** (current pin): PASS, 2 expected-pre-bump -- `cfg.list` and `settings.all` reporting success with the config absent.
- **`after-bump-dryrun`** (arca_cli built against the local arca_config): **2 hard failures**, D4 and D5, both catching A29 exactly -- the destroyed diagnosis and the leaked `%MatchError{}`. D3 went green on its own, which is arca_config's WP-04 landing.

Both artifacts are committed as the reference. `after-bump-dryrun` is a **dry run against a local path dep**, not a real bump; `mix.exs` and `mix.lock` were restored immediately after and the escript rebuilt on the pinned dep.

Two harness bugs were found and fixed by that first dry run, and both are the kind worth naming:

- D4 grepped for `Unknown error`, which matched `cli.error`'s own legitimate help text (`"Unknown error type. Use 'raise'..."`). Now matched exactly.
- D4/D5 scanned the probe's own `##` documentation lines, which name the very strings they hunt for -- a harness failing on its own comments. Doc lines are stripped before scanning.

## Open observation, not yet filed

Post-bump, `about` and `cli.status` emit `[warning] Error loading settings` even though they exit 0 and never read config. Harmless to the contract, noisy to the user, and worth a look during the bump.

## Argv safety

Every probe goes through an array expanded with `"$@"`. Do **not** reintroduce `run $cmd` with an unquoted variable: zsh does not word-split unquoted variables, so a multi-word probe silently runs as one unknown command and every row reports a correct-looking `exit=1 ^error:=1` for entirely the wrong reason. That trap has bitten this project three times -- cc twice, vc once.
