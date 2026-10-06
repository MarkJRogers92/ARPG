# ARPG

A 3D survivors-like (Vampire Survivors / Soulstone Survivors style) with an ARPG
gear layer, built in **Godot 4.6** and designed from the start for **thousands of
enemies on screen**.

Move, auto-attack, kill the horde, collect XP gems, pick an upgrade on every
level-up, spend skill points in a tree, loot and equip gear, survive as long as
you can.

## Run it

1. Install [Godot 4.6](https://godotengine.org/download) (the standard build, no .NET needed).
2. Open `project.godot` in the editor and press **F5**.

| Input | Action |
|---|---|
| WASD / arrow keys / left stick | Move |
| Mouse / right stick | Aim (the hero faces and shoots where you point) |
| T / right stick click | Switch between mouse aim and auto-aim |
| 1 / 2 / 3, click, Enter | Pick a level-up upgrade |
| Tab / I / gamepad Y | Open or close the inventory (pauses the game) |
| K / gamepad Back | Open or close the skill tree (pauses the game) |

Attacks fire on their own: *Magic Bolt* shoots whenever an enemy is in range, and
*Frost Aura* (an upgrade) damages everything around you. Aiming is twin-stick
style: once you move the mouse, the hero faces the cursor and shoots toward it
(a ring on the ground marks the spot) while WASD walks independently, so you can
back away while firing. The right stick aims the same way while held. Until you
touch the mouse, after you release the stick, or after pressing T, bolts auto-aim
at the nearest enemy.

The project uses the **Compatibility** renderer (OpenGL), which runs on nearly any
machine and is the one the game was tested with. If you'd like Forward+ (Vulkan),
switch it under Project Settings → Rendering → Renderer and restart the editor;
nothing in the game depends on the choice, but Forward+ has not been tried.

## The look

Everything you see is built in code: there are no models, textures or icons on
disk. `scripts/visual/models.gd` assembles each model (the hooded hero, the three
enemy types, every item base, bolts, XP crystals and the scenery) out of
primitive shapes with `MeshKit`, which merges them into one vertex-colored mesh.
A part can glow (stored per vertex), and the shaders in `shaders/` do the rest.

- **Enemies:** Grunts are hunched ghouls, Brutes are horned ogres with clubs,
  Runners are burning hellhounds. Each type is still one MultiMesh. The walk
  cycle (swinging legs, bob, sway), the hit flash and the rim light all run in
  `enemy.gdshader`, so the CPU only writes position, facing and a flash value per
  enemy. Soft blob shadows under the horde are a second MultiMesh fed the same
  buffer; real shadow maps for thousands of enemies would cost far more.
- **Hero:** holds the weapon you have equipped (staff, wand or orb, with its gem in
  the item's rarity color), bobs and leans as it walks, thrusts the weapon on
  every volley, and carries a small light.
- **Loot:** each drop shows its own item model floating over a glow ring in its
  rarity color. The inventory renders the same models into icons and shows the
  selected item turning in a preview (see `visual/item_icons.gd`).
- **World:** the ground shader paints grass, dirt and mossy flagstone plazas in
  world space. `WorldDecor` scatters rocks, grass, dead trees, graves, ruined
  pillars, bones, glowing mushrooms and crystals in chunks around the hero;
  each chunk's props come from a seed, so the world stays the same when you walk
  back. Props are decoration only: nothing collides with them.
- **Effects:** kills, bolt hits (bigger and orange on crits), pickups and level-ups
  throw particles from `FxSwarm`, another array-simulated MultiMesh. Glow (bloom),
  fog and a vignette that reddens while you take damage finish the picture.
- **UI:** a shared bronze-on-dark theme (`ui_style.gd`), illustrated level-up cards
  with rank pips, and themed inventory and skill tree screens.

To change the art, edit the colors and shapes in `models.gd` (enemy skins also
follow each swarm's `color` export), the uniforms at the top of each shader, or
the `density` table on the `Decor` node.

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
  ground. Magic and better drops have a light beam (taller for better rarities);
  Rare and better show their name.
- **Inventory screen (Tab):** worn gear, backpack (▲ marks likely upgrades), the
  selected item compared against what you wear, live stats, equip / unequip /
  discard, and "equip all likely upgrades". The upgrade hint is a rough score
  from `ItemData.STAT_INFO`, not a promise.

## Skill tree

You earn a **skill point every 2 levels** (`Player.skill_point_every_levels`; 0 turns
it off) and spend them in a node graph (press K). It sits alongside the level-up
cards: cards are the quick run-by-run picks, the tree is where you steer a build.

- **Four branches** grow from the central Awakening node: **Offense** (bolts,
  crits), **Aura** (unlocked by the Frostbound node), **Defense** (HP, armor,
  regen) and **Utility** (speed, pickup, XP, luck). 27 nodes plus the center.
- **Three tiers:** small nodes cost 1 point, notables 2, keystones 3. Every
  keystone has a real downside, such as Arcane Barrage (+2 bolts, 30% less bolt
  damage) or Juggernaut (+50% max HP and +30 armor, 10% slower).
- **Rules:** you can buy a node when you can pay for it and it's linked to one you
  own. Right-click (or Backspace) refunds a node unless that would cut other nodes
  off from the center, so you can always peel the tree back from its tips. Reset
  refunds everything and is free.
- Buying everything costs 41 points. The damage-first bot earns about 34 in ten
  minutes (level ~69), so even a strong run has to leave some of the tree unbought,
  and weaker runs get far fewer. The choices matter.
- Nodes are data (`scripts/skills/skill_data.gd`) and add stat modifiers under the
  source `skill:<id>`, so they need no stat code.

### How stats work

`PlayerStats` holds base values plus modifiers tagged by source, and
`recalculate()` rebuilds the effective numbers:

```
effective = (base + sum(ADD)) * (1 + sum(INCREASED)) * product(1 + MORE)
```

Gear adds ADD / INCREASED modifiers under `gear:<slot>`, skill nodes add theirs under
`skill:<id>`, and level-up upgrades add MORE modifiers under `upgrade`. Removing a
source is exact, so equipping, swapping, unequipping and refunding can't drift. The level-up pool is data too
(`scripts/upgrades.gd`).

## How it handles thousands of enemies

Godot nodes, physics bodies and per-node `_process` calls don't scale to
thousands of enemies. So enemies, projectiles and XP gems are **not nodes**:

- Each is a row in flat typed arrays (`PackedVector2Array`, `PackedFloat32Array`, …),
  simulated in one tight loop.
- Each swarm is drawn by **one `MultiMeshInstance3D`**. Every frame the whole
  instance buffer (transform, color and custom data, 20 floats each) is uploaded
  in a single call. Animation happens in the shaders.
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
The visual overhaul (enemies turning to face you, hit flashes, a wider instance
buffer and blob shadows) added roughly 10-20% to the swarm update in a
before/after run of `bench_swarm.gd` on the same container (8,000 enemies: 4.4 ms
before, 4.9 ms after).

On the GPU side, enemy models are kept coarse: about 300 triangles for a Grunt
or Runner and 520 for a Brute, so a full late-game horde is a couple of million
triangles a frame. That's fine for a dedicated GPU; on a weak integrated one, the
first thing to try is lowering `MeshKit.max_segments` for enemies in
`Models.enemy()`.
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

Current defaults, 4 seeds each, 10 minutes of game time. The bot spends skill
points by policy (damage-first, or random picks):

| Policy | Survived | Level at 10 min | Enemies alive at minutes 3 / 5 / 10 |
|---|---|---|---|
| greedy (damage-first build) | 4 of 4 reached 10:00 | ~69 | ~360 / ~890 / ~540 |
| random upgrades and nodes | 2 of 4 reached 10:00 (the others died at 4.8 and 5.1 min) | | ~670 / ~1,750 (at 5) |

Before the skill tree the same bot had ~1,290 enemies alive at minute 10, and
every random-pick run died at 4.0 to 5.3 minutes, so the tree adds real power:
it thins a strong build's late game by about 40% and gives weak builds a safety
net. Taking a point every 3 levels instead brings the random-pick runs back to
dying at 4.4 to 5.2 minutes. A 14-minute damage-first run is back up to about 910
enemies by the end and still rising. An earlier 20-minute run without the tree
reached roughly 4,700 to 5,000 enemies, so if you want a bigger late-game horde,
raise `rate_acceleration` on the WaveDirector.

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
godot --headless --path . -s tools/skill_ui_test.gd              # drives the real skill tree screen
xvfb-run godot --path . --fixed-fps 60 -s tools/aim_test.gd     # mouse aim, T toggle, right stick (needs a display)
godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd  # bot playthrough, exit 0 = ok
godot --headless --path . -s tools/bench_swarm.gd                # simulation cost, 1k..16k enemies

# Screenshots of play, the level-up cards, inventory and skill tree. Needs a
# display (not --headless); on a server, wrap it in xvfb-run.
godot --path . --fixed-fps 60 -s tools/screenshot.gd -- shots 30          # 30 s of play
godot --path . --fixed-fps 60 -s tools/screenshot.gd -- shots 5 crowd     # start in a big horde
```

- `tests.gd` covers the modifier math, upgrades, item generation across every
  slot / rarity / item level, the rarity distribution (with and without magic
  find), serialization, inventory and stat syncing, loot drops and the drop
  budget, the wave director's spawn schedule, and the skill tree (graph validity,
  allocate and refund rules, exact stat restore, serialization, earning points).
  Exit code 0 means everything passed.
- `ui_test.gd` and `skill_ui_test.gd` open the real screens with the real input
  actions, check the pause, and click through equipping, discarding, allocating,
  refunding (including the refusals), resetting and closing.
- `aim_test.gd` moves the real cursor around the game window and checks that the
  hero faces it, bolts follow it while walking the other way, T switches to
  auto-aim and back, and the right stick takes over while held.
- `smoke_test.gd` runs a dumb bot for a minute (or `-- 600` for ten); one minute
  of game time takes about a second.

After adding scripts, open the project in the editor once (or run
`godot --headless --path . --import`) so Godot generates their `.uid` files, and
commit those too.

## Project layout

```
scenes/
  main.tscn            The game: environment, ground, scenery, camera, swarms, loot, HUD
  player.tscn          The hero (CharacterBody3D), its model, aura and ground ring
scripts/
  main.gd              Game loop, owns update order, level-up flow
  enemy_swarm.gd       A horde of one enemy type (one node per type)
  projectile_swarm.gd  Bolts, pierce, hit memory
  gem_swarm.gd         XP gems and magnet pickup
  fx_swarm.gd          Hit, death, pickup and level-up particles
  spatial_hash.gd      Grid hash: radius queries + density push
  multimesh_util.gd    MultiMesh setup / buffer helpers
  player.gd            Movement, aiming, Magic Bolt, Frost Aura, XP, levels
  player_stats.gd      Base values + modifiers -> effective stats
  upgrades.gd          The level-up pool (data + apply())
  wave_director.gd     Spawn rate / HP curves and enemy mix over time
  hud.gd               HUD, level-up cards, toasts, game over (built in code)
  inventory_screen.gd  The Tab screen (built in code)
  ui_style.gd          Shared UI theme, panels, bars, labels
  camera_rig.gd        Smooth follow camera
  items/
    item_data.gd       Slots, rarities, bases, affixes, text and scoring
    item.gd            One piece of gear (plain data)
    item_generator.gd  Rolls items
    inventory.gd       Worn gear + backpack, keeps stats in sync
    loot_manager.gd    Kill drops, the drop budget, pickup
    loot_drop.gd       An item on the ground
  skills/
    skill_data.gd      The tree: nodes, links, tiers, modifiers
    skill_tree.gd      Owned nodes and points, allocate / refund rules
    skill_tree_screen.gd  The K screen (built in code)
  visual/
    mesh_kit.gd        Builds one mesh out of colored primitive parts
    models.gd          Every model (hero, enemies, items, bolts, gems, props) + materials
    hero_model.gd      The hero's model and its animation
    world_decor.gd     Scenery scattered in chunks around the hero
    item_icons.gd      Item icons and the turning preview, rendered from the models
    ui_icons.gd        Vector icons for the level-up cards
shaders/
  kit.gdshader         Vertex-colored models with glow and rim light
  enemy.gdshader       Enemies: walk cycle, hit flash, rim light
  ground.gdshader      Procedural grass, dirt and flagstones in world space
  gem / glow / particle / beam / ground_glow / aura / blob_shadow / vignette
tools/
  tests.gd, ui_test.gd, skill_ui_test.gd, aim_test.gd, smoke_test.gd, bench_swarm.gd
  balance_bot.gd, balance.sh, screenshot.gd
```

## Tuning

- **Difficulty curve:** exports on the `WaveDirector` node (`base_rate`,
  `rate_growth`, `rate_acceleration`, `hp_growth_seconds`, `hp_squared_seconds`).
- **Enemy stats, look and drops:** exports on the `Grunts` / `Brutes` / `Runners`
  nodes in `main.tscn` (HP, speed, contact damage, size, color, capacity, when
  they start spawning and how common they are, loot chance and quality).
- **Crowd feel:** `separation_strength` and `crowd_limit` on each swarm.
- **Leveling and skill points:** the XP curve and `skill_point_every_levels` are on the
  `Player` node.
- **Starting stats:** `PlayerStats.BASE`. **Upgrade strengths:** `Upgrades.DEFS`.
- **Loot:** the tables in `items/item_data.gd`, and `drops_per_minute` on the
  `Loot` node.
- **Camera:** angle, distance and FOV are on the `Camera3D` child of `CameraRig`.
- **Look:** see "The look" above. Lighting, glow and fog are on the
  `WorldEnvironment` and `Sun` nodes in `main.tscn`.

## Extending it

- **New skill node:** add an entry to `SkillData.NODES` (position, links, modifiers) and
  link it from a neighbor. The screen and the stats pick it up; the tests check that
  every node is connected, uses real stats, and can be bought and refunded.
- **New upgrade:** add an entry to `Upgrades.DEFS`. It's data; no code needed unless
  it does something new.
- **New affix or base item:** add a row to `ItemData.AFFIXES` / `BASES`.
- **New stat:** add it to `PlayerStats.BASE` (and a typed field plus a line in
  `recalculate()` if code reads it), then to `ItemData.STAT_INFO` for display.
- **New enemy type:** duplicate the `Brutes` node in `main.tscn` and change its
  exports, including when it starts spawning and its share. The wave director and
  `main.gd` find it automatically. For a new look, add a builder to
  `Models.enemy()` and its name to the `model` export's list.
- **New weapon:** add the state to `PlayerStats`, an `_update_*` method in
  `player.gd` (see `_update_aura` for the query-based pattern or `_update_bolt`
  for the projectile pattern), and upgrades to unlock and improve it.
- **Per-instance data:** every swarm's buffer already has a color and four custom
  floats per instance (`MultiMeshUtil.OFFSET_COLOR` / `OFFSET_CUSTOM`). Enemies use
  custom x for the hit flash and y for the walk phase, so z and w are free (for
  example for a burning or frozen tint read in `enemy.gdshader`).

## Not built yet

Saving and loading (items and the skill tree already serialize with `to_dict()`;
use `var_to_str` or `FileAccess.store_var` rather than JSON, which turns ints into
floats), more weapons, ranged enemies, elites and bosses, health
pickups, biomes with obstacles (the player is already a `CharacterBody3D`; the
scenery is decoration only), level-of-detail meshes for far-away enemies, and
sound.
