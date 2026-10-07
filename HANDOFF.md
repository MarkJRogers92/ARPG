# Handoff: the "do all the suggestions" work

Branch: `claude/peaceful-cray-0lvjcv` (pushed; no PR opened).
Game: Soulbound, a Godot 4.6 survivors-like (see `README.md`).

## Status

| # | Item | State |
|---|---|---|
| 1 | Mid-boss variety | **Done**, tested, documented in the README |
| 2 | New specialist enemies | To do (design below) |
| 3 | A hero with a different core weapon | To do |
| 4 | Altar relics and meta unlocks | To do |
| 5 | Settings: rebinding, photosensitivity, high-visibility telegraphs, aim assist | To do |
| 6 | Suspend and resume a run | To do |
| 7 | "Why I died" recap | To do |
| 8 | Daily Night sharing and history | To do |
| 9 | CI: Windows and Linux exports | To do |
| 10 | README refresh and balance re-run | To do (the mid-boss README part is done) |

Suggested order: 2, 3, 4 (content), then 5, 7, 8 (UI and settings), then 6, 9, and
10 last, because the README and the balance numbers should describe the final game.

## What was done: mid-boss moves

- `scripts/mid_mechanics.gd` (`MidMechanics`), wired into `scripts/main.gd`
  (`_mid_mech`: created next to `_final_mech` in `_ready()`, ticked right after
  `_bosses.tick(delta)`, hint shown through the same `set_bet` chain).
- Ogre Warlord: shockwave you dash through. Troll Chieftain: rime armor that only
  chill cracks (`chill[]` on the Bosses swarm, shared `damage_taken`). Magma Lord:
  lava pools. Later bosses are harder (`power()`).
- Tests: `_test_mid_mechanics` in `tools/tests.gd`.
- Commits: `e567daa` (feature) and `64a3258` (README).

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

## To do, in detail

### 2. New specialist enemies

Add a shieldbearer, a healer/buffer and an exploder, with a name per realm
(for example Bone Shieldbearer / Rime Warden / Obsidian Guard).

How enemies work (`scripts/enemy_swarm.gd`): an enemy is a row in flat arrays, not a
node. Each type is one `EnemySwarm` node in `scenes/main.tscn` with exports
(`max_hp`, `move_speed`, `spawn_start_time`, `spawn_share`, `charger`,
`raise_interval`, `captor`...). The wave director and `main.gd` find swarms
automatically through the `enemy_swarms` group. `Realm.REALMS[...]["enemies"]` gives
each node a label, model and color per realm. Lancers (`charger`) and Gravediggers
(`raise_interval`, `hold_range`) are the pattern to copy. Add exports in a
"Specialists" group, per-row state arrays (resize in `_ready`, set in `spawn`, copy in
`_flush_dead`), and signals for anything `main.gd` has to react to.

Suggested designs:

- **Shieldbearer:** shrugs off direct hits but not area or over-time damage. Every
  hit goes through `Elements.hit()`, and each weapon sets `Elements.source` first
  ("Magic Bolt", "Reaping Scythe", "Chain Lightning"...). Cut damage from a set of
  "direct" sources and let burn, Frost Aura, Arcane Nova, reactions ("Reactions") and
  the Soul Army through. Note `EnemySwarm.damage()` has no source, so the check has to
  sit in `Elements.hit()` (or take a `direct` flag). Show it visually (shield-flash on
  a blocked hit) and tell the player once with a toast, like Gravediggers do.
- **Healer/buffer:** stays back (`hold_range`), and periodically heals or speeds up
  nearby enemies, with a visible ring so it can be targeted first.
- **Exploder:** runs at the hero and detonates after a short telegraphed fuse (use
  `HazardDirector.make_decal` for the circle). Hits the horde too.

Things to check before adding a swarm node:

- `Army` raises minions by enemy type: look at `Army.type_index(swarm)` and
  `Army.soul_value` to see whether a new swarm needs a role in `Army.role_of`.
- Models: `model` is an `@export_enum` list on `EnemySwarm`; add builders to
  `Models.enemy()` in `scripts/visual/models.gd`, or reuse an existing model with a
  new color.
- Tests that enumerate swarms or realm entries (`_test_realms`, `_test_specialists`)
  may need updates. Add a test per new behavior next to `_test_specialists`.
- Balance: cap how many can be alive (capacity), as for Cultists (80) and Lancers
  (120), and re-run the bot.

### 3. A hero with a different core weapon

Today every hero is a bolt-firing mage; classes in `scripts/hero_class.gd`
(`HeroClass.CLASSES`) are stat modifiers plus innate powers. Add a fifth hero whose
main attack is the Scythe, Bell or Obol. Check first how `player.gd` gates the
always-on bolt and how weapons are granted (`_update_*` methods, `PlayerStats`
flags). Probably needs a "no bolt" stat or flag, plus starting the chosen weapon
at rank 1. Also add the hero's three paths in `scripts/specializations.gd` (every
hero has one set), a cost (the others are 30-50 Soul Shards) and a robe look. The
title screen hero picker is in `scripts/title_screen.gd`. Add to `_test_heroes`.

### 4. Altar relics and meta unlocks

The Altar (`MetaProgress.UPGRADES` in `scripts/meta_progress.gd`) is seven flat stat
bumps, and heroes cost only 30-50 shards, so shards have nowhere interesting to go.
Ideas, in order of value:

- A **relic slot** chosen on the title screen before a run (a small set of
  build-changing relics that apply modifiers or flags through `PlayerStats`, the
  same way legendary powers do, see `ItemData.POWERS`).
- **Starting weapon** choice.
- **Unlockable level-up cards** (extra entries in `Upgrades.DEFS` that only enter the
  pool once bought).
- Bestiary stars that unlock something instead of only +1% damage.

Saves: `MetaProgress` writes `user://meta.save` (`SAVE_VERSION = 2`) atomically with a
`.bak`. Add new fields with safe defaults in `load_save()` and keep old saves
loading; extend `_test_meta_progress` / `_test_replayability`. The Altar screen is
part of the end screen in `scripts/hud.gd` (`show_game_over`); the title screen
(`scripts/title_screen.gd`) holds the Crypt, Bestiary, Pact of Night and Ascension
screens, which is the pattern to copy for a relic picker.

### 5. Settings

`scripts/pause_menu.gd` only has music, sfx, shake and damage numbers
(`MetaProgress.SETTINGS`, saved with the meta file; `main.gd.apply_settings()` applies
them). Add:

- **Key rebinding:** actions are in `project.godot` `[input]`. Rebind with `InputMap`
  and save the events in `MetaProgress.settings`. Note the hint texts in the HUD and
  README mention specific keys.
- **Photosensitivity toggle:** turn off or tone down the Glitch shader
  (`shaders/glitch.gdshader`, driven by `RiftDirector`), hit-stop and slow motion
  (`Juice.hitstop` / `Juice.slow_motion`), light flashes (`Juice.flash`) and bright
  screen flashes.
- **High-visibility telegraphs:** most ground telegraphs go through
  `HazardDirector.make_decal` (hazards, boss slams, meteors, seals, and now the
  mid-boss waves and pools), so one tint function there covers them. Lancer lines
  (`EnemySwarm._make_telegraph`) and the Colossus fracture lines
  (`FinalMechanics._line_mat`) use their own materials and need the same treatment.
- **Aim-assist strength** for the auto-aim in `player.gd`.

### 6. Suspend and resume a run

A single save slot ("save and quit" from the pause menu). Items and the skill tree
already have `to_dict()`. The enemies are rows in arrays, so save the hero, clock,
`WaveDirector` (elapsed, pressure), army, boss and event timers, rolls (omen, pacts,
ascension, `_spec_chosen`...) and respawn a horde appropriate to the clock rather than
serializing every enemy. It's a large cross-cutting change: do it after the other
features so it captures their state, and decide per feature what is deliberately not
restored (rifts, Ferryman bargains, rival). The title screen needs a Resume button;
`main.gd` has the flow (`Realm.in_title`, scene reload).

### 7. "Why I died" recap

The end screen already shows damage dealt by source (`Elements.damage_by`,
`Hud.set_report`). Track damage taken per source (contact, shots, slams, hazards,
mid-boss moves) in `Player.take_damage` callers, plus a sampled pressure / HP
timeline, and show the top killer and a short line on the end screen
(`hud.gd show_game_over`). Keep it cheap: it runs during play.

### 8. Daily Night sharing

`Realm.daily_pick` already derives realm, omen and seed from today's date.
`MetaProgress.daily` keeps only the best kill count per date. Add a short shareable
code (date plus seed plus result) and a local history list, shown on the title screen
next to the Daily button.

### 9. CI exports

`.github/workflows/mac-build.yml` builds the Mac app, runs the tests and publishes a
`mac-latest` release. Notable: it triggers on `claude/focused-fermat-m7jhtk`, not on
`main`, despite its header comment. Check which branch should publish. Add Windows
and Linux presets to `export_presets.cfg` and jobs (export templates are cached by
`actions/cache`; the Mac job extracts only `macos.zip`). A web build with the
Compatibility renderer is possible but needs a performance check first (thousands of
MultiMesh enemies in a browser).

### 10. README and balance (last)

- Stale README bits: "Not built yet" lists harder difficulty tiers (Ascension
  exists) and biomes with obstacles (`scripts/obstacles.gd` exists); "The look" says
  nothing is on disk but there are 52 imported `.glb` props.
- Document each new feature, update the project layout list, and the `Tests` section if
  tests were added.
- Re-run `tools/balance.sh` for all three realms. The Frozen and Ember tables in the
  README predate the latest pressure, leveling and army tuning
  (`tools/balance.sh -g $G -s "1 2 3 4" -p "greedy random" -m 19 realm=frozen`).
  A quick check I did after the mid-boss work (8 min, seed 1, greedy bot): no deaths in
  any realm.
