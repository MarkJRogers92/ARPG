#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .runtime/{config,cache,data,run} build/creature-qa
export XDG_CONFIG_HOME="$PWD/.runtime/config" XDG_CACHE_HOME="$PWD/.runtime/cache" XDG_DATA_HOME="$PWD/.runtime/data" XDG_RUNTIME_DIR="$PWD/.runtime/run"
chmod 700 "$XDG_RUNTIME_DIR"
export DISPLAY=127.0.0.1:97 XAUTHORITY="$PWD/.runtime/creature-xauth" LIBGL_ALWAYS_SOFTWARE=1
python3 - <<'PY'
import os,subprocess,secrets
p=os.environ['XAUTHORITY'];open(p,'w').close();os.chmod(p,0o600)
subprocess.run(['xauth','-f',p,'add',os.environ['DISPLAY'],'.',secrets.token_hex(16)],check=True)
PY
Xorg :97 -config "$PWD/tools/creature-xorg.conf" -logfile "$PWD/.runtime/Xorg.log" -auth "$XAUTHORITY" -noreset -nolisten unix -nolisten local -listen tcp > .runtime/xorg.log 2>&1 &
XPID=$!
trap 'kill "$XPID" 2>/dev/null || true; rm -f "$XAUTHORITY"' EXIT
sleep 2
for realm in graveyard frozen ember; do
 for mode in old mixed; do
  dir="build/creature-bench/$realm-$mode"
  mkdir -p "$dir"
  timeout 240s godot --path . --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 -s tools/creature_gameplay_qa.gd -- "$realm" "res://$dir" "$mode" bench > "$dir/render.log" 2>&1
  grep 'CREATURE_GAMEPLAY_QA_COMPLETE' "$dir/render.log"
 done
done
