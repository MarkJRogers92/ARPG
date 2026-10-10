# Hero, soul army and combat readability

Visual follow-up to published `f86cd93`. The initial local-only verification
below is historical. On October 10, Mark approved the five imported hero models,
then explicitly authorized push, merge and production installation. The roster
supersedes the procedural Battlemage as the default; that rig remains a fallback.
See `HERO_ROSTER.md` for the final shared adapter and production boundaries.
Unrelated delivery notes and `docs/CODE_REVIEW_HANDOFF.md` remain untouched.

## Scope

- The **Battlemage** gets a segmented procedural rig: hood opening/eyes,
  shoulder trim, articulated arms and legs, and a three-segment trailing cape.
  Walking follows forward/backward and lateral travel, feet stay above ground,
  and the equipped weapon follows the animated hand. Existing weapon meshes and
  the resting hand mount are retained. Other classes keep their original bodies.
- Animation uses supplied deltas, not wall-clock idle animation. Changing class
  resets the pose and light colour; presenting the same palette again does not
  interrupt town walking. Existing death transforms still own the Visual root.
- One detailed allied role: Graveyard **coffin-crawler brawlers**, reusing the
  approved creature mesh and joint shader with an army-only attack envelope.
  No skeleton node per minion, new asset generation or new saved appearance.
  Disabled/missing optional meshes use the original procedural body. Detailed
  bodies remain bounded by the existing 40-minion army capacity.
- All allies get small hollow cyan ground diamonds (gold for veterans), in one
  additional capacity-bounded MultiMesh. Their spectral rim is less broad than
  the old blue glow. Existing names, stars and veteran rings are retained.
- The hero has an ivory ground locator and a small overhead triangle. Both
  respect depth; they do not draw the hero through solid scenery. The triangle
  smoothly lifts from 3.7 to 6 m as crowd count rises, clearing tall actors
  without enabling x-ray rendering, and settles back when the horde thins.
- Hostile shots use an opaque pointed bead with a dark edge and retained
  fire/frost/neutral tints. Hero bolts keep their existing translucent trails.
- Danger circles and charger/Colossus lines use steady, depth-tested ink with
  dark keylines. Countdown fill draws before outlines; Bold warnings still
  applies. Ordinary loot/landmark/mender glows remain unchanged. The established
  0.82 outline convention, caller sizes and all damage checks are unchanged;
  this is not a correction of older warning-radius approximations.

No balance, damage, movement speed, enemy admission limit, save format,
progression, realm lighting, release workflow or project-setting changes.

## Verification

All engine runs use **Godot 4.6.stable.official.89cea1439** in disposable copies
with different user-data folders. The installed Homebrew engine is 4.7.2 and
was not used. No engine was launched against the source project.

- New hero suite: **793 checks passed**, including all other class bodies,
  equipped weapon parity, dynamic grip, directional gait and frame-by-frame
  grounding/cape clearance, deterministic poses, same-palette presentation,
  material isolation, cast retrigger/settling and deferred node cleanup.
- New combat/readability suite: **79 checks passed**, including actual attack
  damage and exact combat/save/RNG equality with optional allied art enabled
  versus disabled, all imported surfaces, untouched enemy materials, existing
  army capacity, swap removal, reused rows, marker cleanup, shot flight/hits,
  warning transforms/diameters and live charge-line settings refresh.
  It also checks that the locator rises/settles without disabling depth tests.
- Existing runner: **7/7 focused** and **28/28 full headless suites passed**.
  Both new suites are registered. Runner success is not a claim that historical
  asynchronous audio-shutdown warnings are fixed.
- New script/shader UIDs are copied from the isolated engine's generated files;
  the worker's two provisional handwritten UIDs were replaced. Original UIDs
  and imports are unchanged, with no duplicate UID values.

- Three realm smokes **configured for up to 420 simulated seconds passed**:
  Graveyard (8,030 kills,
  37 upgrades, alive), Frozen (7,517 kills, 38 upgrades, alive), Ember (9,858
  kills, 32 upgrades, bot died and ended early). Bot survival is not a balance
  acceptance test.
  Each retained shutdown ObjectDB/resource warnings (20/20/21 resources),
  with no script, parse or shader-compilation errors. These warnings are not
  fixed by this visual package.
- Native **Apple M2 / OpenGL Compatibility** crowd captures passed in all three
  realms: 776–829 active enemies and 40 allies, an alive fixture
  hero, active shots and danger circles, at 1280×720. Sol reviewed original
  captures plus a 2× nearest-neighbour elemental-shot crop. Hero/ally silhouette,
  cape direction, weapon grip, depth-tested locator and steady warning contrast
  were checked. A quiet gallery and hostile-shot palette on snow were also
  checked. Ground ink/diamonds remain subject to body and scenery occlusion;
  readability is improved, not guaranteed for every overlapping effect.

### Native crowd-cost comparison

Alternating before/after runs, two repeats per realm, 600 frames each with the
first 120 discarded: **960 measured intervals per variant/realm**, no screenshot
readbacks, vsync disabled and fixed 1/60 s simulation. Actor-count ranges, shots
and warnings matched in paired runs. Only Graveyard uses detailed brawlers;
all realms include the new hero and readability materials.

| Realm | Median before → after (ms) | P95 before → after (ms) | Enemy range |
| --- | --- | --- | --- |
| Graveyard | 14.316 → 14.195 | 25.925 → 25.196 | 784–830 |
| Frozen | 13.761 → 13.697 | 25.791 → 24.517 | 776–816 |
| Ember | 13.493 → 13.317 | 26.086 → 25.069 | 776–816 |

No material regression was observed in these fixtures, including 40 detailed
Graveyard allies. Small differences do **not** establish a speedup. Submission
intervals include CPU/render work; device clocks and desktop load were not
locked. This is not isolated GPU timing, software-renderer evidence, a general
60 FPS guarantee or a substitute for a human campaign playtest.

### Preservation

Final hash checks confirmed **367 profile files**, the installed Soulbound pack,
source project settings, every original UID/import sidecar and all three
pre-existing dirty documentation files unchanged. All **344 runtime/test/UID
files** in the source match both verification copies. No commit, install, push,
merge or publication was performed.

## Tools and evidence

`tools/combat_readability_qa.gd` accepts realm, output directory and stage
(`gallery`, `crowd`, `bench`, `threats`). It uses actual Main, lighting, camera,
input, army and shots. The hero/enemies/allies are durable fixtures. SFX calls
are disabled for matched-fixture RNG because audio cooldowns use wall time;
production Sound is unchanged. These fixtures are not human balance evidence.
Bench uses 600 frames, discards the first 120, and has no screenshot readbacks;
interval measurements are not isolated GPU costs or an FPS guarantee.

Evidence directory:
`/private/var/folders/q6/wd0w60596vg_rnm736shphw00000gn/T/opencode/soulbound-hero-readability-20261009/`.

Durable before/after review and final logs:
`/Users/markrogers/Desktop/art/reviews/soulbound-hero-army-readability-20261009/`.
Open `review.html` for original-resolution comparisons.

## Participants

- GPT-6.1 Sol: army/readability implementation, hero corrections, integration,
  engine verification and visual review.
- DeepSeek V4.1 Flash (`opencode-go/deepseek-v4.1-flash`): initial Battlemage rig
  and hero tests.
- Claude Haiku 5.5 (`opencode-go/claude-haiku-5-5`): independent read-only review
  and rechecks. A mistaken UV-azimuth finding was corrected after verifying
  MeshKit's per-part glow metadata.
- GPT-6 Luna (`opencode-go/gpt-6-luna`): initial read-only exploration; its session
  had no write tools, so implementation was reassigned rather than retried.

No premium agents or new paid art generation.
