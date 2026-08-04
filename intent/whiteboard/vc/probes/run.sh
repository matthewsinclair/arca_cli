#!/usr/bin/env bash
#
# run.sh -- the deps-bump verification instrument.
#
#   ./run.sh capture <label>     rebuild, probe, assert, write artifacts/<label>.*
#   ./run.sh diff <a> <b>        diff two captured labels
#   ./run.sh assert <label>      re-run the invariant checks over an artifact
#
# Built BEFORE the bump on purpose. hv ruled one deps bump, not several, so the
# first time everything is exercised together is also the moment it is signed
# off. An instrument written under that pressure is an instrument nobody trusts.
#
# Typical use at the bump:
#   ./run.sh capture before-bump
#   mix deps.update arca_config
#   ./run.sh capture after-bump
#   ./run.sh diff before-bump after-bump

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../.." && pwd)"
ART="$HERE/artifacts"
mkdir -p "$ART"

fail_count=0
expected_count=0
note_fail() { echo "  FAIL: $*"; fail_count=$((fail_count + 1)); }
note_expected() { echo "  EXPECTED-PRE-BUMP: $*"; expected_count=$((expected_count + 1)); }

# PHASE decides whether D3 is a gate or a known-red baseline. Before the bump
# the pinned arca_config silently falls back and reports success, so MISSCFG
# rows are red BY DESIGN and that redness is the thing the bump removes.
# Set PHASE=after (or label the capture "after-*") to make D3 a hard gate.
phase_of() {
  case "${PHASE:-}" in
    before|after) echo "$PHASE" ;;
    *) case "$1" in after*|post*) echo after ;; *) echo before ;; esac ;;
  esac
}

# The probe output includes its own `##` documentation lines, which name the
# very strings D4 and D5 hunt for. Scanning them matches the description
# instead of the defect -- a harness that fails on its own comments. Strip the
# doc lines before scanning; only real probe output is evidence.
probe_output_only() { grep -vE '^(##|#) ' "$1"; }

# assert_artifact <file> <phase>
assert_artifact() {
  local f="$1" phase="${2:-before}"
  echo "## asserting invariants over $(basename "$f")  [phase: $phase]"

  # D1 every SUCCESS row: exit=0, zero dialect lines
  while IFS= read -r line; do
    [[ "$line" == *"exit=0 "* && "$line" == *"^error:=0 "* ]] \
      || note_fail "D1 SUCCESS row not exit=0/^error:=0 -> $line"
  done < <(grep '^SUCCESS ' "$f")

  # D2 every FAILURE row: exit=1, exactly one dialect line
  while IFS= read -r line; do
    [[ "$line" == *"exit=1 "* && "$line" == *"^error:=1 "* ]] \
      || note_fail "D2 FAILURE row not exit=1/^error:=1 -> $line"
  done < <(grep '^FAILURE ' "$f")

  # D3 every MISSCFG row: exit=1, exactly one dialect line.
  # Red before the bump is the defect being visible, not the harness misfiring.
  while IFS= read -r line; do
    if [[ "$line" == *"exit=1 "* && "$line" == *"^error:=1 "* ]]; then
      :
    elif [ "$phase" = before ]; then
      note_expected "D3 $(awk -F'|' '{gsub(/ /,"",$2); print $2}' <<<"$line") reports success with config absent (arca_config WP-04 fixes this)"
    else
      note_fail "D3 MISSCFG row not exit=1/^error:=1 AFTER the bump -> $line"
    fi
  done < <(grep '^MISSCFG ' "$f")

  # D3b config-independent commands must keep working in both phases
  while IFS= read -r line; do
    [[ "$line" == *"exit=0 "* ]] \
      || note_fail "D3b MISSOK row should not need config -> $line"
  done < <(grep '^MISSOK ' "$f")

  # D4 the A29 gate. A destroyed diagnosis still exits 1 and still matches
  # ^error:, so only the TEXT can catch it. Match the exact destroyed message,
  # not any prose containing "unknown error" -- cli.error's own help text says
  # "Unknown error type", which is a legitimate message and not this defect.
  if probe_output_only "$f" | grep -q 'Unknown error loading settings'; then
    note_fail "D4 A29 -- a load failure reports 'Unknown error loading settings' instead of its reason"
    probe_output_only "$f" | grep -n 'Unknown error loading settings' | sed 's/^/       /'
  fi

  # D5 no internal exception struct leaks into user-facing output
  if probe_output_only "$f" | grep -qE '%[A-Za-z.]*(Error|Exception)\{'; then
    note_fail "D5 an exception struct leaked into user-facing output"
    probe_output_only "$f" | grep -nE '%[A-Za-z.]*(Error|Exception)\{' | sed 's/^/       /'
  fi

  # Sanity: the probe must actually have probed. An empty table asserts nothing.
  local rows
  rows=$(grep -cE '^(SUCCESS|FAILURE|MISSCFG|MISSOK) ' "$f")
  [ "$rows" -ge 15 ] || note_fail "only $rows probe rows -- the harness did not run properly"
}

cmd_capture() {
  local label="${1:?usage: run.sh capture <label>}"
  cd "$REPO_ROOT" || exit 1

  echo "## rebuilding escript (release trap: a VERSION bump alone does not rebuild)"
  touch mix.exs
  MIX_ENV=prod mix compile --force >/dev/null 2>&1 || { echo "compile FAILED"; exit 1; }
  MIX_ENV=prod mix escript.build >/dev/null 2>&1 || { echo "escript build FAILED"; exit 1; }

  echo "## behaviour probe"
  bash "$HERE/behaviour_probe.sh" "$label" > "$ART/$label.behaviour.txt" 2>&1
  local rc=$?
  [ $rc -eq 2 ] && { echo "  stale escript, aborting"; cat "$ART/$label.behaviour.txt"; exit 2; }

  echo "## ctx matrix"
  MIX_ENV=test mix run --no-start "$HERE/ctx_matrix.exs" > "$ART/$label.ctx.txt" 2>&1

  echo "## suite"
  {
    echo "# suite -- label: $label"
    MIX_ENV=test mix compile --force --warnings-as-errors 2>&1 | tail -5
    mix format --check-formatted 2>&1 | tail -3
    for s in 1 3 11 77 555 4242; do
      printf 'seed %-6s ' "$s"
      mix test --seed "$s" 2>&1 | grep -oE '[0-9]+ (passed|failure).*' | head -1
    done
    echo -n "contract: "; intent ac status ST0011 2>&1 | tail -1
  } > "$ART/$label.suite.txt" 2>&1

  echo
  assert_artifact "$ART/$label.behaviour.txt" "$(phase_of "$label")"
  grep -q 'RESULT: PASS' "$ART/$label.ctx.txt" || note_fail "ctx matrix did not report PASS"
  grep -q 'failure' "$ART/$label.suite.txt" && note_fail "suite reported failures"

  echo
  if [ "$fail_count" -eq 0 ]; then
    echo "CAPTURE $label: PASS ($expected_count expected-pre-bump) -- artifacts in $ART"
  else
    echo "CAPTURE $label: *** $fail_count INVARIANT FAILURE(S) *** ($expected_count expected-pre-bump)"
  fi
  return "$fail_count"
}

cmd_diff() {
  local a="${1:?usage: run.sh diff <a> <b>}" b="${2:?usage: run.sh diff <a> <b>}"
  for kind in behaviour ctx suite; do
    echo "=============== $kind: $a -> $b ==============="
    if diff -u "$ART/$a.$kind.txt" "$ART/$b.$kind.txt"; then
      echo "(identical)"
    fi
    echo
  done
}

case "${1:-}" in
  capture) shift; cmd_capture "$@" ;;
  diff)    shift; cmd_diff "$@" ;;
  assert)  shift; assert_artifact "$ART/${1:?usage: run.sh assert <label>}.behaviour.txt" "$(phase_of "${1}")"
           [ "$fail_count" -eq 0 ] && echo "ASSERT: PASS" || echo "ASSERT: *** $fail_count FAILURE(S) ***" ;;
  *) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
esac
