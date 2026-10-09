# Camp visual polish preview

Local branch `preview/camp-visual-polish`, based on merged PR #34 (`1c44652`).

## Scope

Improve the camping stops introduced by the onward journey: Gravediggers’ Camp, Whitepass Refuge, Sledwright’s Rest, and Redwake Caravan. Retain their biome identities, all seven traveling services, and the existing journey/save rules. Use the existing native low-poly mesh and prop system.

Canvas shelters, cooking sites, sleeping gear, supplies, and ground treatment should be visible from the playable camera. The lighting must refresh when moving from Last Lantern to a camp within the same biome, and reset correctly on returning to the starter town.

## Preview isolation

`Play Polished Camps Preview.command` launches the local worktree using the separate `Soulbound_CampPolishPreview_20261008` profile. The original player files were copied once; later preview progress is isolated. The local `override.cfg` is deliberately untracked. Checking out the branch elsewhere does not isolate saves by itself.

## Acceptance evidence

Godot 4.7.2: all-destination visual/movement/service checks passed (582 PASS assertions), walk-town passed (43), and backdrop fixture passed. Final logs are `work/camp-polish-evidence/{visual,walk,backdrop}-final.log`. These runs reported no errors or warnings. The visual harness exercises directional movement and E interaction at all seven services in all thirteen destinations, checks camp blockers/shelters, and verifies same-biome Lantern → camp → Lantern lighting.

Parent inspected four final native 1280×720 renders: Gravediggers’ Camp, Whitepass Refuge, Sledwright’s Rest, and Redwake Caravan. The images are actual fixture renders, not a full human campaign playthrough. No balance or long-session performance claim is made. Earlier campaign shutdown warnings were not investigated as part of this visual change.

Native Luna implemented; independent native Sol reviewed the actual three-file source/test diff and accepted it. Parent verified the final logs and images. Jev routing was unavailable, so the ordinary native assignment was retained.

All six original save/backup file states and the original checkout’s project settings match the starting fingerprints. Generated Godot import sidecars were restored; the preview override remains untracked. No controller, save format, economy, or balance changes. Local review branch only; not pushed, merged, or installed over the released app.
