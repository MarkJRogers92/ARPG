# Soulbound: animated creature bestiary I

Review integration, 2026-10-10. Base: `7029bf935c4fb537d5bf21bc5b58dd41bc91a595`.
Branch: `visual/creature-bestiary-animated`. Authored and tested on the assistant's
cloud computer. No installed-app update or publication is implied.

## Appearances and existing behaviors

| Realm | New appearance | Existing behavior |
|---|---|---|
| Hollow Graveyard | Coffin Crawler | grunt/contact |
| Hollow Graveyard | Gallows Raven | runner/contact |
| Frozen Wastes | Rime Widow | runner/contact |
| Frozen Wastes | Antler Revenant | lancer/telegraphed charge |
| Ember Rift | Slag Scorpion | runner/contact |
| Ember Rift | Furnace Tortoise | brute/contact |

These are cosmetic alternatives, not six new AI classes. Statistics, collision,
spawn tables, targeting, hit timing, charge telegraphs, status effects and RNG
consumption remain those of the existing roles. Contact-attack animation is a
visual loop, not frame-authoritative damage. Original appearances remain.

## Animation and runtime contract

- The companion source pack contains an editable Blender master and six skinned
  GLBs, each with `idle`, `walk`, `attack`, `hit`, and `death` clips (30 total).
- The game uses separate rigid-joint GLBs and a shared MultiMesh vertex shader,
  not a Skeleton3D/AnimationPlayer per enemy. Joint indices are in UV2.x; UV0.x
  retains the original glow-mask contract. Vertex colors are linear.
- Runtime locomotion blends idle/walk; charge states drive anticipation,
  attack and recovery; existing hit flash drives recoil. The GPU animation is
  a procedural counterpart to the portable clips, not GLB timeline playback.
- Dead actors leave the simulation immediately. A separate bounded pool of 24
  visual remnants per swarm folds/shrinks them for 0.55 seconds without physics,
  targeting, XP, loot or contact damage. Despawn clears remnants without death.
- Native authored scale, feet at ground root, Y-up and -Z forward. The raven
  hovers. No global height normalization or per-enemy animation nodes.

## Crowded-scene protection

Eligible spawns alternate old/new until **16 living new creatures per swarm**
are admitted. Additional enemies retain their original appearance. A living
model never swaps because population changes; a future eligible spawn may
reuse a slot after death. This visual-only budget does not limit enemy count.
The initial uncapped 50/50 implementation was rejected by the software-renderer
stress comparison. See `validation.md` for measured capped results and limits.

`CreatureModels.enabled = false` before realm construction restores the original
appearance path. Missing or invalid creature art also falls back. Existing
specialist models and other roles remain available.

## Reproduce

Godot 4.6.3 Compatibility was used. Run from repository root:

```sh
bash tools/run_tests.sh
# Automated seven-minute simulation, one realm per invocation:
godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420 frozen
# Linux cloud visual harnesses (Xorg dummy driver, xauth, software Mesa):
bash tools/run_creature_visual_qa.sh
bash tools/run_creature_gallery.sh
bash tools/run_creature_bench.sh
```

The visual harnesses use isolated `.runtime/` configuration. Their outputs go to
`build/`; neither directory belongs in a commit. The gallery is a controlled
close-up animation review, not gameplay footage. Gameplay QA uses the real Main,
camera, lighting and input actions with invulnerability/durable targets.

## Release gate and rollback

Cloud software rendering is not a Mac GPU benchmark. Before release, compare the
same late-run seed on the target Mac, including death bursts and allies. Ember now uses stronger neutral ash-sky fill, a warmer readable key light and
lighter basalt/ash ground values across all three night stages. Lava and
existing boss tint remain. See the dated lighting follow-up in validation.md.

To remove this integration, revert its review commit. To preview the original
look without removing files, disable CreatureModels before creating the realm.
No save schema, project settings or installed player profiles are changed.
