# Soulbound quick start

## Context
- Godot 4.6, GDScript, Compatibility renderer; open `project.godot`, F5 to play.
- Start with relevant sections of `README.md`. Check
  `agent_docs/latest_session_work.md` for recent work; use `HANDOFF.md` for older
  background, not as proof of current branch status or test counts.
- Gameplay code: `scripts/`; scenes: `scenes/`; rendering: `shaders/`;
  assets/audio: `assets/`, `audio/`; test scripts: `tools/`.
- Inspect `git status` before edits and preserve existing uncommitted work.

## Verification (run from this directory)
Use the existing runner, which preserves failure status and limits log output:
```sh
bash tools/run_tests.sh -l                              # available suites
bash tools/run_tests.sh -t "tools/tests.gd"             # core tests
bash tools/run_tests.sh -t "tools/campaign_tests.gd"    # example focused suite
bash tools/run_tests.sh                                # all headless suites
```
Set `GODOT` or pass `-g /path/to/godot` if it is not on PATH. Do not assume
the Linux binary path in the older handoff applies to this Mac.
- Select suites matching the change first; run broader checks for shared systems.
- For new runtime features, also run a real-time smoke bot:
  `"$GODOT" --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420`
  (set `GODOT` to the installed binary first). Save its log and check for script
  errors as well as exit status; report unavailable engine/display checks.
- Visual/input changes need an appropriate in-engine check, not just headless tests.

## Important constraints
- Deferred `queue_free()` can leave stale references: clear references and check
  frame-driven behavior, not only synchronous unit tests.
- Reset static `Elements.player` / `Elements.swarms` in tests. After swarm
  `spawn()`, call `step(0.0, Vector2.ZERO)` before area queries.
- Preserve tracked `.gd.uid` files; review newly generated UIDs for new scripts.
  Do not hand-edit `.godot/` caches or alter release workflows without task need.
- Keep these instructions short; put detailed history in `agent_docs/`.
