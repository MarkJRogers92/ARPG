# Approved Soulbound scenery collection

24 static, texture-free, vertex-coloured GLBs: 12 Hollow Graveyard props,
6 Frozen Wastes props, and 6 Ember Rift props. These are byte-identical copies
of the approved October 9 assets. The graveyard files are the **corrected
revision 2** exports (outward arch side normals and supported mausoleum seal).

`ASSET_CATALOG.json` records each file's SHA-256, mesh bounds in Godot XYZ,
surfaces, triangle count, biome, and source revision. All exports contain one
mesh; opaque and emissive parts use separate surfaces, with explicit backface
culling. Metres, Y up, ground-centred origin, front +Z.

`AssetProps.KINDS` supplies footprint, scale, yaw, shadows, collision circles
and biome-coloured motes; `Realm.REALMS` controls the scatter densities.
`Models.PROPS` appends the kinds after the original collection. All use the
existing WorldDecor MultiMesh batching and kit shaders, including landmark
hero-occlusion windows.

- Gates, fence/barricade segments and larger solid set pieces block movement.
  The Rift archway has two pillar circles and a passable central opening.
- Small scenery remains walk-through. The ritual circle is non-blocking.
- No new loot, objective, damage, opening or animation mechanics. The new
  reliquary chest is not the cursed-chest event model.
- Fence segments are placed singly; no repeat-run end-post duplication.
- Source Blender masters, builders and review boards remain in the external
  approved art folders, not in the game repository. Lantern Warden is not
  included (still static/unrigged and not runtime-ready).

Acceptance checks: `bash tools/run_tests.sh -t tools/approved_collection_test.gd`.
Native review: `tools/asset_showcase.gd` collection modes documented in README.
