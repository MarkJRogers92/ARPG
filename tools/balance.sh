#!/usr/bin/env bash
# Runs tools/balance_bot.gd for several seeds and policies in parallel and
# summarizes how long each survived.
#
#   tools/balance.sh [-g /path/to/godot] [-s "1 2 3 4"] [-p "greedy tank random"] [-m 20] [-j 4] [-f 60] [overrides...]
#
#   -g  Godot binary (default: $GODOT, then `godot`)
#   -s  seeds                (default: 1 2 3 4)
#   -p  policies             (default: greedy tank random)
#   -m  max minutes per run  (default: 20)
#   -j  parallel runs        (default: number of CPUs)
#   -f  simulation fps       (default: 60; 30 is about twice as fast but unverified against 60, so explore only)
#   overrides: node.property=value, e.g. director.rate_growth=0.1

set -euo pipefail

GODOT_BIN="${GODOT:-godot}"
SEEDS="1 2 3 4"
POLICIES="greedy tank random"
MINUTES=20
JOBS="$(nproc 2>/dev/null || echo 4)"
FPS=60

while getopts "g:s:p:m:j:f:" opt; do
  case "$opt" in
    g) GODOT_BIN="$OPTARG" ;;
    s) SEEDS="$OPTARG" ;;
    p) POLICIES="$OPTARG" ;;
    m) MINUTES="$OPTARG" ;;
    j) JOBS="$OPTARG" ;;
    f) FPS="$OPTARG" ;;
    *) exit 2 ;;
  esac
done
shift $((OPTIND - 1))
OVERRIDES=("$@")

cd "$(dirname "$0")/.."
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

run_one() {
  local seed="$1" policy="$2"
  "$GODOT_BIN" --headless --path . --fixed-fps "$FPS" -s tools/balance_bot.gd -- \
    "$seed" "$policy" "$MINUTES" "${OVERRIDES[@]}" 2>&1 \
    | grep -E '^(T|RESULT|OVERRIDE) ' > "$OUT/$policy-$seed.log" || true
}
export -f run_one
export GODOT_BIN MINUTES OUT FPS
export OVERRIDES_STR="${OVERRIDES[*]:-}"

for p in $POLICIES; do for s in $SEEDS; do echo "$s $p"; done; done \
  | xargs -P "$JOBS" -L 1 bash -c 'OVERRIDES=($OVERRIDES_STR); run_one "$0" "$1"'

echo
grep -h '^OVERRIDE' "$OUT"/*.log | sort -u || true
printf '\n%-8s %5s  %8s  %5s  %6s  %6s  %5s  %s\n' policy seed survived level kills peak items died
for p in $POLICIES; do
  for s in $SEEDS; do
    line="$(grep '^RESULT ' "$OUT/$p-$s.log" | tail -1 || true)"
    [ -z "$line" ] && { printf '%-8s %5s  (no result)\n' "$p" "$s"; continue; }
    get() { sed -E "s/.* $1=([^ ]*).*/\1/" <<<"$line"; }
    printf '%-8s %5s  %7.1fm  %5s  %6s  %6s  %5s  %s\n' \
      "$p" "$s" "$(awk -v t="$(get t)" 'BEGIN{print t/60}')" "$(get level)" "$(get kills)" "$(get peak)" "$(get items)" "$(get died)"
  done
done

echo
echo "per-minute averages across runs that were still going (alive = runs / total)"
for p in $POLICIES; do
  echo "[$p]"
  cat "$OUT"/"$p"-*.log | grep '^T ' | awk -v total="$(echo $SEEDS | wc -w)" '
    {
      for (i = 2; i <= NF; i++) { split($i, kv, "="); f[kv[1]] = kv[2] }
      m = int(f["t"] / 60 + 0.5)
      n[m]++; en[m] += f["enemies"]; lv[m] += f["level"]; it[m] += f["items"]; hp[m] += f["hp"] / 1
    }
    END {
      printf "  %-6s %-7s %9s %7s %7s\n", "min", "alive", "enemies", "level", "items"
      for (m in n) printf "%d %d %.0f %.1f %.1f\n", m, n[m], en[m] / n[m], lv[m] / n[m], it[m] / n[m]
    }' | sort -n | awk -v total="$(echo $SEEDS | wc -w)" '
      NF == 5 { printf "  %-6d %d/%-5d %9d %7.1f %7.1f\n", $1, $2, total, $3, $4, $5; next } { print }'
done

echo
echo "summary (minutes survived)"
for p in $POLICIES; do
  for s in $SEEDS; do
    grep '^RESULT ' "$OUT/$p-$s.log" | tail -1 | sed -E 's/.* t=([^ ]*) .*/\1/'
  done | sort -g | awk -v p="$p" '
    { v[NR] = $1 / 60; sum += v[NR] }
    END {
      if (NR == 0) { printf "%-8s no data\n", p; exit }
      med = (NR % 2) ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2
      printf "%-8s median %5.1f   mean %5.1f   min %5.1f   max %5.1f   (%d runs)\n", p, med, sum / NR, v[1], v[NR], NR
    }'
done
