# Soulbound authored character integration

The six approved specialist enemies and the subsequently approved Ferryman/Collector pair are integrated into the actual Soulbound runtime. The specialist and Collector populations retain both authored and original procedural appearances. Other enemy roles, environments, player art and combat values are unchanged. This is local work only: no push, merge, release or deployment.

## Repository and source

Isolated branch: `codex/specialist-enemy-variants`.
Worktree: `/Users/markrogers/Documents/Codex/2026-10-07/task-2/soulbound-enemy-variants`.
Final upstream base: `5983ee15200ad84d73601196c420876bb7999462` (PR 22), fetched and inspected after the initial audited base `1ff408a0dd521bf99eb7ced494f32279f0b679ec` (PR 20). Local changes were backed up and rebased cleanly onto the newer upstream. The original `/Users/markrogers/ARPG` checkout still has its preexisting `project.godot` edit; no original work was reset. DEAD MALL and Jev work were not touched.

Source provenance and verified ZIP/GLB checksums are in `assets/enemies/specialists/README.md` and `assets/enemies/signatures/README.md`. All 119 specialist-pack and 81 signature-pack manifest entries passed verification. Editable Blender source remains available in the two original packs.

Catalog content is preserved with LF line endings. Their import sidecars use Godot's [Keep File mode](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html) so the CSV catalogs do not become translation resources; a final preview import verified this metadata change.

| Realm | Existing role | Authored appearance | Triangles |
|---|---|---|---:|
| Graveyard | shieldbearer | Bone Shieldbearer | 904 |
| Graveyard | mender | Grave Mender | 790 |
| Frozen | mender | Hoarfrost Shaman | 652 |
| Frozen | bloater | Frost Bloater | 648 |
| Ember | shieldbearer | Obsidian Guard | 608 |
| Ember | bloater | Magma Bloater | 610 |
| All three | collector | Debt Collector | 2,494 |
| All three | Ferryman encounter | Ferryman | 2,159 |

## Runtime behavior

`SpecialistModels` extracts and caches static mesh geometry once. It bakes node transforms and body scaling, preserves both surfaces, vertex colors and UV emission tags, and gives each caller an independent mesh. Existing shaders handle effects on both surfaces; imported material emission and realm tint are not applied a second time. Invalid or absent assets use the procedural fallback. Swarms retain flat simulation arrays and shared MultiMeshes, with one extra body batch per affected role rather than a scene node per enemy. A separate cosmetic counter alternates appearances without consuming gameplay RNG, and assignments survive swap-removal/recycling.

The six specialists match the existing body parameters: 1.6 m for shields/healers and 1.3 m for bloaters. Staff-inclusive bounds do not enlarge collision or stats. Signature characters retain their approved native proportions, while Collector combat size remains the original 2.2 m parameter and 0.6 m radius. Collector capacity remains two.

For moving authored enemies, the foot lift/stride and a small forward lean follow actual resolved travel. Stopped healers stop stepping; chill reduces movement pose intensity. Shield/staff accessories stay outside the foot mask. The Collector has a narrower mask to preserve his low chain. This is the game's shader deformation, not a new skeletal animation system. Hit, elite, burn, spectral, block, heal and fuse cues remain in the existing runtime. Recycled rows also clear their previous burn flag.

Only the two new Ember specialists receive a modest cool rim to separate their dark silhouettes from lava. Their authored colors and emission masks remain intact. The realm's existing low contrast still limits both old and new dark bodies; global lighting and other models were not changed. The Collector's ledger/chain and Ferryman's face/lantern remain visible in the actual Ember encounter. The Ferryman retains his original encounter light, decal, facing, wager UI and loans. `authored_model = false` selects his original appearance.

## Validation

Godot 4.7.2, Apple M2, OpenGL Compatibility. All tests ran against isolated preview copies with their own save directory.

| Check | Result | Evidence |
|---|---|---|
| Targeted adapter/batching/movement/signature tests | 699 checks, zero failures | `chain-green.log` |
| Complete existing unit suite after all eight integrations | 58,588 checks passed, exit 0 | `signatures/final-unit.log` |
| Inventory UI, skill UI, resume | All passed | `latest-inventory.log`, `latest-skills.log`, `latest-resume.log` |
| 60-second smoke run | Passed; alive, 131 kills, one upgrade | `latest-smoke.log` |
| Fresh preview import plus subsequent two signature imports | Exit 0; runtime loaded all eight assets | `latest-fresh-import.log`, `signatures-import.log` |
| Final catalog metadata import | Exit 0 | `catalog-final-import.log` |
| Repaired signature QA harness parse | Exit 0 | `signature-qa-final-parse.log` |
| Independent code/geometry review | Chain finding fixed and rechecked; no remaining reported findings | `independent-review.md` |

Regression coverage includes exact realm mappings, untouched roles, native colors/UVs/topology, both material surfaces, body scale, invalid fallback, bounded node counts, all 20 render floats, capacity, RNG state, survivor identities, recycling, burn reset, stopped/chilled travel, forward direction and the Collector chain mask. Ferryman material/fallback/orientation/light and actual scene Collector capacity/stats are asserted.

The unit suite deliberately reads a corrupt save and logs the expected `get_var` diagnostic. Some UI/smoke test shutdowns report existing leaked-object/resource warnings. Sandboxed import passes could not save global editor settings; these messages did not prevent imports or gameplay. Logs are included rather than described as warning-free.

## Actual game evidence

Full-game captures use `scenes/main.tscn`, its existing 55-degree camera and 32-degree FOV, original environment/HUD and role effects. They are controlled QA encounters: invulnerable hero, seeded positions, durable target HP, and accelerated loan wait. They exercise real movement, attacks, heal/block/fuse/blast, statuses, Ferryman table/loan arrival and Collector seizure/death return. These controls are confined to QA scripts. The supplied standalone asset fixture was also inspected, but is not the basis for claiming game integration.

The `final/` specialist captures show old and new variants together in all three realms. Graveyard/Frozen capture sets include the travel pose correction; Ember combat captures establish the rim correction, while the later current-base horde capture includes the final gait and all eight integrations. Earlier six-model captures were taken before the upstream rebase; the signature/current horde captures use the final upstream base above. The `signatures/` captures show procedural/authored Ferryman and Collector encounters, the wager UI, Collector movement and matching hordes.

Encounter metrics on procedural Graveyard, authored Graveyard and authored Ember record the same loan (90 seconds), Collector delay (45 seconds), and army counts **1 → 0 on seizure → 1 after Collector death**. Moving Collector fronts track the hero (dot product 0.985 authored Graveyard, 0.996 authored Ember; rotation is refreshed every fourth frame). Targeted specialist probes report forward agreement above 0.999. A healer already within its hold range intentionally stays stationary.

The first signature harness accessed an incorrect private name for the army's away list. This skipped the two later screenshot labels; the minion-count checks immediately before those accesses, the mechanics themselves and the remaining captures completed. The harness now uses the actual public `away` field and passes a fresh parse check. The missing seize/return stills have not been recaptured; numeric checks and the complete passing unit suite support those mechanics. A prohibited main-window hide call in that harness was also removed. These were QA diagnostic errors, not production changes.

## Matched performance

Current-base Ember measurement, no movie recording: 120 warmup frames and 180 measured frames each, identical seeded populations, 1,108 enemies at start and 1,110 at end for both runs. The controlled horde has 1,000 grunts, 60 shields, six healers, 40 bloaters and two Collectors; durable HP and disabled fuse proximity stabilize the comparison. Both runs include normal player movement, attacks and the actual environment. Rendered PNG/backbuffer dimensions are **2940 × 1846**; the requested logical 1280 × 720 window did not change the Mac backbuffer.

| Appearance | Mean frame time | Median | 95th percentile | Approx. mean FPS |
|---|---:|---:|---:|---:|
| Procedural | 20.805 ms | 20.897 ms | 22.428 ms | 48.1 |
| Mixed authored/procedural | 20.661 ms | 20.900 ms | 21.846 ms | 48.4 |

The difference is measurement noise, not evidence of an optimization. This single short hardware comparison found no measurable horde slowdown from the variants; it does not establish sustained 60 FPS or every late-game workload. An earlier movie capture rendered much slower than real time due to recording overhead; it is excluded from the performance comparison and is not delivered as a clip of the final motion. PNG captures can also briefly disturb the on-screen FPS counter; timed benchmark samples exclude capture frames.

## Safe play and files

Run `tools/preview_specialists.sh` from this worktree. It copies the runtime into an ignored `build/specialist-preview.*` folder, imports it, and starts Godot. Saves use `Soulbound_Specialist_Variants_Preview`, separate from the installed Soulbound app and its ARPG save. The launcher refuses to run if the expected original save setting is missing or ambiguous. `--prepare-only` creates the copy without launching.

Production changes are confined to `scenes/main.tscn` (Collector appearance setting), `scripts/enemy_swarm.gd`, `scripts/ferryman.gd`, `scripts/realm.gd`, `shaders/enemy.gdshader`, the new `scripts/visual/specialist_models.gd` adapter, and `assets/enemies/{specialists,signatures}/`. Tests/QA/launcher live in `tools/`; provenance, this report and the plan live in `docs/` and the asset folders. The delivery manifest lists the exact local commit and every changed path. The evidence ZIP contains that commit as a binary Git patch, this report, selected full-game stills, raw metrics and logs.

Remaining limits: no uninterrupted full-night manual playthrough, no final motion video, and performance measured only on this Mac. Ember's existing dark-on-lava presentation remains a broader art limitation. No release was created or installed.
