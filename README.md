# ARPG

A 3D survivors-like (Vampire Survivors / Soulstone Survivors style) built in
**Godot 4.6**, designed from the start for **thousands of enemies on screen**.
The plan is to grow ARPG systems (loot, builds, skill trees) on top of this core.

Move, auto-attack, kill the horde, collect XP gems, pick an upgrade on every
level-up, survive as long as you can.

## Run it

1. Install [Godot 4.6](https://godotengine.org/download) (the standard build, no .NET needed).
2. Open `project.godot` in the editor and press **F5**.

| Input | Action |
|---|---|
| WASD / arrow keys / left stick | Move |
| 1 / 2 / 3, click, Enter | Pick a level-up upgrade |

Attacks are automatic: *Magic Bolt* fires at the nearest enemy, and *Frost Aura*
(an upgrade) damages everything around you.

The project uses the **Forward+** renderer. If your GPU is old, switch to
*Compatibility* under Project Settings → Rendering → Renderer. Nothing in the
game depends on it.

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
-> gems magnetize and get collected
-> wave director spawns
```

Enemy deaths are only *marked* during the frame (and the XP gem dropped
immediately); the row is removed at the start of the next swarm step. That keeps
every index stable for all the queries in between. If you add something that
queries enemies, run it after the swarm `step()` and don't hold indices across frames.

### Measured performance

Script time per frame, measured headless on a 4-core cloud container (so
treat it as a relative number, not a promise about your machine). This is
GDScript only and **excludes GPU rendering**.

| Enemies | Swarm update | Full game loop |
|---|---|---|
| 1,000 | 1.6 ms | |
| 4,000 | 4.6 ms | |
| 8,000 | 7.5 ms | 7.8 ms |
| 16,000 | 13.7 ms | |

The 60 fps budget is 16.7 ms. The cost stays flat as the crowd packs tighter. I
also rendered the game with a software GL driver to check the visuals, but that's
far too slow to say anything about real GPU performance, and Forward+ itself was
not exercised in that environment. Run `tools/bench_swarm.gd` on your own
machine and check the in-game FPS counter (bottom left).

If you outgrow this: parallelize the per-enemy loop with `WorkerThreadPool`, move
the hot loop to C# or a GDExtension, or step far-away enemies less often.

## Project layout

```
scenes/
  main.tscn            The game: ground, lights, camera, swarms, HUD
  player.tscn          The hero (CharacterBody3D) + aura/ring visuals
scripts/
  main.gd              Game loop, owns update order, level-up flow
  enemy_swarm.gd       A horde of one enemy type (use one node per type)
  projectile_swarm.gd  Bolts, pierce, hit memory
  gem_swarm.gd         XP gems and magnet pickup
  spatial_hash.gd      Grid hash: radius queries + density push
  multimesh_util.gd    MultiMesh setup / buffer helpers
  player.gd            Movement, Magic Bolt, Frost Aura, XP and levels
  player_stats.gd      All upgradeable numbers, as plain data
  upgrades.gd          The level-up pool (data + apply())
  wave_director.gd     Spawn rate / enemy HP / enemy mix over time
  hud.gd               HUD, level-up menu, game over (built in code)
  camera_rig.gd        Smooth follow camera
shaders/ground_grid.gdshader   World-space grid so movement is visible
tools/
  smoke_test.gd        Headless bot playthrough (exit code 0 = ok)
  bench_swarm.gd       Simulation-cost benchmark
```

## Tuning

- **Difficulty curve:** `WaveDirector` exports on the `WaveDirector` node
  (`base_rate`, `rate_growth`, `hp_growth_seconds`, brute timing).
- **Enemy stats and look:** exports on the `Grunts` / `Brutes` nodes in `main.tscn`
  (HP, speed, contact damage, size, color, capacity).
- **Crowd feel:** `separation_strength` and `crowd_limit` on each swarm. Higher
  strength spreads the horde out more; a lower `crowd_limit` means thinner crowds.
- **Player and weapons:** starting values in `player_stats.gd`.
- **Camera:** angle, distance and FOV are on the `Camera3D` child of `CameraRig`.

## Extending it

- **New upgrade:** add an entry to `Upgrades.DEFS` and a case in `Upgrades.apply()`.
- **New enemy type:** duplicate the `Brutes` node in `main.tscn`, change its
  exports, then register it in `main.gd` (`_swarms`) and `wave_director.gd`
  (that's where the spawn mix is decided).
- **New weapon:** add the state to `PlayerStats`, an `_update_*` method in
  `player.gd` (see `_update_aura` for the query-based pattern or `_update_bolt`
  for the projectile pattern), and upgrades to unlock and improve it.
- **Hit flash / per-enemy color:** turn on `use_colors` in the MultiMesh and write
  a color per instance into the buffer. That makes each instance's slice of the
  buffer longer than the 12 transform floats, so update the layout constants in
  `MultiMeshUtil` and the offsets in the swarms to match.

## Dev tools

```sh
# Headless bot playthrough; 1 minute of game time takes about a second.
godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd
godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 600   # 10 minutes

# Simulation cost for 1k..16k enemies (or pass a count after --)
godot --headless --path . -s tools/bench_swarm.gd
```

After adding scripts, open the project in the editor once (or run
`godot --headless --path . --import`) so Godot generates their `.uid` files,
and commit those too.

## Ideas for the ARPG layer

Items with random affixes feeding `PlayerStats`, a skill tree replacing the
random upgrade pool, multiple weapons/skills with their own cooldowns, enemy
types with ranged attacks, elites and bosses, biomes with obstacles
(`CharacterBody3D` is already in place for the player), and saves.
