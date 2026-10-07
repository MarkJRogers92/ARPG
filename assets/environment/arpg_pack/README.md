# Imported environment art (stage 1)

Static, vertex-colored GLBs from the *ARPG 56 Assets* handoff
(`ARPG_Claude_Implementation_Essentials.zip`, prepared 7 October 2026). Nine of
the 56 are imported so far, three per realm. The pack directories keep their
original names. The files are byte-for-byte copies; their SHA-256 hashes match
the handoff's `ASSET_CATALOG.json`. They were not rebuilt or re-exported.
Blender masters, builders and previews stay in the handoff archive, outside
the project.

| File | SHA-256 |
|---|---|
| 01_soul_ruins/Rune_Gravestone.glb | e0625b7f0a7b15837f5517db320be7113011c3bc3ac7238e6c32d8bc332cb3e3 |
| 01_soul_ruins/Soul_Lantern_Brazier.glb | fde45dead82d963e2dc191a268142914bd3b44dbf0ecba66624ce68ca4d139b7 |
| 03_three_realms/Brimstone_Vent.glb | d18d440dab1f5df60126ba16de56567ef8b83ce980711ad5a5af550d237b791a |
| 03_three_realms/Frosted_Pine.glb | d660643194db863e41068372b6037d218ad2a273d106bf593ea4eef9e0fa9dd6 |
| 03_three_realms/Glacial_Ice_Arch.glb | 21f0a3ea8cec2dc39eb6a7e66f42bb0c13ed775ca62cd79a28dfb4df187de9cc |
| 03_three_realms/Obsidian_Outcrop.glb | e684ab4f560e5aaad0d957b8d1e3adb242c8aa1322a6890ce777953732f5c1c0 |
| 03_three_realms/Snowbound_Boulder.glb | a60e6294682046f159b4145902d50559c1380f58be8b92ae8bc83b93914e077e |
| 04_landmarks/Demon_Skull_Gateway.glb | 034b787eb35270f64d9a42e2880bb6597aa16cf715e0feec005e5c2a719ae961 |
| 04_landmarks/Graveyard_Mausoleum.glb | 0a9b813504bdfe9bc9421d814679e72ec43f0574cec908026384fb91dc05a42f |

Pack caveats that matter here (from the pack READMEs):

- Everything is static decoration: no collision, navigation, animation,
  interaction, lights or audio.
- The mausoleum is a sealed exterior. The gateway is not an exit.
- The brazier is not a light. The vent is not a hazard.
- 1 unit = 1 m, Y-up, ground-level origin, identity transforms. Fronts face +Z,
  which is toward the game camera.

Unlike the pack READMEs say, opaque surfaces do **not** have UV.x = 0: 85–100%
of their vertices carry non-zero UV.x. So `AssetProps` (`scripts/visual/asset_props.gd`)
takes glow from each surface's imported material, never from UV.x.
