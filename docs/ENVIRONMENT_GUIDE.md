# Building environments in Soulbound

A recipe for any agent (Astra, Luna, Sol, Claude) adding a walkable or
decorative 3D space. Worked example: `scripts/campaign/campaign_walk_town.gd`.

## 1. Everything is code; no asset pipeline needed

- **MeshKit** (`scripts/visual/mesh_kit.gd`) builds one low-poly mesh from
  primitives, each with its own color and glow:
  `box(size, xf, color, glow)`, `sphere(r, xf, color, glow, seg, rings)`,
  `cylinder(top, bottom, h, xf, color, glow, seg)`, `capsule`, `torus`.
  Place parts with `MeshKit.at(position, rotation_degrees, scale)`.
  Finish with `kit.commit(Models.material("kit"))`. Set `kit.flat = true` for
  the faceted look.
- **AssetProps** (`scripts/visual/asset_props.gd`): ~40 imported props by kind,
  such as `forge`, `mausoleum`, `lantern_post`, `soul_brazier`, `weapon_rack`,
  `sarcophagus`, `ruined_wall` or `guardian_statue`. Use
  `AssetProps.mesh(kind)` and, outside combat, override surfaces with
  `AssetProps.opaque_material()` / `emissive_material()` (see `_prop()` in the
  walk town). Combat materials use a hero-occlusion shader you don't want here.
- **Models.prop(kind)**: scenery that combat decor uses (`grass`, `bush`,
  `tree`, `grave`, `rock`, `pine`, `ice`, `ashtree`, `obsidian`...).
  **Models.hero_body(look)**, **HeroModel**, **Models.ferryman()** give people.

## 2. Think in walking scale

The hero is about 2.2 units tall (HeroModel rig scale 1.12). Doors ~1.5,
cottage walls 2.3–3, a street ~4 wide, a plaza radius ~13. Existing art made
for a small framed vignette (like `CampaignBackdrop`) can be reused by
parenting it under a scaled `Node3D` (the walk town scales the Lantern ×1.6
and apse ×1.9).

## 3. Composition checklist

1. Ground layers: earth plane → stone/cobbles → inlays. Build cobbles from
   many small boxes with slight random size, rotation and shade (plus ~12% moss).
2. A focal landmark in the middle, a backdrop wall on one side, streets out.
3. Buildings face the square: compute yaw with `atan2(pos.x, pos.z)` so -Z
   (the model's front) points to the center.
4. Silhouette ring at the edge (graves, pillars, statues); biome scatter beyond.
5. Life: drifting motes, mist sheets, idle bob on NPCs, wisps.
6. Collision: circle blockers `[center, radius]` plus a radius clamp.

## 4. Light on a budget (important)

The project renders with **gl_compatibility**:
- each mesh receives at most **8** lights, and the scene renders at most
  **32** by default. Split big floors into chunks (the walk town uses 6 m grid
  chunks) so each chunk gets the lights near it.
- Make glow with emissive geometry (`glow` argument ≥ 1.5) and environment
  glow/bloom, not with more `OmniLight3D`s. Keep real lights around 20–24.
- No volumetric fog in this renderer; use depth fog plus additive
  radial-gradient mist planes.

## 5. GDScript traps that have broken builds

- `var x := expr` fails to compile if `expr` comes from an **untyped** loop
  variable or a Dictionary/Array lookup. Type loop variables
  (`for edge: float in [-1.0, 1.0]`) or declare `var x: Vector2 = ...`.
- The CI test suite runs headless and never loads campaign UI, so CI passing
  does **not** prove a town script compiles.

## 6. Verify before shipping (works without a display)

```
godot --headless --path . --import
godot --headless --path . --check-only --script res://scripts/campaign/campaign_walk_town.gd
```
Then a smoke test: a temporary `tools/zz_smoke.gd` that `extends SceneTree`,
adds the node to `root` in `_initialize()`, and in `_process()` waits a couple
of frames before calling methods (nodes are not ready during `_initialize`),
prints counts and returns `true` to quit. Delete the file afterwards and
restore any `*.glb.import` files the import rewrote (`git checkout -- assets/`).
Screenshots from a real desktop run remain the only proof of looks.
