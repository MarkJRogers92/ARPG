# Generated equipment prototypes

These are opt-in art-integration prototypes, not newly balanced loot types.
They are not in the default drop pool or starting loadouts.

| Asset | Source triangles | Runtime length | Attachment origin |
|---|---:|---:|---|
| Rune Greatsword | 4,951 | approximately 1.52 m | Grip midpoint; blade +Y |
| Amber Amulet | 5,278 | approximately 0.35 m | Top-ring center; body hangs down |

## Provenance and rights

Images were generated with Higgsfield Soul 2.0, converted by Meshy T2.5
Image-to-3D / Smart Topology, then prepared in Blender on 2026-10-18.
The Blender pass moved/oriented attachment origins; it did not resize the
masters or replace texture bytes. Each GLB has one material, one UV set, and
2048×2048 base-color, metallic/roughness, and normal maps embedded in it.
Checksums and explicit release-review flags are in `asset_manifest.json`.

No license, exclusive ownership, public-domain status, or commercial clearance
is asserted here. Confirm the applicable provider/account terms and source-image
rights before production distribution. The amulet exceeds its requested 5,000
triangle target by 278 triangles (5.56%). Both models are static and unrigged;
watertightness/manifold geometry is not certified. The amber is opaque PBR,
not physically transmissive glass.

The Godot sidecars use embedded Basis Universal textures to avoid a second
copy of every JPEG in the repository. The GLB originals remain byte-identical.
See [Godot's GLTFState image handling reference](https://docs.godotengine.org/en/4.6/classes/class_gltfstate.html).

## Integration

`ImportedEquipment` caches one textured ArrayMesh per base name. `Models.item`
selects it for the correct slot, so the same asset works in inventory icons,
selected-item previews, ground loot, and held-weapon visuals. Uniform runtime
scales are baked into copies of the vertices; UVs, normals, tangents, materials,
and source files are retained. Rarity is still displayed by the existing UI
and loot glow; the authored PBR material is not recolored.

The sword grip attaches to all current hero hand mounts. It follows the existing
one-handed cast pose and does **not** add melee damage, collision, or a two-handed
swing. The accessory occupies the ordinary amulet inventory slot; the current
game does not display worn amulets on the character's chest.

## Bronze lantern preview prop

The opt-in equipment preview also places a 4,482-triangle bronze lantern beside
the player. This is a static decorative prop, not a new equippable item.
Blender preparation removed malformed custom split normals that produced black
triangles on the rear surface, retaining the normal map and original texture
bytes. The prepared origin is at the bottom center. The source master is
preserved in the cloud asset archive; this GLB is the corrected derivative.

The material remains opaque and non-emissive. No light source, collision,
interaction, or animation is asserted. Commercial release rights and visual
fit in the running game still require review. The preview regression verifies
the prop is present, and Godot imports its embedded textures without extracting
duplicate JPEGs into the repository.
