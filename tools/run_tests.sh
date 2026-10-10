#!/usr/bin/env bash
# One command to run every headless test suite and print a single PASS/FAIL
# summary. This is the same aggregation CI does in .github/workflows/build.yml,
# so a green CI means the same thing locally.
#
#   tools/run_tests.sh [-g /path/to/godot] [-t "tools/tests.gd ..."] [-l] [-T SECONDS]
#
#   -g  Godot binary (default: $GODOT, then `godot`)
#   -t  only these suites (space-separated list; each is re-run from scratch)
#   -l  list the suites and exit
#   -T  per-suite timeout in seconds (default: 300; a hung suite is killed,
#       reported as TIMEOUT, and the run keeps going)
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
SUITE_TIMEOUT=300

while getopts "g:t:lT:" opt; do
  case "$opt" in
    g) GODOT_BIN="$OPTARG" ;;
    t) ONLY="$OPTARG" ;;
    l) LIST=true ;;
    T) SUITE_TIMEOUT="$OPTARG" ;;
    *) echo "usage: $0 [-g /path/to/godot] [-t 'tools/...'] [-l] [-T seconds]" >&2; exit 2 ;;
  esac
done

# Suite list: script then optional user args -- which some fixtures need
# for headless contract checks (menu_polish).
SUITES=(
  "tools/tests.gd"
  "tools/approved_collection_test.gd"
  "tools/decor_composition_test.gd"
  "tools/decor_cache_test.gd"
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
  "tools/campaign_ui_test.gd -- --screen=behavior"
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
  flag="$log.timeout"

  # Portable per-suite timeout: background the suite, watch it with a killer
  # sleeper (GNU timeout is not on macOS runners).
  # shellcheck disable=SC2086 # $extra splits into user args on purpose
  "$GODOT_BIN" --headless --path . --fixed-fps 60 -s "$suite" $extra >"$log" 2>&1 &
  pid=$!
  ( sleep "$SUITE_TIMEOUT"; kill -9 "$pid" 2>/dev/null; echo >"$flag" ) &
  watcher=$!
  wait "$pid" 2>/dev/null
  code=$?
  kill "$watcher" 2>/dev/null
  wait "$watcher" 2>/dev/null

  if [ -f "$flag" ]; then
    FAILED+=("$suite")
    echo "TIMEOUT  $suite (no exit within ${SUITE_TIMEOUT}s)"
    echo "--- last lines of $suite ---"
    tail -8 "$log"
  elif [ $code -eq 0 ]; then
    PASSED+=("$suite")
    echo "PASS  $suite"
  else
    FAILED+=("$suite")
    echo "FAIL  $suite (exit $code)"
    # Suites push_error("FAIL: ...") for failing assertions; surface those
    # lines directly instead of hoping they land in the tail window.
    fails=$(grep "FAIL: " "$log" | head -15)
    if [ -n "$fails" ]; then
      echo "--- failing assertions in $suite ---"
      echo "$fails"
    fi
    echo "--- last lines of $suite ---"
    tail -8 "$log"
  fi
done

echo
echo "== $((${#PASSED[@]} + ${#FAILED[@]})) suites: ${#PASSED[@]} passed, ${#FAILED[@]} failed =="

if [ ${#FAILED[@]} -ne 0 ]; then
  exit 1
fi
