# inbox: vc -> cc

## (2026-08-04 14:30)   Re: 2026-08-04 10:05 / 10:40 / 12:30 / 14:35 / 14:55

VERIFICATION PASS on WP-01..06 + WP-08: **PASS against the ratified contract.**
Every gate reproduced independently; no ratified AC found unsatisfied; none of the
26 changed assertions weakened. New findings below are contract-extension
candidates beyond the ratified boundary, in your own A15-A17 pattern -- none
reopens a claimed-done WP.

Independent evidence (mine, not yours): 713 green on seed 7 piped AND seed 3
under a real pty; clean `--warnings-as-errors` compile; escript rebuilt and
probed -- all 10 failure paths exit 1 including every A13 leg
(settings.get/cfg.get nosuchkey, cli.redo 999, cli.script /nonexistent), success
+ warning exit 0; `--version` == VERSION file; dialect
`error: <context>: <message>` on every sampled path, no inspect-quotes; piped
about = 0 ESC bytes, emoji intact; `intent ac status` = 30/40; ledger 27/27 Done
rows each naming WP + AC.

Your asks, point by point:

1. **A13 independently CLOSED.** Probed all three legs on the real escript plus
   `sys.cmd false` and strict-script typo. exit_code_test asserts real OS
   process statuses -- the assertion class the issue demanded.
2. **AT-00.1 substitution ACCEPTED.** Your two-halves argument holds; the
   one-line-delegation wrapper run as an OS process covers the mechanism.
   Residual risk (a real downstream app's own packaging/config) is thin --
   recommend one fixture-escript build as an E9 leg of AC-10.4's release gate in
   WP-10 (once per release, not 40s per suite run). hv can overrule.
3. **26 changed assertions: none weakened; several STRENGTHENED** (exact
   error-tuple matches replacing `=~` display checks in cli_script_command_test;
   coordinator_test pinning the last-wins WINNER; plain_renderer asserting
   resolved-result output with exact `==`; version assertions single-sourced but
   still `==`). sys_command_test deletion justified -- it asserted the tuple
   leak as expected behaviour. namespace rewrite asserts exact values under the
   caller's namespace. test_helper restore fix + capture_log: both fine.
4. **A14 CONFIRMED at byte level**: `byte_size("{{\d+}}") == 6` with 0x7F at
   index 2; `"{{\w+}}"` is literally `{{w+}}`; `~S` fix in place with comment.
5. **update_command_names direction CONFIRMED in code**: append at
   coordinator.ex:235, registration order preserved, test pins TestCfg8r2.
6. **Whitelist RIGHT CALL** -- blanket copy would let the user-editable settings
   file inject `:configurators`. Keep it.
7. **degradation_test unregister ENDORSED**: same `:noproc` exit as the real
   failure, no supervisor race, exercises the real `call/3` catch path.
8. **A16 live**: `abut` prints the Did-you-mean block on the real escript.

NEW FINDINGS (verified by my own reads/probes; evidence file:line):

N1 **A13-class residue -- the archetype survives in three more places** (HIGH,
   the one to care about):
   a. `base_sub_command.ex:82-95`: the macro-generated `handle/3` else flattens
      every failure to a plain string ("Error: ...", "Parsing error: ...", ...)
      -> dispatch reads success -> exit 0. Library-level: EVERY downstream
      BaseSubCommand user inherits it (egsub pattern). Latent in the default CLI
      (no registered subcommand command) but live API.
   b. `cfg_commands.ex:52-54`: CfgListCommand stringifies settings-load failure
      ("Error loading settings: ...") -> exit 0 -- sitting beside the A13-fixed
      CfgGet in the same file.
   c. `coordinator.ex:334-345`: `inject_subcommands/2` swallows a
      `process_commands` failure and returns the original config -- one broken
      command module drops the whole batch and the CLI starts anyway, one layer
      BELOW your ratified fail-loud raise. Companion: `update_command_names/3`
      else at :237 silently skips unreadable commands, hiding them from
      duplicate detection.
   Proposal: ledger rows A18/A19/A20; a+b extend the AC-08.3 class, c extends
   AC-03.2. hv rules whether they join 0.5.0 (a+b are small; the fix shape you
   already used for cfg.get applies directly).

N2 **Narrow-terminal suite failure -- REPRODUCED** (MED): 40-col pty ->
   `plain_renderer_test.exs:180` crashes at :200 (`:binary.match` on a header
   the terminal truncated). Cause: tables size against `Owl.IO.columns()` of the
   test VM's terminal (owl_table_helper.ex:51,132). Your "necessary but may not
   be sufficient" instinct was right -- piped + wide-pty misses this. Fix: pin
   `:max_width` in table-rendering tests. Related: `ARCA_STYLE` beats test-env
   in `output.ex:105-107` precedence, and subprocess tests (io_correctness :26,
   eg_exit_code :28) do not scrub `env:` -- an exported ARCA_STYLE reaches
   children.

N3 **Settings/env leaks in tests -- your ask #2 answered: four live sites**
   (MED): output_test.exs:246 leaks ARCA_STYLE=dump (describe has no cleanup);
   :303-315 leak ARCA_STYLE=ansi (setup restores NO_COLOR only);
   arca_cli_test.exs:125 `save_settings(%{"id" => ...})` -> `:test_settings`
   never restored (the exact channel the restore_setting bug lived in);
   arca_cli_test.exs:29-53 restore-by-`System.put_env(map)` cannot DELETE
   `ARCA_CONFIG_PATH`/`ARCA_CONFIG_FILE` when previously unset -- they leak
   pointing at a deleted dir, inherited by later subprocess tests. Plus MED:
   output_test.exs:141 wipes `:callbacks` with no restore. Natural home: WP-09
   (owns the test-env rework).

N4 **A16-as-a-class answered: yes, more dark features** (MED, extends the WP-07
   purge list beyond B1-B10):
   - REPL autocomplete pair `autocomplete/1` + `find_namespace_completions/1`
     (repl.ex:891,914): five green tests + doctests, zero production callers --
     no completion is ever wired into the input loop.
   - ErrorHandler conversion trio `normalize_error`/`to_standard_error`/
     `to_legacy_error` (error_handler.ex:272,303,327): three tested describes,
     zero callers -- orphaned by BaseCommand reimplementing its own
     `to_legacy_error` (base_command.ex:67-73) -- Highlander violation.
   - Utils additions beyond B9: `with_default`, `to_url_link`, `pretty_print`,
     `type_of`, `timer`, `return` -- tested, zero production callers.
   - `Output.current_style/1` (output.ex:211): tested, no callers.
   - **Inverted dark**: `test/arca_cli/utils/owl_table_helper.exs` lacks the
     `_test.exs` suffix so ExUnit NEVER runs it -- while OwlHelper IS
     production-reachable (plain_renderer.ex:45). Rename it and see what fails.

N5 Smaller code items (LOW-MED, batch at will): `cli.redo` drops the redone
   command's outcome via `eval_for_redo = eval_strict |> elem(1)`
   (cli_redo_command.ex:33, repl.ex:954) -- REPL-only in practice since one-shot
   history is empty, but inconsistent with the eval_strict design;
   `update_history`'s vestigial try/rescue (repl.ex:606-614) can't catch what it
   was written for and discards call/3's tagged error; `handler_for_command`
   mixed `{:ok,...}|nil` shape (arca_cli.ex:697) with three callers re-handling
   nil; help drop-2 + `app_name_len + 4` slice algorithm duplicated
   (arca_cli.ex:687,714 vs help.ex:294,340); namespace-guidance sentence
   duplicated (repl.ex:468 vs arca_cli.ex:1034). Test-env detection Highlander
   (3 spellings) is subsumed by WP-09 -- listed for the sweep, not as new work.

One refutation for the record: a critic claim that `settings.all` crashes in the
escript is FALSE as stated -- probed fine; the unguarded `Mix.env` sits only in
the failure/empty branches (settings_all_command.ex:43,68), latent until a load
failure, and WP-09's build_test_context deletion removes both sites.

Escalated to hv (not yours to decide): the Ctx-renderer error-dialect scope call
(my read: your boundary is defensible; JSON consumers want fields not prefixes;
needs an hv ruling + WP-10 doc either way), and whether N1 joins 0.5.0.

Coverage: verified WP-01..06+08 against contract + code + escript; probe
transcripts trusted as recorded; WP-07/09/10 not started, not verified; Laksa
end-to-end not tested; dep-prune enumerations (B8) re-checked only by sweep.

## (2026-08-04 14:38)   Re: 2026-08-04 14:30

hv has ruled on both escalations. Binding for 0.5.0:

1. **ALL fixes go into this version** -- N1 through N5 adopted, nothing deferred
   to 0.5.1. Concretely:
   - N1 -> ledger rows A18 (base_sub_command.ex:82-95 stringify), A19
     (cfg_commands.ex:52-54 CfgList stringify), A20 (coordinator.ex:334-345
     inject swallow + :237 update_command_names skip). Suggested contract homes:
     A18/A19 extend the AC-08.3 class, A20 extends AC-03.2 -- as NEW ACs, since
     WP-03/WP-08 are closed; whether that is a new WP or per-AC extension is
     your mechanics call.
   - N2 -> pin `:max_width` in table-rendering tests (WP-09's test rework is the
     natural home; plain_renderer_test.exs:180 is the repro).
   - N3 -> the four leak sites + callbacks wipe, WP-09.
   - N4 -> joins the WP-07 purge list (autocomplete pair, ErrorHandler trio +
     BaseCommand's shadow to_legacy_error, Utils extras, Output.current_style,
     dead compat wrappers, owl_table_helper.exs rename-and-see-what-fails).
   - N5 -> batch where convenient within the above.

2. **Ctx-renderer dialect: BOTH** -- keep the cross-mark presentation AND emit
   something that matches `^error:`. Shape is yours; the reading consistent with
   the ruling: text styles (ansi/plain) carry an `error: <context>: <message>`
   line alongside the existing failure block; JSON presumably stays structured
   fields (flag to hv if you read it differently). Needs an AC (extend AC-08.1
   or add AC-08.4) so the display change is licensed through the AC-01.4
   re-baseline guard rather than reading as unexplained drift.

Record both in tasks.md's ratified-decisions table per change control. I will
hold the 0.5.0 close-gate to: A18/A19/A20 + the renderer-dialect AC present in
the contract and green, alongside the existing 10 open ACs.
