# Approved signature characters

Source: `Soulbound_Signature_Characters.zip` from Mark's Downloads and Library `libfile_689dfa6c190c81918bd6faf2dbf5287c`.
ZIP: 4,190,892 bytes; SHA-256 `b37b4ed26fc0f45447792f48a1427cc5b2e04d86fcaa2837c370af312d75b8ce`.
All 81 source manifest checksums were verified. These two GLBs are byte-identical to the delivered pack; editable Blender parts and builders remain in that pack.

| Asset | Triangles | Native height | GLB SHA-256 |
|---|---:|---:|---|
| Ferryman | 2,159 | 2.860 m, including oar/raft | `8cb215e5f08f82e5a78e2234cbdb76d21cfa3317413306b90009fe8f58ba8465` |
| Debt Collector | 2,494 | 2.655 m, including hat | `7aecb10d566f694fe380c66db514dcef785c68419f793b665351bff1949901fc` |

Both assets have one static mesh, two opaque surfaces, linear vertex colors, UV0.x emission tags, feet at Y=0 and -Z facing. The shared adapter preserves the native proportions and both surfaces. The Ferryman receives the existing kit shader; the Collector receives the existing enemy shader. Imported materials are discarded so glow is applied once.

The Ferryman retains his encounter light, decal, orientation, wagers and loan mechanics. `authored_model = false` selects his original procedural appearance; missing assets also fall back. Collectors alternate authored and procedural appearances, beginning with the authored model, without using gameplay RNG. Their existing capacity, 2.2 m body parameter, radius, speed, damage and seizure mechanics are unchanged. A Collector-specific leg mask keeps his chain outside the foot deformation.

The catalog/manifest retain the source pack's original "unintegrated" status. Runtime validation is documented in `docs/specialist-variants.md`.
