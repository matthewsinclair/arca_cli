---
verblock: "04 Aug 2026:v0.1: matts - Thread results and durable findings"
st_id: ST0011
title: "Fable review of arca_cli base code -- results"
---

# ST0011 -- Results

The permanent record of what this thread found, as distinct from what it did. The as-built is in `impl.md`, the contract in `acceptance.md`, the ledger in `tasks.md`.

## Outcome

Fifteen work packages, 57/57 acceptance criteria, 782 tests green against arca_config 0.3.0. 34 confirmed correctness findings, 10 dead-machinery clusters, 15 design-debt items. Issue 0001 closed.

## The three archetypes

The audit found recurring shapes rather than a list of bugs, and 0.5.0 fixes the shapes:

1. **Outcomes discarded in transit.** Every command exited 0, because failure was returned as display text that dispatch could only read as success. A1, A13, A18-A20, A24.
2. **Configuration read but not honoured.** An explicit `false` coerced to `true`; a broken configurator silently replaced by the default. A4, C2.
3. **Environment-dependent behaviour.** ANSI forced into pipes, test-env branches in `lib/`, output that depended on terminal width. A12, A21-A23.

Several fixes were REMOVALS rather than replacements: the forced `ansi_enabled: true`, a duplicate default, the DftConfigurator fallback, four of five error formatters. **When configuration is "not being honoured", look first for a second writer of the same value.**

## The one finding worth carrying elsewhere

**A green test suite cannot tell you whether anything reaches the code it tests.** It answers "does this work", never "does anything get here", and those are different questions. Most of this thread is variations on it:

| finding | the variation                                                                 |
| ------- | ----------------------------------------------------------------------------- |
| A16     | A feature with unit tests and no call path at all.                            |
| A21     | A rule whose deciding variable is never set.                                  |
| A22     | An isolation whose variable never wins.                                       |
| A25     | Testing every implementation of an interface is not testing every state of it. |
| A26     | A construct gate cannot prove the new branch is reachable. Absence-of-the-old is not presence-of-the-new. |
| A28     | Asserting that a line is present cannot catch it being present when it should not be. |
| inverted | `owl_table_helper.exs` -- live production code whose tests ExUnit had never once run. |

## What the thread learned about claiming

These cost more than the code did, and they are the half worth keeping.

- **Predict the failing set before running a mutation, and treat a shortfall as a finding.** A29's tests were predicted to turn 4 red and turned 2. The two that held passed *against the broken code*, satisfied by the very leak they forbade. Counting "some tests went red" would have shipped two weak tests looking rigorous.
- **An assertion that the right text APPEARS is satisfied by wrong output containing it.** Three instances in one day: a `%MatchError{}` leak containing its own reason string; AT-11.7 asserting presence where the claim was really an iff; A34's doubled message. Where a claim is an iff, assert the iff. Where it is "exactly once", count.
- **Completeness claims earn a probe, not a sentence.** The counter is structural -- a cross-product over whatever the claim quantifies over, so a new member of either dimension fails until covered. Every time this bit, the untested COMBINATION was the broken one.
- **When every row of a result table agrees, check the harness can produce disagreement.** A23, A26, and a probe loop where zsh's lack of word-splitting made every row read `exit=1` for the wrong reason.
- **"There is no seam" is a claim to check, not to reason to.** "No seam without mocking" went into an acceptance criterion. The seam was in a file written earlier in this same thread.
- **A repro names an instance; it does not bound the class.** And "dormant until X" is a claim about triggers: A29 was filed as going live at the dep bump, which was true of the missing-config trigger and false of the corrupt-config one.
- **Four of the 34 findings landed after the thread first looked finished**, three of them found by the verifier checking a PASS. A clean verification is where to look next, not where to stop.

## What the thread learned about building

- **A question answered in more than one place is eventually answered differently.** Four sites decided whether a `Ctx` had failed, and two came to disagree with the exit code -- one printing `error:` while exiting 0, the exact inverse of the defect the thread opened with. The fix is not to make them consistent, which is maintenance forever, but to leave one of them. Highlander applies to predicates, not only modules. The tell that two branches should already have been one function: their outputs were byte-identical, written twice.
- **Making a failure visible is what makes its wording matter.** Four times: the coordinator's six messages, History's four, the config-load reason, and arca_config's new error tuples. Ship a dialect pass with any unswallowing.
- **When a fix makes a symptom disappear, check what else it made disappear.** Silencing build-lock noise bought subprocess tests running against a build nobody had compiled, with every `exits 1` assertion still passing.
- **Zero-caller-in-this-repo is necessary but not sufficient for a library.** Downstream calls what this repo cannot see. A probe with no caller -- `register_change_callback/2` -- is invisible to a call-graph search from either side, which is why it is now pinned by a test.

## Cross-repo

arca_cli and arca_config ship together and moved together. arca_config 0.3.0 ratified one error shape, `{:error, {:config, reason, detail}}`, and its rationale names this repository as the reason: arca_cli classified a missing key by testing whether the message contained the words "not found", so rewording a message there was a silent breaking change here. That is fixed on both sides -- an atom to match on there, a match on it here.

The coupling is now asserted rather than remembered, in `test/arca_cli/config_contract_test.exs`.
