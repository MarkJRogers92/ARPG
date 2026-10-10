# Soulbound — Four Remaining Hero Classes

Original Blender characters completing the class roster alongside the separately delivered **Aegis Battlemage**. These are actual 3D assets, with editable meshes and glTF exports, not image-generation concepts.

## The four characters

### Sepulcher Necromancer
Deep green robes, bone-rib armor, antler crown, burial mask, hanging funerary charms and an ossuary cape seal. Carries a **Reliquary Orb** held in a bone-and-brass cage. Uses the existing Necromancer's green soul accent and orb weapon category.

### Cinder Pyromancer
Red robes, dark heat-shield armor, a copper flame crown, vented pauldrons, layered furnace scales, a charred cape hem and an alchemist's canister. Carries a **Furnace Wand** with a caged ember focus. Uses the existing Pyromancer's red/orange palette and wand category.

### Tempest Stormcaller
Violet cloth, pale silver armor, swept temple fins, wing-shaped shoulder plates, forked circlet and trailing cape streamers. A compass is mounted to the weather atlas at the belt. Carries a **Thunderfork Staff** around a suspended storm prism. Uses the existing Stormcaller's purple/white lightning palette and staff category.

### Veil Reaper
Charcoal shrouds, an ivory death mask, blade-shaped pauldrons, a hooked cowl and hourglass lantern. Carries the broad curved **Eclipse Scythe**, with a pale sharpened edge and restrained mint soul channel. Uses the existing Reaper's black/mint palette and scythe category.

## Cohesion

All four share the approved Battlemage's anatomical scale, hand locations, faceted mesh construction, vertex-color materials and 18-bone skeleton convention. Class identity comes from custom masks, head silhouettes, chest armor, shoulder construction, accessories and weapons. Repeated boots, robe construction, clasps and embroidery intentionally make them a coherent faction.

The new models preserve the class/weapon definitions inspected at ARPG commit `70fc01899c8079661ab782705c0a8b7f29e70c4e`. They do not add or alter gameplay abilities.

## Contents

Each class directory contains:

- `Soulbound_<class>.blend`: editable parts, preview studio and hidden export rig.
- `glb/<class>_body.glb`: joined static body, grounded root, three material surfaces.
- `glb/<class>_weapon.glb`: separate weapon, origin at the right-hand grip.
- `glb/<class>_rigged.glb`: assembled character and weapon on one 18-bone skeleton.
- `previews/hero.jpg`, `rear.jpg` and `action.jpg`: actual model renders.
- `validation/`: class construction and coordinate metadata.

The root `source/` directory contains the original reproducible Blender scripts and shared Battlemage construction utilities. The root `validation/` contains the Godot import/skin/animation checks and exported-mesh checks. `asset_manifest.json` records final per-class counts.

### Animation scope

Each rigged file includes an `idle` demonstration (2 seconds) and one 1-second action demonstration. Necromancer, Pyromancer and Stormcaller use `cast`; Reaper uses `reap`. These are starting poses/clips, not a complete locomotion or combat animation library. No root motion, physics, attack timing, projectile triggers or damage events are included.

Rigid weighting is deliberate for faceted armor and cloth segments. There is no cloth simulation, finger skeleton or automatic humanoid retargeting preset. Keep the static alternative if integrating into the current whole-body procedural animation system.

## Coordinates, materials and attachment contract

- Metres; feet remain at the grounded origin.
- Blender +Y forward / Z up becomes GLB -Z forward / Y up.
- Anatomical eye, shoulder, hand and foot heights match the approved Battlemage. Crowns and horns extend above that shared anatomy; do not normalize every full bounding box to identical height.
- Right-hand grip in model-local Godot coordinates: `(0.642, 1.20, -0.379)`.
- The separate weapon export has this grip rebased to its own origin. Attach it with identity local placement.
- Linear vertex colors; flat normals; cloth/leather, metal and emissive material surfaces. No external image textures.
- UV0.x = 0 for ordinary parts and 0.72 for arcane surfaces, following the preceding Soulbound asset convention.
- The staff-named bone in the common rig is the generic equipped-weapon bone for every class, including orb, wand and scythe.

## Integration handoff

The repository and installed game have not been changed by this asset-generation task. The existing `HeroModel` constructs its body procedurally; these GLBs are not automatic file-swap replacements.

1. Retain the original appearances as fallback/selectable options.
2. Load each static body under the current visual rig, or deliberately adapt the rigged path. Preserve `set_body`, `set_motion`, `cast`, `set_weapon`, class modifiers and player ownership.
3. Use the supplied grip position instead of the old `Models.HERO_HAND` `(0.44, 1.12, -0.45)` for these bodies. For the supplied weapons, do not additionally apply the old staff's +0.15 Y placement offset.
4. In the rigged path, use `hand.R` and the bind-space socket metadata for a `BoneAttachment3D`. The Blender socket empties are documentation helpers, not automatically configured Godot attachments.
5. Hide the included class weapon when equipping another item. Preserve weapon switching, inventory behavior and the Reaper's actual scythe gameplay logic.
6. Review the old visual rig's 1.12 scale at the gameplay camera rather than multiplying automatically. Do not let scythe/crown/cape bounds alter the existing player collision capsule or targeting radius.
7. Preserve vertex colors and the separate emissive surface when adapting to Soulbound shaders. A blanket material override can lose their intended appearance.
8. Test class selection, movement, casting/reaping, equipment switching, hit flash, respawn, lighting in all biomes and busy-wave performance before making them the default.

These are hero/named-character assets. Their costs have not been benchmarked in a full installed Soulbound run, and they should not be substituted across hundreds of swarm enemies without a separate budget review.

## Rebuild and validate

From this package root, with Blender 4.3.2 or later:

    blender -b -t 3 --python source/build_roster.py -- necromancer
    blender -b -t 3 --python source/export_roster.py -- necromancer
    blender -b -t 3 --python source/render_action.py -- necromancer

Repeat with `pyromancer`, `stormcaller` and `reaper`. Rebuilding overwrites generated files; preserve hand-edited masters separately first.

    blender -b -t 2 --python source/validate_roster.py
    godot --headless --path validation --script check.gd

The original `common_battlemage.py` and `export_template.py` are shared templates used by these entrypoints. Do not run those two template files directly as a roster build.

When editing a master, use `01_EDITABLE_CHARACTER`. `02_GAME_EXPORTS` contains hidden merged meshes and the rig, preventing duplicate rendering. Hide the editable source and unhide the rig and its two weighted meshes to preview the named actions. `03_PREVIEW_ONLY` is excluded from all GLBs.

## Validation limits and provenance

Godot 4.6.3 imports, vertex colors, normals, normalized skin weights, expected bones and changing animation poses are tested. Blender checks exported meshes for finite coordinates and zero-area triangles. Front, rear and action renders are reviewed. These are studio views, not gameplay screenshots.

Original assets authored for Mark's Soulbound request on October 10, 2026, extending the approved Aegis Battlemage construction. No third-party model, stock texture or paid image-generation service was used. The original Battlemage remains in its previously delivered pack; this package supplies the four remaining classes.
