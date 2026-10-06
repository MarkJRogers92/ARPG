# ARPG

A 3D survivors-like (Vampire Survivors / Soulstone Survivors style) with an ARPG
gear layer, built in **Godot 4.6** and designed from the start for **thousands of
enemies on screen**.

Move, auto-attack, kill the horde, collect XP gems, pick an upgrade on every
level-up, loot and equip gear, survive as long as you can.

## Run it

1. Install [Godot 4.6](https://godotengine.org/download) (the standard build, no .NET needed).
2. Open `project.godot` in the editor and press **F5**.

| Input | Action |
|---|---|
| WASD / arrow keys / left stick | Move |
| 1 / 2 / 3, click, Enter | Pick a level-up upgrade |
| Tab / I / gamepad Y | Open or close the inventory (pauses the game) |

Attacks are automatic: *Magic Bolt* fires at the nearest enemy, and *Frost Aura*
(an upgrade) damages everything around you.

The project uses the **Forward+** renderer. If your GPU is old, switch to
*Compatibility* under Project Settings → Rendering → Renderer. Nothing in the
game depends on it.

## Gear and loot

- **Six slots:** weapon, helm, chest, boots, amulet, ring.
- **Four rarities:** Normal, Magic (1-2 affixes), Rare (3-4), Legendary (5, rolled
  in the top half of each range). Higher rarities are rarer; **magic find** shifts
  the odds.
- **Affixes** come from a data table (`scripts/items/item_data.gd`). Each one lists
  the slots it can roll on, a value range, and a weight. Some only appear on Rare+
  (pierce) or Legendary (extra bolts).
- **Item level** follows your level at half rate. Flat stats (HP, armor, flat
  damage) scale with it fully; percentage stats at about a third of that rate;
  magic find not at all.
- **Drops:** each enemy type has a `loot_chance` and `loot_quality` (brutes drop
  more and better). A token budget (`LootManager.drops_per_minute`, default 3)
  caps the total, so a huge late-game kill rate can't flood the ground.
- **Pickup:** walk over loot. It's worn straight away if the slot is empty,
  otherwise it goes to the 24-slot backpack. A full backpack leaves it on the
  ground. Magic and better drops have a light beam; Rare and better show their name.
- **Inventory screen (Tab):** worn gear, backpack (▲ marks likely upgrades), the
  selected item compared against what you wear, live stats, equip / unequip /
  discard, and "equip all likely upgrades". The upgrade hint is a rough score
  from `ItemData.STAT_INFO`, not a promise.

### How stats work

`PlayerStats` holds base values plus modifiers tagged by source, and
`recalculate()` rebuilds the effective numbers:

```
effective = (base + sum(ADD)) * (1 + sum(INCREASED)) * product(1 + MORE)
```

Gear adds ADD / INCREASED modifiers under `gear:<slot>`; level-up upgrades add MORE
modifiers under `upgrade`. Removing a source is exact, so equipping, swapping and
unequipping can't drift. The level-up pool is data too (`scripts/upgrades.gd`).

## How it handles thousands of enemies

Godot nodes, physics bodies and per-node `_process` calls don't scale to
thousands of enemies. So enemies, projectiles and XP gems are **not nodes**:

- Each is a row in flat typed arrays (`PackedVector2Array`, `PackedFloat32Array`, …),
  simulated in one tight loop.
- Each swarm is drawn by **one `MultiMeshInstance3D`**. Every frame the whole
  transform buffer is uploaded in a single call.
- There is no physics body per enemy. Collisions (bolt hits, aura, touching the
  player) use a **spatial hash** rebuilt every frame.
- The horde spreads out using a **density push**: each enemy reads the occupancy
  of its own cell and its four neighbors, a constant cost however packed the
  crowd is. Enemies in a full cell stop advancing, so the horde queues up
  instead of collapsing into one pile.
- Enemies that fall too far behind the player are recycled to the spawn ring, which
  keeps the crowd dense around you without spawning more.

Positions live on the ground plane as `Vector2(x, z)`.

### Frame order (`scripts/main.gd`)

```
player moves
-> each enemy swarm: flush dead, rebuild hash, spread, chase, upload buffer
-> weapons fire, projectiles hit enemies, aura ticks
-> contact damage to the player
-> gems magnetize and get collected, loot is picked up
-> wave director spawns
```

Enemy deaths are only *marked* during the frame (and the XP gem and loot roll
happen immediately); the row is removed at the start of the next swarm step. That
keeps every index stable for all the queries in between. If you add something
that queries enemies, run it after the swarm `step()` and don't hold indices
across frames.

### Measured performance

Script time per frame, measured headless on a 4-core cloud container (so treat it
as a relative number, not a promise about your machine). This is GDScript only and
**excludes GPU rendering**. These were measured on the swarm and game loop before
the gear and loot layer was added; that layer adds a handful of nodes and some
per-kill work, but it has not been re-benchmarked.

| Enemies | Swarm update | Full game loop |
|---|---|---|
| 1,000 | 1.6 ms | |
| 4,000 | 4.6 ms | |
| 8,000 | 7.5 ms | 7.8 ms |
| 16,000 | 13.7 ms | |

The 60 fps budget is 16.7 ms. The cost stays flat as the crowd packs tighter.
Visuals were checked by rendering with a software GL driver, which is far too slow
to say anything about real GPU performance, and Forward+ itself was not exercised
there. Run `tools/bench_swarm.gd` on your own machine and check the in-game FPS
counter (bottom left).

If you outgrow this: parallelize the per-enemy loop with `WorkerThreadPool`, move
the hot loop to C# or a GDExtension, or step far-away enemies less often.

## Balance

`tools/balance_bot.gd` plays whole runs headless with a bot that kites crowds,
collects gems, takes upgrades by a build policy (`greedy`, `tank`, `random`) and
manages gear. `tools/balance.sh` runs many seeds in parallel and prints
per-minute averages. The bot is a consistent yardstick for comparing settings,
**not** a stand-in for a person.

Current defaults, 4 seeds each, 10 minutes of game time:

| Policy | Survived | Level at 10 min | Enemies alive at minutes 3 / 5 / 10 |
|---|---|---|---|
| greedy (damage-first build) | 4 of 4 reached 10:00 | ~63 | ~530 / ~1,130 / ~1,290 |
| random upgrades | all died, 4.0 to 5.3 min | | ~750 / ~1,760 (at 5) |

In a separate 20-minute greedy run (before loot rationing) the horde was at
roughly 4,700-5,000 enemies at the end, close to its peak.

What shaped the curve, from the bot's own data:

- With no starting regeneration the hero bled out from chip damage around minute 4,
  so the opening is 2 bolts and 1.5 HP/s regen.
- Enemy HP scaling that ramped too early killed every build at minutes 3-5; it now
  stays gentle early (linear term over 600 s) and has a squared term so a maxed
  build is still pushed later.
- Spawn rate accelerates (`rate_acceleration`) so the late game fills up.
- Every upgrade maxes out at level ~52, so later levels quietly heal instead of
  opening a menu with nothing to pick.

Expect to retune. Everything is an export on the `WaveDirector`, the swarms and
`Player` (see Tuning), and the bot can override them without editing files:

```sh
tools/balance.sh -g /path/to/godot -s "1 2 3 4" -p "greedy random" -m 10 \
    director.rate_acceleration=0.0004 Brutes.spawn_share=0.3 base.regen=2
# -f 30 simulates at 30 fps, about twice as fast (43 s vs 91 s for 4 ten-minute
# runs here). I haven't compared its results against 60 fps, so only use it to explore.
```

## Tests

```sh
godot --headless --path . -s tools/tests.gd                      # unit tests
godot --headless --path . -s tools/ui_test.gd                    # drives the real inventory screen
godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd  # bot playthrough, exit 0 = ok
godot --headless --path . -s tools/bench_swarm.gd                # simulation cost, 1k..16k enemies
```

- `tests.gd` covers the modifier math, upgrades, item generation across every
  slot / rarity / item level, the rarity distribution (with and without magic
  find), serialization, inventory and stat syncing, loot drops and the drop
  budget, and the wave director's spawn schedule. Exit code 0 means everything
  passed.
- `ui_test.gd` opens the inventory with the real input action, checks the pause,
  selects, equips, discards and closes it.
- `smoke_test.gd` runs a dumb bot for a minute (or `-- 600` for ten); one minute
  of game time takes about a second.

After adding scripts, open the project in the editor once (or run
`godot --headless --path . --import`) so Godot generates their `.uid` files, and
commit those too.

## Project layout

```
scenes/
  main.tscn            The game: ground, lights, camera, swarms, loot, HUD
  player.tscn          The hero (CharacterBody3D) + aura/ring visuals
scripts/
  main.gd              Game loop, owns update order, level-up flow
  enemy_swarm.gd       A horde of one enemy type (one node per type)
  projectile_swarm.gd  Bolts, pierce, hit memory
  gem_swarm.gd         XP gems and magnet pickup
  spatial_hash.gd      Grid hash: radius queries + density push
  multimesh_util.gd    MultiMesh setup / buffer helpers
  player.gd            Movement, Magic Bolt, Frost Aura, XP, levels
  player_stats.gd      Base values + modifiers -> effective stats
  upgrades.gd          The level-up pool (data + apply())
  wave_director.gd     Spawn rate / HP curves and enemy mix over time
  hud.gd               HUD, level-up menu, toasts, game over (built in code)
  inventory_screen.gd  The Tab screen (built in code)
  ui_style.gd          Shared panel / label look
  camera_rig.gd        Smooth follow camera
  items/
    item_data.gd       Slots, rarities, bases, affixes, text and scoring
    item.gd            One piece of gear (plain data)
    item_generator.gd  Rolls items
    inventory.gd       Worn gear + backpack, keeps stats in sync
    loot_manager.gd    Kill drops, the drop budget, pickup
    loot_drop.gd       An item on the ground
shaders/ground_grid.gdshader   World-space grid so movement is visible
tools/
  tests.gd, ui_test.gd, smoke_test.gd, bench_swarm.gd
  balance_bot.gd, balance.sh
```

## Tuning

- **Difficulty curve:** exports on the `WaveDirector` node (`base_rate`,
  `rate_growth`, `rate_acceleration`, `hp_growth_seconds`, `hp_squared_seconds`).
- **Enemy stats, look and drops:** exports on the `Grunts` / `Brutes` / `Runners`
  nodes in `main.tscn` (HP, speed, contact damage, size, color, capacity, when
  they start spawning and how common they are, loot chance and quality).
- **Crowd feel:** `separation_strength` and `crowd_limit` on each swarm.
- **Leveling:** the XP curve is on the `Player` node.
- **Starting stats:** `PlayerStats.BASE`. **Upgrade strengths:** `Upgrades.DEFS`.
- **Loot:** the tables in `items/item_data.gd`, and `drops_per_minute` on the
  `Loot` node.
- **Camera:** angle, distance and FOV are on the `Camera3D` child of `CameraRig`.

## Extending it

- **New upgrade:** add an entry to `Upgrades.DEFS`. It's data; no code needed unless
  it does something new.
- **New affix or base item:** add a row to `ItemData.AFFIXES` / `BASES`.
- **New stat:** add it to `PlayerStats.BASE` (and a typed field plus a line in
  `recalculate()` if code reads it), then to `ItemData.STAT_INFO` for display.
- **New enemy type:** duplicate the `Brutes` node in `main.tscn` and change its
  exports, including when it starts spawning and its share. The wave director and
  `main.gd` find it automatically.
- **New weapon:** add the state to `PlayerStats`, an `_update_*` method in
  `player.gd` (see `_update_aura` for the query-based pattern or `_update_bolt`
  for the projectile pattern), and upgrades to unlock and improve it.
- **Hit flash / per-enemy color:** turn on `use_colors` in the MultiMesh and write
  a color per instance into the buffer. That makes each instance's slice of the
  buffer longer than the 12 transform floats, so update the layout constants in
  `MultiMeshUtil` and the offsets in the swarms to match.

## Not built yet

Saving and loading (items already serialize with `Item.to_dict()` / `from_dict()`;
use `var_to_str` or `FileAccess.store_var` rather than JSON, which turns ints into
floats), a skill tree, more weapons, ranged enemies, elites and bosses, health
pickups, biomes with obstacles (the player is already a `CharacterBody3D`), and
sound.
