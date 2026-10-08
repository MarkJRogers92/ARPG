#!/bin/sh
# An isolated playable copy with its own save directory. No app replacement.
set -eu
repo_path=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$repo_path/build"
preview_path=$(mktemp -d "$repo_path/build/specialist-preview.XXXXXX")
python3 - "$repo_path" "$preview_path" <<'PY'
from pathlib import Path
import shutil, sys
source, target = map(Path, sys.argv[1:])
for name in ['assets', 'audio', 'scenes', 'scripts', 'shaders', 'tools']:
    shutil.copytree(source/name, target/name)
config = (source/'project.godot').read_text()
marker = 'config/custom_user_dir_name="Godot/app_userdata/ARPG"'
if config.count(marker) != 1:
    raise SystemExit("Preview aborted: expected Soulbound save setting was not found exactly once.")
config = config.replace(marker,
                        'config/custom_user_dir_name="Godot/app_userdata/Soulbound_Specialist_Variants_Preview"')
(target/'project.godot').write_text(config)
PY
printf 'Preview project: %s\nSeparate save folder: Soulbound_Specialist_Variants_Preview\n' "$preview_path"
if [ "${1:-}" = "--prepare-only" ]; then exit 0; fi
godot --headless --path "$preview_path" --import
exec godot --path "$preview_path" "$@"
