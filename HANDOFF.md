# Handoff: the "do all the suggestions" work

All ten items are done. Items 1-7 and 9 were merged into the default branch
(`claude/focused-fermat-m7jhtk`) as MarkJRogers92/ARPG#20; items 8 and 10
follow in the next PR from `claude/keen-heisenberg-1evqcn`.
Game: Soulbound, a Godot 4.6 survivors-like (see `README.md`).

## Status

| # | Item | Where it lives |
|---|---|---|
| 1 | Mid-boss moves | `scripts/mid_mechanics.gd` |
| 2 | Specialist enemies (Shieldbearers, Menders, Bloaters) | "Specialists" exports in `enemy_swarm.gd`, `scripts/specialists.gd`, `Elements.DIRECT` |
| 3 | The Reaper (scythe instead of bolts) | `hero_class.gd`, `upgrades.gd` (`bolt` / `only`), `specializations.gd`, `abilities/scythe.gd` |
| 4 | The Reliquary: relics, starting weapons, lost lore | `scripts/relics.gd`, `meta_progress.gd` (save version 3), `title_screen.gd` |
| 5 | Rebinding, calm effects, bold warnings, aim assist | `scripts/controls.gd`, `pause_menu.gd`, `Juice.calm` / `warning_color`, `Player.assisted_aim` |
| 6 | Save and quit / resume | `scripts/run_save.gd`, `main.gd` (`capture`, `_restore`), `tools/resume_test.gd` |
| 7 | "Why you died" | `scripts/death_recap.gd`, `Player.take_damage(amount, cause)` |
| 8 | Daily Night codes and history | `scripts/daily_code.gd`, `MetaProgress.daily_runs`, the Daily overlay on the title |
| 9 | Mac, Windows and Linux builds | `.github/workflows/build.yml`, `export_presets.cfg` |
| 10 | README refresh and balance re-run | `README.md` |

## Open questions and follow-ups

- The repo has no `main` branch; the default is `claude/focused-fermat-m7jhtk`, and
  `build.yml` triggers on it (and on `main`, should one appear).
- The Windows build hasn't been run on a real Windows machine yet, and isn't signed
  (SmartScreen will warn).
- The Reaper is slower than the Battlemage in the first minutes and stronger later
  (by design so far; buff its start if players find it sluggish).
- **The final boss takes longer than 4 minutes after dawn.** The game has no
  time limit there, but the balance runs stop at 19:00, and none of the 16 killed
  the boss by then (nor did the code from before this work, 3 Graveyard seeds); the
  README's older table had it falling 50-70 s after dawn. Run with `-m 30` to see
  whether and when the bot wins. Likely from the army / pressure tuning before
  this work. See the README's Balance section.
- Not built: gamepad rebinding, saving during the final fight, a web build, LODs.

## Setting up a fresh session

Godot is not installed in a new container. Download it into its own directory:

```bash
mkdir -p /tmp/godot && cd /tmp/godot
curl -sSL -o godot.zip "https://github.com/godotengine/godot/releases/download/4.6-stable/Godot_v4.6-stable_linux.x86_64.zip"
unzip -q godot.zip && chmod +x Godot_v4.6-stable_linux.x86_64
cd /path/to/ARPG && /tmp/godot/Godot_v4.6-stable_linux.x86_64 --headless --path . --import
```

Checks (all headless):

```bash
G=/tmp/godot/Godot_v4.6-stable_linux.x86_64
$G --headless --path . -s tools/tests.gd 2>&1 | tail -5            # unit tests, ~1 min
$G --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420   # bot walks 7 min of game time
$G --headless --path . --fixed-fps 60 -s tools/balance_bot.gd -- 1 greedy 8 realm=ember   # whole-run bot
```

The last baseline was `ALL TESTS PASSED (58387 checks)`. The one `ERROR: Condition
"(uint32_t)buff.size() != len"` line in the output is the deliberate broken-save test.

### Gotchas learned the hard way

- **Run a real-time bot after every new runtime feature, not just the unit tests.**
  A node you `queue_free()` is only freed a frame later, which unit tests that call
  `tick()` in a loop never see. My mid-boss code kept a reference to a freed marker
  and only the 7-minute bot run showed "Trying to assign invalid previously freed
  instance". Set references to `null` when you free them.
- A stress helper that runs the bot in all three realms at once is worth recreating:
  one `balance_bot.gd` process per `realm=graveyard|frozen|ember`, then
  `grep -c "SCRIPT ERROR"` on each log. 8 minutes each takes about 2 minutes in parallel.
- In unit tests, `Elements.swarms` and `Elements.player` are static and leak between
  tests. Set them explicitly (`Elements.swarms = [boss] as Array[EnemySwarm]`) and
  reset after.
- A swarm needs one `step(0.0, Vector2.ZERO)` after `spawn()` before any area query
  (`Elements.hit_area`, `grid.query`) works, or you get "Out of bounds" errors.
- Always pipe test output through `head` or `tail`. A single bug can print thousands
  of lines.
- The repo commits `.gd.uid` files. After `--import`, `git add` the new ones.
- Commit messages end with the attribution lines from the session reminder.

