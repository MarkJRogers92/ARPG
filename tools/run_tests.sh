#!/usr/bin/env bash
# One command to run every headless test suite and print a single PASS/FAIL
# summary. This is the same aggregation CI does in .github/workflows/build.yml,
# so a green CI means the same thing locally.
#
#   tools/run_tests.sh [-g /path/to/godot] [-t "tools/tests.gd ..."] [-l]
#
#   -g  Godot binary (default: $GODOT, then `godot`)
#   -t  only these suites (space-separated list; each is re-run from scratch)
#   -l  list the suites and exit
#
# Every suite gets --fixed-fps 60 so tests that need a fixed timestep
# (resume_test, smoke-style bots) behave the same as the plain unit ones.
# aim_test.gd needs a real display (it moves the mouse cursor), so it is not
# in the default list; run it separately under xvfb on a server.
#
# Exit code 0 iff every suite passed; logs land in a temp dir and failures
# print their last lines.

set -u

GODOT_BIN="${GODOT:-godot}"
ONLY=""
LIST=false

while getopts "g:t:l" opt; do
  case "$opt" in
    g) GODOT_BIN="$OPTARG" ;;
    t) ONLY="$OPTARG" ;;
    l) LIST=true ;;
    *) echo "usage: $0 [-g /path/to/godot] [-t 'tools/...'] [-l]" >&2; exit 2 ;;
  esac
done

# Suite list: script then optional user args -- which some fixtures need
# for headless contract checks (menu_polish).
SUITES=(
  "tools/tests.gd"
  "tools/ui_test.gd"
  "tools/skill_ui_test.gd"
  "tools/objective_props_test.gd"
  "tools/specialist_variants_test.gd"
  "tools/resume_test.gd"
  "tools/menu_polish_ui_test.gd -- --screen=behavior"
  "tools/campaign_backdrop_test.gd"
  "tools/campaign_camp_life_test.gd"
  "tools/campaign_combat_tests.gd"
  "tools/campaign_first_expedition_test.gd"
  "tools/campaign_guidance_test.gd"
  "tools/campaign_lifecycle_test.gd"
  "tools/campaign_loadout_test.gd"
  "tools/campaign_settlement_stories_test.gd"
  "tools/campaign_sound_lifecycle_test.gd"
  "tools/campaign_tests.gd"
  "tools/campaign_ui_test.gd"
  "tools/campaign_walk_town_test.gd"
  "tools/campaign_waystop_visual_test.gd"
  "tools/campaign_waystops_test.gd"
  "tools/campaign_world_progression_test.gd"
)

if [ -n "$ONLY" ]; then
  SUITES=()
  for s in $ONLY; do SUITES+=("$s"); done
fi

if $LIST; then
  for s in "${SUITES[@]}"; do echo "${s%% *}"; done
  exit 0
fi

if ! command -v "$GODOT_BIN" >/dev/null 2>&1 && [ ! -x "$GODOT_BIN" ]; then
  echo "godot binary not found: '$GODOT_BIN'" >&2
  echo "pass -g /path/to/godot or set GODOT" >&2
  exit 2
fi

LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR" 2>/dev/null || true' EXIT

FAILED=()
PASSED=()

for entry in "${SUITES[@]}"; do
  suite="${entry%% *}"
  extra="${entry#"$suite"}"
  log="$LOG_DIR/$(basename "$suite").log"
  # shellcheck disable=SC2086 # $extra splits into user args on purpose
  "$GODOT_BIN" --headless --path . --fixed-fps 60 -s "$suite" $extra >"$log" 2>&1
  code=$?
  if [ $code -eq 0 ]; then
    PASSED+=("$suite")
    echo "PASS  $suite"
  else
    FAILED+=("$suite")
    echo "FAIL  $suite (exit $code)"
  fi
done

echo
echo "== $((${#PASSED[@]} + ${#FAILED[@]})) suites: ${#PASSED[@]} passed, ${#FAILED[@]} failed =="

if [ ${#FAILED[@]} -ne 0 ]; then
  for suite in "${FAILED[@]}"; do
    echo "--- last lines of $suite ---"
    tail -8 "$LOG_DIR/$(basename "$suite").log"
  done
  exit 1
fi
