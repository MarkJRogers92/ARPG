# Approved specialist cosmetic variants

Six source GLBs from `Soulbound_Specialist_Enemies_Editable_Pack.zip` are used by the existing EnemySwarm renderer. The original procedural models remain alternate appearances. Other enemy roles and realm combinations retain their original models.

Source Library: `libfile_330075bc435c81919ac761af46db42dd`.
Source ZIP: 849,560 bytes; SHA-256 `b347caf0e6734eb6970ceb8629caa51f36d59eb45368704bbf4ea9e5949f2860`.
All 119 manifest checksums in the editable pack were verified. The six GLBs here are byte-identical to that pack. Editable Blender parts/builders remain in the original Library pack, rather than adding unrelated source assets to this repository.

| Realm | Existing role | Added appearance | Triangles |
|---|---|---|---:|
| Graveyard | shieldbearer | Bone Shieldbearer | 904 |
| Graveyard | mender | Grave Mender | 790 |
| Frozen | mender | Hoarfrost Shaman | 652 |
| Frozen | bloater | Frost Bloater | 648 |
| Ember | shieldbearer | Obsidian Guard | 608 |
| Ember | bloater | Magma Bloater | 610 |

Each file is one static mesh with two surfaces, opaque linear COLOR_0 and UV0.x emission tags (0 or 0.72), ground origin, Y up and -Z forward. `SpecialistModels` caches extraction, preserves every surface/attribute, and scales by authored **body** height (1.8 m for shields/healers; 1.35 m for bloaters). Staff-inclusive 2.3 m bounds do not change collision or combat size. Imported materials are replaced with the existing enemy shader, avoiding double emission or realm tint.

The catalog/manifest describe the delivered source pack, including its original "unintegrated" status. Runtime integration and validation are documented in `docs/specialist-variants.md`.
