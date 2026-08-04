# vc board archive -- 2026-08-04 (localfold before compact)

Settled content rolled out of the live board. Append-only; never reloaded on pickup.

## Completed DOING

- Provisioned as vc on arca_cli (ST0011) and, later the same day, on arca_config
  (ST0002) by hv direction. One session, two boards, same session_id by design.
- Ownership question resolved by hv: cc@arca_cli builds the ST0011 closing batch,
  vc validates. A separate cc session runs ST0002 in ../arca_config.

## Verification record -- ST0011 (all mine, independently measured)

| Pass                     | Verdict                     | Evidence                                                                 |
| ------------------------ | --------------------------- | ------------------------------------------------------------------------ |
| Plan review (pre-build)  | SOUND, 7 advisory findings  | 20+ audit claims spot-checked at ca7ba57; only drift was Ctx.complete:263 |
| WP-01..06 + WP-08        | PASS                        | 713 green seeds 7 (piped) + 3 (pty); all A13 legs exit 1 on escript       |
| WP-09 / WP-07 / WP-10    | PASS, PASS, PASS + MED gap  | 710 green x3 seeds; purge grep-zero; MED = 4 undocumented changelog items |
| WP-11 (first claim)      | NOT PASS                    | 728 green but A24 fix inert; `^error:` false for one Ctx channel          |

## Findings I raised that were adopted

- N1 -> A18 / A19 / A20 (A13-class residue: base_sub_command, cfg.list, coordinator).
- N2 -> renderer width pins (closed; I confirmed 91 green at 40/60/100/200 under a
  pty, the route cc's sandbox could not run -- this watch-out is now RESOLVED).
- N3 -> four test env/settings leak sites + a callbacks wipe, fixed in WP-09.
- N4 -> dark features: ErrorHandler conversion trio and the REPL autocomplete pair
  deleted; `owl_table_helper.exs` renamed so ExUnit actually runs it. Utils extras
  and `Output.current_style/1` KEPT by hv ruling (used downstream).
- MED changelog reverse-walk gap -> the "For command authors" block.
- WP-11 Finding 1 (A24 inert, ledgered by cc as A26), Finding 2 (`^error:` gap),
  Finding 3 (AC-07.2 ack not transcribed).

## Settled decisions

- (2026-08-04) hv ACKED the AC-07.2 amendment as written. Change control satisfied:
  cc flagged rather than reading the AC loosely, vc confirmed via `mix deps.tree`,
  hv acked. Relayed for transcription.
- (2026-08-04) RETRACTED by hv, same day: I claimed the 7 deps AC-07.2 conceded to
  arca_config (plus `owl`) were unused chain-wide and could be dropped. They are
  USED DOWNSTREAM. AC-07.2's limit STANDS as cc wrote it; the changelog line stays
  correct permanently; no 0.5.1 note. Retraction sent to both cc nodes.
- (2026-08-04) hv ruled: no `hv` node on either board -- hv is present in-session.
- (2026-08-04) AT-00.1 fixture-app substitution accepted (cc's two-halves proof);
  recommended an E9 release-gate leg in WP-10 instead of a per-run fixture build.

## Stale, retained only as history

- "cc never received my 14:38 rulings relay" -- cost a day of parallel work; cc
  built WP-09/07/10 believing a ruling was still pending. Re-sent 15:49. The
  durable countermeasure is live on the board: RULINGS in the first line.
- "cc is off this board / batch unowned" -- resolved by hv the same afternoon.
