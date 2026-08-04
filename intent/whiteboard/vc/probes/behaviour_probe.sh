#!/usr/bin/env bash
#
# behaviour_probe.sh -- escript behavioural probe for the single deps bump.
#
# Emits ONE normalised, diffable table describing what the CLI actually DOES.
# Run it before the bump and after the bump; `diff` the two artifacts. A
# behaviour change shows up as a diff line rather than as an inference from a
# passing suite.
#
# WHY THIS EXISTS: arca_cli held at 764 green while built against arca_config
# with ST0002 WP-01/03/04 landed, yet its missing-config behaviour changed
# materially -- `cfg.list` went from "exit 0, silently reads a different config"
# to "exit 1, reports Unknown error loading settings". Nothing in the suite
# reaches that path. Counts and seeds cannot see this class; only probes can.
#
# ARGV SAFETY: every probe is invoked through an ARRAY expanded with "$@".
# Do NOT reintroduce `run $cmd` with an unquoted variable -- zsh does not
# word-split unquoted variables, so a multi-word probe silently runs as ONE
# unknown command and every row reports a correct-looking exit=1 ^error:=1 for
# entirely the wrong reason. That trap has bitten this project three times.
#
# Usage: behaviour_probe.sh <label>        (eg: before-bump, after-bump)
# Output: stdout. Redirect to artifacts/<label>.txt

set -uo pipefail

LABEL="${1:-unlabelled}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
ESCRIPT="$REPO_ROOT/_build/escript/arca_cli"
MISSING_CFG="/tmp/vc-probe-nonexistent-$$"

cd "$REPO_ROOT" || exit 1

# Normalise everything that legitimately varies between runs, so a diff shows
# behaviour changes and nothing else.
normalise() {
  sed -E \
    -e 's/[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+/HH:MM:SS.mmm/g' \
    -e "s|$MISSING_CFG|<MISSING_CFG>|g" \
    -e "s|$REPO_ROOT|<REPO>|g" \
    -e 's|/Users/[a-zA-Z0-9_.-]+|<HOME>|g' \
    -e 's/#PID<[0-9.]+>/#PID<X.X.X>/g'
}

# probe <section> <label> -- remaining args are argv for the escript
probe() {
  local section="$1" desc="$2"; shift 2
  local out rc errs cross first
  out="$("$ESCRIPT" "$@" 2>&1)"; rc=$?
  errs=$(printf '%s\n' "$out" | grep -c '^error:')
  cross=$(printf '%s\n' "$out" | grep -c '✗')
  first=$(printf '%s\n' "$out" | normalise | head -1)
  printf '%-8s | %-22s | exit=%d | ^error:=%-2d | cross=%-2d | %s\n' \
    "$section" "$desc" "$rc" "$errs" "$cross" "$first"
}

# probe_full -- same, but keeps the first N lines. Used where the QUALITY of the
# diagnosis is the thing under test, not just its presence (this is the A29 class:
# the tuple had the right shape and said the wrong thing).
probe_full() {
  local desc="$1" lines="$2"; shift 2
  local out rc
  out="$("$ESCRIPT" "$@" 2>&1)"; rc=$?
  printf -- '--- %s (exit=%d)\n' "$desc" "$rc"
  printf '%s\n' "$out" | normalise | head -"$lines" | sed 's/^/    /'
}

# The artifact MUST say what it measured. cc ran this against the pinned
# arca_config and read the result as evidence about an A29 fix that the pinned
# dep makes unreachable -- the numbers looked fine and meant nothing. A header
# that states the resolved dep, not just the label, is what makes that visible.
dep_source="$(grep -oE '\{:arca_config, (github|path): "[^"]+"' mix.exs | sed 's/{:arca_config, //')"
case "$dep_source" in
  path:*) dep_desc="LOCAL ../arca_config @ $(git -C "$REPO_ROOT/../arca_config" rev-parse --short HEAD 2>/dev/null || echo '?')  <-- A29 rows ARE reachable" ;;
  *)      dep_desc="PINNED @ $(grep -oE '"arca_config": \{:git, "[^"]+", "[a-f0-9]+"' mix.lock | grep -oE '[a-f0-9]{40}' | cut -c1-7)  <-- A29 rows CANNOT fire; the fallback hides them" ;;
esac

echo "# behaviour probe -- label: $LABEL"
echo "# arca_cli HEAD:     $(git -C "$REPO_ROOT" rev-parse --short HEAD)$(git -C "$REPO_ROOT" diff --quiet || echo ' +uncommitted')"
echo "# arca_config BUILT: $dep_desc"
echo "# arca_config local: $(git -C "$REPO_ROOT/../arca_config" rev-parse --short HEAD 2>/dev/null || echo n/a) (informational -- NOT what was built unless BUILT says LOCAL)"
echo "# escript version:   $("$ESCRIPT" --version 2>&1 | head -1)"
echo

# The release trap: bumping VERSION does not rebuild. If the escript is older
# than mix.exs the probe is measuring a stale binary and every row is a lie.
if [ "$REPO_ROOT/mix.exs" -nt "$ESCRIPT" ]; then
  echo "!! STALE ESCRIPT -- mix.exs is newer than the binary."
  echo "!! Run: touch mix.exs && MIX_ENV=prod mix compile --force && MIX_ENV=prod mix escript.build"
  exit 2
fi

echo "## A. success paths -- contract: exit 0, zero ^error:"
probe SUCCESS "about"             about
probe SUCCESS "sys.info"          sys.info
probe SUCCESS "cli.history"       cli.history
probe SUCCESS "cli.status"        cli.status
probe SUCCESS "settings.all"      settings.all
echo

echo "## B. failure paths -- contract: exit 1, exactly one ^error:"
probe FAILURE "cli.error ctx"       cli.error ctx
probe FAILURE "cli.error standard"  cli.error standard
probe FAILURE "cli.error exception" cli.error exception
probe FAILURE "cli.error legacy"    cli.error legacy
probe FAILURE "sys.cmd false"       sys.cmd false
probe FAILURE "sys.cmd (no arg)"    sys.cmd
probe FAILURE "unknown command"     nosuchcommand
echo

echo "## C. MISSING CONFIG -- the A29 class. No suite reaches this."
echo "##"
echo "## MISSCFG rows READ config, so with the config absent they must FAIL:"
echo "##   exit 1, exactly one ^error:, and the REASON must survive to the user."
echo "##"
echo "## EXPECTED TO BE RED BEFORE THE BUMP. The pinned arca_config silently"
echo "## falls back to a different config and reports success, which is the"
echo "## defect arca_config's WP-04 fixes. Red here pre-bump is the harness"
echo "## working; red here POST-bump is a real failure."
echo "##"
echo "## MISSOK rows do NOT read config, so they must keep working either way."
export ARCA_CLI_CONFIG_PATH="$MISSING_CFG"
export ARCA_CLI_CONFIG_FILE="config.json"
probe MISSCFG "cfg.get somekey"   cfg.get somekey
probe MISSCFG "cfg.list"          cfg.list
probe MISSCFG "settings.all"      settings.all
probe MISSOK  "about"             about
probe MISSOK  "cli.status"        cli.status
echo
echo "## C2. diagnosis quality -- what the user actually reads."
echo "## A reason destroyed in transit still exits 1 and still matches ^error:."
probe_full "cfg.get somekey" 4 cfg.get somekey
probe_full "cfg.list"        4 cfg.list
probe_full "settings.all"    4 settings.all
unset ARCA_CLI_CONFIG_PATH ARCA_CLI_CONFIG_FILE
echo

echo "## D. invariants (see run.sh; D3 is the one that flips at the bump)"
echo "##   D1 every SUCCESS row: exit=0 and zero dialect lines"
echo "##   D2 every FAILURE row: exit=1 and exactly one dialect line"
echo "##   D3 every MISSCFG row: exit=1 and exactly one dialect line"
echo "##      -- expected RED before the bump, must be GREEN after it"
echo "##   D3b every MISSOK row: exit=0 (config-independent commands keep working)"
echo "##   D4 no C2 block destroys a load diagnosis (the A29 gate)"
echo "##   D5 no C2 block leaks an exception struct to the user"
