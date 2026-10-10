# Soulbound — Aegis Battlemage

An original detailed, faceted battlemage character for Soulbound. Authored in Blender, not an image-generation mockup.

## Design

The established Battlemage's blue robe, gold trim, burgundy cape, cyan eyes and staff are retained. New construction includes a genuinely open hood, segmented half-mask, layered cuirass and pauldrons, split embroidered skirt panels, articulated greaves and fingers, a spell-focus gauntlet, a clasped grimoire with page edges and bookmarks, potion harnesses and an astrolabe staff.

Geometry is deliberately faceted. The materials use vertex colors; there are no external textures or texture dependencies. Small details use real meshes. The character is intended as a hero or named character, not a mass-swarm replacement.

## Files

- `Soulbound_Aegis_Battlemage.blend`: editable parts, preview lighting/camera, and hidden game-export collection with an 18-bone rigid-weight rig.
- `glb/battlemage_body.glb`: joined static body, world-grounded origin. Three material surfaces.
- `glb/astrolabe_staff.glb`: separate equipable staff, origin at the hand grip. Three material surfaces.
- `glb/battlemage_rigged.glb`: assembled character and staff on one skeleton. Includes two demonstration animation clips: `idle` (2 seconds) and `cast` (1 second).
- `previews/`: actual model renders from multiple views. These are studio views, not screenshots from an installed game.
- `source/`: reproducible Blender scripts.
- `validation/`: import test, statistics and coordinate/rig contract.

The complete exported character is 7,942 triangles (6,436 body + 1,506 staff), with 291 editable source parts.

The static body is suitable for Soulbound's current whole-model procedural movement. The rigged alternative is available for a more articulated integration. The two clips are a starting point, not a complete locomotion/combat animation set. The cast is a non-root-motion pose; no hitbox, projectile or gameplay timing is attached.

## Scale and orientation

- Metres; body approximately 2.36 m high, assembled staff reaches 2.55 m.
- Blender Z-up, +Y forward. GLB/Godot Y-up, -Z forward.
- Grounded root, identity object scales in exports.
- Staff grip in body-local Godot coordinates: `(0.642, 1.20, -0.379)`.
- UV0.x is 0 for ordinary surfaces and 0.72 for arcane surfaces, consistent with the preceding Soulbound creature asset convention.
- Linear vertex COLOR_0, faceted normals, separate cloth/metal/emissive PBR materials.

## Integration handoff

Compatibility was checked against `MarkJRogers92/ARPG` commit `70fc01899c8079661ab782705c0a8b7f29e70c4e`, including `scripts/visual/hero_model.gd`, `scripts/visual/models.gd`, `scripts/hero_class.gd` and `scenes/player.tscn`.

This package does not change the repository, installed game or existing saves. It is not an automatic file-swap replacement: the current hero is a procedurally constructed `ArrayMesh`.

Recommended integration:

1. Keep the original hero as a selectable/fallback appearance. Add this as an optional Battlemage body.
2. For the static path, load the body GLB under the existing visual rig. Preserve `set_motion`, `cast`, `set_weapon`, class stat application, collision and gameplay authority.
3. The existing `Models.HERO_HAND` is `(0.44, 1.12, -0.45)`. Use this model's authored grip position for its weapon pivot. Do not move the gameplay/projectile origin without a deliberate test.
4. For this supplied staff, apply identity local placement at that pivot. Do not also apply the old staff's `+0.15` Y offset: its local origin convention differs.
5. For the rigged path, attach replacement weapons through `hand.R` using the bind-space socket information. Keep the supplied staff hidden when another equipped weapon is shown. The named socket empties in the Blender master record bind-space positions; they are not automatic Godot `BoneAttachment3D` nodes.
6. Review camera framing before reusing the old visual rig's `1.12` scale. The exported body is already authored at the stated size.
7. Retain the GLB vertex-color materials or intentionally adapt them to Soulbound's shader. A blanket material override can remove cloth/metal distinction or emission.
8. Test weapon changes, all hero classes, ground contact, damage flash, respawn and busy-wave performance before enabling by default. This model was not installed or benchmarked in a full Soulbound run.

No collision shapes or physics bodies are included. Decorative staff/cape bounds must not expand the player's existing capsule.

## Editing and rebuilding

Open the `.blend` and edit collection `01_EDITABLE_CHARACTER`. Collection `02_GAME_EXPORTS` is hidden to prevent double-rendering the model. The studio is isolated in `03_PREVIEW_ONLY` and omitted from exports. For animation editing, unhide the rig and its two weighted meshes and hide the editable source collection.

The skeleton uses rigid weights per armor/cloth segment, suitable for the faceted construction. It does not include soft cloth simulation, finger bones or a standardized humanoid retargeting preset.

With Blender 4.3.2 or later:

    blender -b -t 4 --python source/build_battlemage.py
    blender -b -t 4 --python source/export_battlemage.py

Rebuilding overwrites the master and renders; save manual edits to another file first. The source script contains the editable palette. No paid services or external assets are needed.

Validate imports with Godot 4.6.3:

    godot --headless --path validation --script check.gd

Use writable XDG data/cache locations when running inside a restricted container.

## Provenance

Original model and mesh construction authored for Mark's Soulbound request on October 10, 2026. Palette/scale conventions were compared with the existing project and the earlier approved creature pack. No downloaded third-party model, stock texture or paid generation was used.
