# Latest session work

Current published checkpoint: approved 24-prop integration and biome compositions merged via PR #45 as `7029bf9` on `claude/focused-fermat-m7jhtk`, released and installed at `/Applications/Soulbound.app`. Verified local, uncommitted follow-ups correct the documentation, add diagnostics, and implement user-approved runtime chunk reuse with audio regression coverage. The audio shutdown warning remains an upstream engine limitation. Check `git status` for current working-tree state.

Earlier entries record their status and evidence at the time, not the current branch or installed build. Their historical test counts (including 23 before the composition suite and 24 afterward) are unchanged.

## Expedition campaign — 2026-10-08

Current status: local Market and departure UI fixes are accepted at `c7ec967` on `fix/campaign-market-departure`, based on published PR #25 (`fb69741`). See the final entry below. Overnight automation remains PAUSED; historical schedule notes describe earlier checkpoints only.

- Feature branch: `feature/expedition-campaign-v1`; base `3fe4ea0`.
- Task commits: `125043d`, `d0196d9`, `4be1500`, `a35ee41`, `3b67fec`, `aede952`, `473d471`.
- Campaign baseline HEAD: `473d471`; overnight checkpoint 1 HEAD: `3254886`.
- Overnight commits: `4a553ae`, `76d80aa`, `3254886`.
- Core, UI/combat integration, persistence, and Classic compatibility evidence is documented in `docs/expedition_campaign/VALIDATION.md`.
- Six full finale simulations succeeded after the 900-second boss arrival; varied fresh/tank attempts also failed. This does not establish universal balance.
- Normal-speed Hunt reached a real 300-second success at time scale 1 using automated input; no human enjoyment claim.
- Continuous journey passed: 12 real Main settlements succeeded across 12 unique attempts and three biome clears; Graveyard, Frozen Wastes, and Ember Rift guardians died at 995.74s, 916.64s, and 989.77s. It used an automated full-Necromancer account fixture, not a human balance test.
- Earlier fresh Ember bot attempts orbited at radius 6.8 while the meteor lure requires within 4. A corrected-lure fresh run still failed at 924.92s with three of four seals and 33,527.8 boss HP remaining; this single automated result is not a general balance conclusion.
- All six save/profile primary and backup fingerprints plus `project.godot` match the starting checkpoint. Test setup temporarily wrote two empty campaign fields and restored them; progression values were unchanged. Godot shutdown warnings remain possible.
- Preserve the local uncommitted `project.godot` 4.7 marker. No push, release, merge, deployment, or installed-app replacement.
- Later harness-only artifact/failure-preservation edits passed parser checks; the full journey was not rerun after them. Baseline campaign acceptance is complete; the overnight improvement task remains active, and remote push needs separate authorization.
- Overnight checkpoint 3 is integrated at `9211a01`: route previews show biome-scaled base gold before event/shard changes, optional Cursed Cache bonus, talent awards by mission and realm, and reserved Rare versus banked finale Legendary prizes. Veiled routes and existing reveal/availability/commit behavior remain unchanged. Parent diff review prompted repair of a vacuous state-preservation test; integrated UI passed (exit 0, no ERROR/WARNING). Parent inspected 720p/1080p fixture views, not live-play evidence. Protected player-file fingerprints and original `project.godot` bytes matched; no import churn. No full journey rerun for this view-only change. Overnight work remains active until 7:00 a.m. Chicago time; next bounded entry is to inspect one concrete combat/objective feedback moment or town friction against current state. Details: `docs/expedition_campaign/OVERNIGHT.md`.


- Overnight checkpoint 4 integrated at `131a328`: breach HUD guidance now reflects the configured seal deadline, including countdown after the survival target when seals remain; aliases and already-closed behavior are covered. Integrated combat 50 and guidance 22 passed (exit 0, no ERROR/WARNING). Parent reviewed the actual diff and inspected a 720p fixture, not live-combat evidence. Protected player files and original `project.godot` bytes matched; no import churn. No full journey/lifecycle rerun for this presentation-only change. Hourly continuation remains active to 7:00 a.m. Chicago time; next entry is a concrete friction point or bug. Details: `docs/expedition_campaign/OVERNIGHT.md`.


- Overnight checkpoint 5 integrated at `cb7b961`, based on `8a02b93`: Market/Armory show used backpack capacity; full-pack Buy and Unequip are disabled with guidance, Market offers an Equipment shortcut, and navigation refreshes selected highlighting. Equip/swap and Claim safeguards remain. Integrated campaign UI passed (exit 0, no errors/warnings), covering the existing real-controller workflow, gates, slot freeing, navigation, and render-state preservation. Evidence: `work/town-flow/integrated-ui.log`; [720p fixture preview](/Users/markrogers/Documents/Codex/2026-10-07/ple/outputs/backpack-full-720.png). Protected player files and original `project.godot` bytes matched; no import churn. No full journey/lifecycle rerun for this UI-only change. Hourly continuation runs to 7:00 a.m. Chicago time; next entry: concrete workflow friction or functional issue. Details: `docs/expedition_campaign/OVERNIGHT.md`.

- Final overnight integration is `36a3c1d`. Accepted commits since start `370204c`: `ddcc4ab`, `de92a86`, `f1fef28`, `de56730`, `6162495`, `6b84318`, `5f7109a`, `36a3c1d`. Added cached native objective props; equipment filters/sorting and focus-following scroll; Market/Trainer focus; shared loadout assembly and Route/Trainer starting-build summary; mounted-combat preview parity; talent detail footer and specialization wrapping; cooldown display precision. Parent and native Sol reviewed consequential diffs. Integrated logs: props PASS, combat 50 PASS, loadout 98 PASS, talent UI PASS, lifecycle 137 checks/0 failures with 12 ObjectDB and 6 resource shutdown warnings. Import exited 0 without `SCRIPT ERROR`; 53 generated import sidecars were restored. Preview reconstructs ephemeral runtime item IDs and advances the counter, with no saved-state mutation. The `f1fef28` original-source baseline ran after extraction. No balance/economy tuning or save-format change. Final preservation check confirmed original `project.godot` bytes and all six protected player-file states match. Saved automation readback confirms the bounded quarter-hour schedule remains active through the 6:00 a.m. Chicago cutoff. No push/release/deploy or paid action. Details: `docs/expedition_campaign/OVERNIGHT.md`.


- Prior cutoff pass at `762d7ac` on `feature/expedition-campaign-v1` added full Ledger offer/worn comparisons and safer veteran recruitment. Integrated campaign UI passed without warnings or errors; fixtures are not live-play evidence. Only town UI and focused UI tests changed. No controller, economy, save, or art changes. Earlier 12 ObjectDB/6 resource shutdown warnings remained unresolved and were not rerun. The pre-existing local `project.godot` change was preserved; after integrated UI, its original bytes and all six protected player-file fingerprints matched. This checkpoint is superseded by the final cutoff below.

## Final overnight cutoff — reforge recovery

Accepted at commit `1c72f95` on `feature/expedition-campaign-v1`. Reforge choices render full original/reforged item records with stat/power comparison, rarity, level, and paid fee; Market shows pending choices after resume even when local selection is empty. Parent diff review and integrated 720p and configured 1920×1080 UI runs passed without errors or warnings. Save/reload checks confirm exact old/new inventory records and gold, a single paid fee, and no duplicates. The 1080p invocation is not an independent physical viewport measurement; `reforge-recovery-720.png` is a fixture, not live-play proof. After tests, original `project.godot` bytes and all six protected save fingerprints matched. No controller, economy, save-format, or art changes. Earlier lifecycle shutdown warnings (12 ObjectDB instances and 6 resources) remain unresolved and were not rerun; no real-profile test or release was performed. The quarter-hour automation is PAUSED as of 6:00 a.m. Chicago time; implementation is closed. Logs: `work/reforge-recovery-integrated-final-720.log` and `work/reforge-recovery-integrated-final-1080.log`.


## Morning continuation — October 8

Mark explicitly renewed implementation after the overnight cutoff. Starting HEAD was `beccb9b`; integrated commit is `996ba37` on `feature/expedition-campaign-v1`. Nearby seal and Cursed Cache prompts use the same nearest eligible site as the current rebound interaction key; cache prompts warn that guardians appear. Objective interactions take priority over nearby landmarks, preventing one press from activating both. Prompts clear during the return ritual after success or death; dead fallback guidance is suppressed. No art/models, balance, economy, or save changes. Native Luna implemented; native Sol independently reviewed the actual diff and found terminal/test issues; parent verified corrections and byte identity of all six integrated files. Jev `routing_advice` was unavailable; work followed the native plan. Integrated combat (66) and guidance (23) checks passed; same-source lifecycle checks passed 145/145 but process exit retained 12 ObjectDB and 6 resource warnings. Audio harness experiments did not resolve them; Ogg playback as their cause and any player-visible leak remain unproven. Six protected save states and original `project.godot` were verified unchanged after integration. The 720p fixture was inspected, not live-play evidence; the existing 12-mission automated journey remains baseline evidence and was not rerun. No art generation, paid action, or release. Next: playtest early-campaign prompt readability and build balance. Logs: `/Users/markrogers/Documents/Codex/2026-10-07/ple/work/morning_checkpoint/combat.log`, `guidance.log`, and `lifecycle.log`.

## Market and departure controls — October 8

Current local integration: `c7ec967` on `fix/campaign-market-departure`, based on published `fb69741` (PR #25 merged). Market rows now display details from `entry.item.data` and compare against worn gear; the purchased-copy label is disabled. The route board stays above preparation and a persistent footer outside the center scroller presents preview/committed **Choose** or **Depart**, retaining existing event/departure blockers and offering the relevant town service when blocked. Integrated Godot 4.7.2 UI behavior passed with clean exit and no errors/warnings; see `work/market-route-clarity-evidence/integrated-ui.log`. Real-controller checks covered generated market records, one purchase, save/reload, and purchased state. Route resume was fixture state only, not a disk reload; existing real-controller event/departure checks remain. Parent inspected 720p fixture images, not live-play evidence. Original project bytes and six save states matched the fresh checkpoint. No art, save/economy/controller changes, push, or release. Running PID 61300 remains untouched; next entry is Save & Leave, close game, reopen existing launcher, Continue Campaign.


## 2026-10-08 — Last Lantern polish preview

Local branch `preview/last-lantern-expedition-polish` starts at Claude's merged town `6768024`. Added wider walk-town framing, footsteps and bus-aware town/transition audio, first-Graveyard gate/causeway and arrival guidance, and cleared-node votives. No save schema, economy or balance changes. Native Luna implemented; independent Sol reviewed and accepted the audio fade-race correction. Forced-walk, first-arrival, repeated-audio, UI behavior, lifecycle (145), and combat (66) checks passed; parent real Hunt completed 300 simulated seconds and settled successfully in a full-profile fixture. Parent inspected 720p renders. Shutdown resource warnings remain; see `docs/expedition_campaign/POLISH_PREVIEW.md` for exact limits and evidence. Original files/saves preserved. No push/merge/release. Next: user playtest using the isolated preview launcher.


## 2026-10-08 — World and feedback follow-up

Mark approved publication of the Last Lantern preview: PR #32 merged as `b9c0c2f`, and all GitHub build/test/export jobs succeeded. New local review branch `preview/campaign-world-and-feedback` adds first-Graveyard composition, destination/arrival/return presentation, objective feedback, and town milestone dressing. Native Luna packages received independent Sol review; parent integrated and verified. Integrated world/walk/arrival/audio/UI, combat70, guidance27, lifecycle150 and Classic60-second smoke passed. Rendered fixtures inspected; shutdown audio/resource cleanup warnings remain. Original profile/settings fingerprints match. No save format/economy/balance changes. The new preview remains unpushed/unmerged for user review. See `docs/expedition_campaign/WORLD_FEEDBACK_PREVIEW.md` for scope, exact evidence and limitations.


## 2026-10-08 — Onward biome settlements preview

Mark approved a forward journey with different camps/cities for each biome. Local `preview/onward-biome-settlements`, based on merged PR #33 (`4035c99`), adds 12 biome stops and Dawn's Rest. A pure resolver follows committed biome/clears/completion; original Last Lantern stays the starting scene, while subsequent stops have distinct scenery and biome lighting. Services and hero/camera persist. Failed attempts and withdrawals do not advance; guardian victory enters the next biome. No save schema, controller, economy, or balance changes.

Native Luna packages and independent Sol review; parent integrated and inspected native 720p views. Integrated waystop 66 (windowed capture variant 70), all-stop movement/service 571, world 50, walk 43, UI, backdrop, sound lifecycle, and campaign lifecycle 150 passed. First victory uses real Shell/Main with an injected result, not another full combat playthrough. Existing shutdown ObjectDB/resource warnings remain. Original six save states and project settings fingerprints match. The launcher uses a separate copied profile. Jev routing unavailable; native plan retained. Local review only, no publication. Details and limitations: `docs/expedition_campaign/ONWARD_PREVIEW.md`.


## 2026-10-08 — Camp visual polish preview

Local branch `preview/camp-visual-polish` is based on merged PR #34 (`1c44652`). Added more legible pitched canvas shelters, seams, ropes/stakes, entrance lanterns, cooking sites, bedrolls, supplies and worn ground, with snow windbreaks and ember heat shields. Gravediggers’ Camp, Whitepass Refuge, Sledwright’s Rest and Redwake Caravan were inspected at native 1280×720. Lighting now refreshes when leaving Last Lantern for a camp in the same biome and resets on return.

Native Luna implemented; independent Sol accepted the actual diff, and parent verified final evidence. Visual/movement/service checks 582, walk-town 43 and backdrop passed with clean final logs. These are fixture and input-path checks, not a full human playthrough. Original six save-file states and project settings match fresh fingerprints. Isolated preview profile and launcher prepared; generated sidecars restored. Jev unavailable; native plan retained. Local review only, no push/merge/install. See `docs/expedition_campaign/CAMP_POLISH_PREVIEW.md`.


## 2026-10-08 — Gravediggers’ Camp life preview

Local `preview/gravediggers-camp-life`, based on merged PR #35 (`2df2ec1`), adds three camp residents, role-specific arm/tool motion, hearth smoke/embers/flicker, a quiet generated SFX-bus fire loop, and Mara Venn’s optional repeatable dialogue. The encounter respects current Use mapping, service precedence and forced phases, freezes walking while open, and closes through Escape or Leave without rewards or campaign mutation. Scope is this one stop.

Native Luna implemented; native Sol independently reviewed. Parent verified its showcase scene-ownership and role-specific motion-test corrections, final logs and native 720p camp/dialogue views. Focused camp 46, all-stop movement/service 582, walk-town 43, UI behavior, backdrop and real-Shell showcase/title-return checks passed. Audio was checked instrumentally, not listened to; physical remapped-key input and a full human campaign were not tested. Focused shutdown diagnostics remain (4 ObjectDB/2 resources; showcase 12/6). Original six save states and project settings match. Direct demo uses fresh disposable campaign files with account progression disabled; normal preview uses a separate copied profile. Generated imports restored, Jev unavailable/native assignment retained. No publication or installed-app replacement. Details: `docs/expedition_campaign/CAMP_LIFE_PREVIEW.md`.
## 2026-10-09 — Approved 24-prop scenery integration (subsequently merged in PR #45)

Integrated the corrected 12 graveyard props plus six Frozen Wastes and six
Ember Rift props under `assets/environment/arpg_pack/06_approved_collection/`.
All 24 GLBs match the approved hashes; catalog and Godot import sidecars included.
Appended AssetProps/Models kinds, conservative scaled footprints, biome-exclusive
densities, circle collisions for solid set pieces, and matching glow/motes.
Existing usable-piece placement weights are preserved; landmark shares are
0.483 / 0.430 / 0.445. The Rift arch stays passable; the sealed gate and single
fence/barricade segments block movement. Chests/shrines/lava remain static scenery;
no new loot, objectives, hazards, animations, save schema or balance mechanics.
The Lantern Warden character remains external/unrigged, not integrated.

Sol implemented/integrated; GPT-6 Luna personal added tests; DeepSeek Flash API
independently reviewed and rechecked the bounded collision/docs/test fixes.
Godot 4.6 Compatibility: all 23 headless suites passed; new catalog/placement/
frame-driven cleanup suite passed 41,848 checks. Three smoke bots ran with a
420-second frame budget (one ended early on death), passed, and had no script
errors. ObjectDB/resource-in-use exit warnings also reproduced in all three
pre-integration `c60f2d6` baseline smoke runs; they remain unresolved.

Inspected 13 native 1280×720 gallery/field/behind/crowd captures plus three final
collider galleries and controlled mausoleum occlusion on/off. Rendering used
same-source copied projects with separate save folders and window overrides
(Mac startup fullscreen otherwise ignored CLI capture dimensions). These are
controlled visual checks, not a full journey or performance benchmark. The
external off-window harness initially crashed on shutdown with a server-signal
lambda connected; a named callback and explicit disconnect fixed the harness,
and the control rerun was clean. No game-runtime signal code changed.

Original `project.godot`, tracked UIDs/imports and all 184 original save-file
fingerprints preserved. No commit/push/merge/release or installed-app update.
Review board, native captures, test logs and verification JSON:
`/Users/markrogers/Desktop/art/reviews/soulbound-integrated-24-20261009-194959/`.
Minor limit: circle approximations allow some sled runner-corner clipping.

## 2026-10-09 — Purposeful biome scenery composition (subsequently merged in PR #45)

The user approved a placement pass after finding the new props too randomly
arranged. `DecorCompositions` now provides 13 primary-anchor layouts, with
mirrored variants: aligned grave rows/mausoleum courts, side-gated burial plots,
sheltered snow supply camps/shrine trails, and forge yards/arch approaches.
All 24 approved kinds remain represented. Single fence segments avoid duplicate
terminal posts; sealed gates and barricades sit beside public approaches, and
the Rift arch's original opening remains unchanged.

`WorldDecor` preserves the original seeded scatter plan for all `Landmarks.USES`
transforms, counts and colours, then replaces approved cosmetic scatter with
cluster members. Old loose imported candidates are thinned to 45%; code-built
scatter is suppressed inside yards/approaches without rerolling its transforms.
One primary slot per chunk remains; auxiliary fences/shelters may also carry
landmark metadata. Bounds stay inside 12 m chunks, whole compounds stay outside
the start exclusion, and usable scenery wins any composition conflict.
Approaches are local 1.9–2.2 m lanes, not a connected road/campaign routing system.
Three shared ground MultiMeshes draw feathered paving/compacted snow/ash stamps;
their state clears on chunk/realm/density changes. No new gameplay interactions.

Verification used Godot **4.6**, same-source disposable projects with separate
profiles, and the existing runner: all **24 headless suites passed**, followed
by the final three affected suites after dependency/test cleanup. The new
composition suite passed **79,070 checks**, including both layout variants,
1,500 distant single chunks, neighbour-chunk collision clearance, frame-stepped
approach traversal, exact usable placement parity and deferred render cleanup.
Three smoke bots passed a 420-second frame budget (Ember ended early on death);
no script errors. Fifteen native 1280×720 captures cover before/after, alternate
places, 220-enemy crowds and behind-anchor views. Before/after camera transforms
match exactly. These are controlled checks, not a full human journey or a
performance benchmark; known ObjectDB/resource shutdown warnings remain.

Review/preview/logs: `/Users/markrogers/Desktop/art/reviews/soulbound-composed-environments-20261009/`.
`tools/decor_composition_test.gd` is in the default runner; new script/shader
UIDs were generated by the engine. The source project parses without requiring
a new global-class cache entry (explicit composition-module preload); existing
project settings and tracked imports/UIDs remain unchanged. All **354 non-log
original profile-file hashes** match the pre-test snapshot; source parse checks
rotated normal engine logs only. Existing uncommitted integration work is kept.

Sol implemented/refined/integrated and reviewed native views; GPT-6 Luna through
OpenAI drafted layouts and tests; DeepSeek API independently reviewed the delta.
No premium agents, new paid art generation, installed-app update, publication,
push or merge.

## 2026-10-09 — Publication and local installation

At the user's request, Sol committed the approved integration/composition as
`9a6164f`, pushed `feat/approved-biome-compositions`, and merged
[PR #45](https://github.com/MarkJRogers92/ARPG/pull/45) as `7029bf9`.
[Build run 38013169086](https://github.com/MarkJRogers92/ARPG/actions/runs/38013169086)
passed tests and all three exports; Mac/Windows/Linux latest releases matched
the merge SHA. This supersedes the original entries' local/unpublished status.

Installed the matching universal Mac release at `/Applications/Soulbound.app`
after checking the ZIP's published SHA-256, archive paths, bundle signature and
every installed file against the downloaded bundle. The exported data passed
64 asset/composition checks with the full engine; the release executable
disallows CLI path overrides, and those controls were not changed. Actual
exported-app headless and native Metal/OpenGL startup passed. All 354 original
non-log profile fingerprints were unchanged at installation; the old app and
profile were backed up. Known shutdown diagnostics persisted; no full human
campaign or deployment performance benchmark was claimed. Evidence/rollback:
`/Users/markrogers/Desktop/art/reviews/soulbound-delivery-7029bf9/`.

## 2026-10-09 — Status correction and diagnostic-only follow-up

User authorized only the recommended status-pointer correction, controlled
shutdown-cache experiment and rebuild measurement. Both current-status pointers
now identify PR #45/`7029bf9`; history remains intact. Added standalone
`tools/shutdown_cache_probe.gd` and `tools/decor_benchmark.gd`, not default test
suites. No `scripts/`, shaders, placement, loading, gameplay, release workflows
or installed-app code changed; no new commit/push/merge/install was performed.
The user's pre-existing untracked `docs/CODE_REVIEW_HANDOFF.md` was preserved.

Verification used the explicit Godot **4.6.stable.official.89cea1439** binary,
a same-source disposable project and a different user-data folder. The current
`/opt/homebrew/bin/godot` reports **4.7.2**, so it was not used. Engine-generated
UIDs for the two new tools were brought back; existing imports/UIDs and project
settings were not edited.

- **Shutdown probe:** 16 fresh processes covered empty, minimal-prop, combined visual
  and short real-Main fixtures, each with no cleanup, two mesh caches cleared,
  all five visual caches cleared, and all caches plus gameplay static resets.
  Fixture nodes were deleted and four frames awaited before inspecting cleanup;
  weak references confirmed every tracked visual resource was released by full
  cache cleanup. Empty/prop/visual fixtures exited without leak warnings even
  without cache clearing. All four Main runs still reported **12 leaked objects
  and 6 resources**, exclusively Ogg sequence/stream/playback objects for
  `boss.ogg`, `graveyard_calm.ogg`, and `graveyard_drums.ogg`. Visual caches are
  **not the cause of this reproduced diagnostic**. Audio teardown is the next
  investigation target, not a proven underlying diagnosis or a production fix;
  shutdown warnings remain unresolved.
- **Benchmark:** three fresh headless processes, each with both modes, all three
  realm densities and 9/49/121-chunk views, three warmups and 30 timed samples
  per mode/metric/case. All 54 repeated-center determinism checks passed per run.
  Mode order alternated; asset startup was excluded. `applied_rebuild` includes
  compute, CPU-side MultiMesh writes and obstacle updates, not GPU completion.
  The comparison is this revision with `compositions=false` versus `true`, not
  a historical pre-integration checkout. Pooled 90-sample medians at the default
  49-chunk view were **5.47→11.03 ms graveyard, 4.83→10.31 ms frozen, and
  4.88→10.43 ms ember** (legacy→composed applied rebuild); composed p95 was
  **11.32 / 10.60 / 10.73 ms** on Apple M2. Composed compute medians were
  **10.59 / 10.03 / 10.10 ms**. At 121 chunks, composed applied medians rose to
  **27.48 / 25.47 / 25.97 ms**. Roughly twice the rebuild CPU cost is measured,
  but no live frame-rate, GPU cost, enemy-load budget or causal attribution to
  individual loops is established. `_inside_group` uses per-chunk groups; the
  original review draft's claimed all-view accumulation does not apply. Optimization remains
  a separate follow-up rather than a change here.
- **Regression:** existing runner, three focused suites passed (`tests.gd`,
  `approved_collection_test.gd`, `decor_composition_test.gd`). No new full-suite,
  smoke-bot or visual run was needed or claimed for this diagnostic-only change.

All 367 original non-log profile-file hashes and the installed data-pack hash
match the diagnostic starting snapshot. The review handoff received a concurrent
self-audit from outside this task; that updated file was left untouched.

Raw logs, three benchmark JSONs with samples/counts, and pooled/probe results:
`/Users/markrogers/Desktop/art/reviews/soulbound-diagnostics-7029bf9/`.
Sol implemented the experiment, reviewed/refined and ran the benchmark, and
updated the docs. GPT-6 Luna through OpenAI drafted the benchmark; no premium
agents or paid art generation were used.

## 2026-10-09 — Runtime chunk reuse and audio shutdown investigation (local)

User approved the runtime performance follow-up and investigation of the audio
exit warnings. `WorldDecor` now retains only the currently visible chunk data:
an axial crossing of the default 7×7 view reuses 42 chunks and generates seven;
a diagonal crossing reuses 36 and generates 13. Density, composition mode,
chunk size and fixed-prop changes invalidate the cache, including in-place
nested edits. Leaving the tree releases it; `cache_chunks=false` disables it.
Sparse chunk maps avoid storing/merging off-biome empty arrays. Public frame
state deep-copies nested collisions, glow, groups and marks, so consumers cannot
corrupt retained data. The original draw sequence, layout, collision and order
remain unchanged. `compute()` is still an uncached placement oracle; fixed
showcase pieces append after all chunks as before. No eager-loading change.

All **432 full-output fingerprints** match the pre-change source, across three
realms, both composition modes, three chunk sizes, three view sizes, four
centres and fixed-prop presence/absence. The final cache suite passed **10,314**
headless checks and **65,452** native renderer checks (Apple M2 Metal/OpenGL
Compatibility), covering overlap identity reuse, output parity, nested config
invalidation, resizing, warps/revisits, disabled cache, public-state mutation
and deferred teardown. Native colours are compared against an independent
MultiMesh round-trip because Compatibility packs colour components into 16
bits; the dummy headless renderer does not support instance readback. The new
suite is registered in the default runner. Five focused suites passed before
final sound-test assertion refinement; the final full runner passed **25/25**
suites, followed by the cache-suite rerun after adding six global-RNG isolation
checks (pure/cold/overlap generation, both modes). Three 420-second-frame-budget
smoke bots passed without script errors
(Frozen ended on death; elapsed combat time can differ from the frame budget
because of upgrade pauses). Shutdown warnings persisted in Frozen/Ember runs,
with 21/22 resources reported; no warning-free production quit is claimed.
Final sound tests also passed directly under verbose headless and native
CoreAudio/Metal execution with the test-only wall-clock drain.

A verbose, seeded heavy Frozen control passed on both baseline and current
source. The current run's 21 retained resources were exclusively music/Ogg and
SFX/WAV; no scenery resource was reported. The control's kill totals differ and
are not a deterministic replay claim: Sound uses wall-clock cooldowns and
global pitch randomness, which interact with accelerated `--fixed-fps` runs.
The placement code itself passed all six global-RNG isolation assertions.

Benchmark hygiene: an audio diagnostic's zsh scalar PID-list cleanup failed,
leaving eight CPU stress children running. Sol identified their exact command
paths, terminated only those owned children, and discarded all earlier stream
timing results. Final default-view paired measurements are rerun after cleanup;
the incident and targeted process cleanup are recorded in the review folder.

Clean benchmark: six fresh processes (three before, three after), alternating
phase order, the default 49-chunk view, all three realms, cold/repeat/axial/
diagonal/teleport scenarios, three warmups and 30 samples per scenario/run.
Pooled 90-sample CPU medians for ordinary axial crossings were **12.07→3.32 ms
graveyard, 12.46→2.35 ms frozen, 12.56→2.62 ms ember** (72–81% reduction);
composed p95 was **3.95 / 2.89 / 3.29 ms**. Diagonal crossings fell to
**4.87 / 3.82 / 3.91 ms**, about 61–69% less CPU time. Same-centre rebuilds
fell to **1.51 / 0.82 / 0.95 ms**. This is headless main-thread target-rebuild
time including MultiMesh writes and obstacle updates, not GPU completion,
full gameplay-frame cost, live FPS or a human performance assessment.

Trade-off: cold views still generate every chunk. Graveyard cold fill measured
**11.18→14.89 ms** (+3.71 ms); frozen/ember cold medians were slightly lower.
Teleport medians were close (graveyard **13.67→13.97 ms**, frozen
**12.83→12.14 ms**, ember **12.72→12.94 ms**). No uniform startup/teleport
improvement is claimed. `quiet-stream-summary.json` and six `quiet-*.json` files
contain all samples/counts; earlier stress-contaminated runs are not used.

**Audio remains an engine limitation, not a fixed warning.** DeepSeek traced the
Ogg playback references to AudioServer's asynchronous retirement, matching open
[Godot issue #76745](https://github.com/godotengine/godot/issues/76745), which Sol
independently checked. Explicit Sound teardown (stop all players, clear streams,
cancel tweens) did not meaningfully improve a verbose A/B: baseline **10/12**
runs warned, candidate **8/12** warned. Fresh-copy normal headless runs were
mostly clean (one warning in 56+ probes); two native CoreAudio runs were clean.
This timing variability is not proof that production quit is warning-free.
`scripts/audio/sound.gd` stays unchanged; no blocking delay, engine replacement,
quit interception or warning suppression was added to gameplay.

The real-Sound suite now covers repeated realm changes, looping calm/drums,
same-realm stop/resume, all-layer fade to silence, fade progression while paused,
the requested SFX stream and automatic static-owner release. A **test-only**
300 ms wall-clock drain yields frames after freeing the shell: a simulated
SceneTreeTimer is not a real-time drain under `--fixed-fps`. This provides time
for mixer cleanup, not a production fix or a leak-free assertion.

Sol implemented/refined chunk reuse and integration; DeepSeek V4.1 Flash
(`opencode-go/deepseek-v4.1-flash`) investigated audio and drafted regression
checks; Claude Haiku 5.5 (`opencode-go/claude-haiku-5-5`) independently reviewed
the cache and final test logic. No premium agents. All engine runs used the
explicit Godot 4.6 binary in disposable projects with separate profiles. Work
remains local and uncommitted; no push, merge, release or installed-app update.
Final preservation verified all **367** original non-log profile hashes and the
installed data-pack hash unchanged; source runtime/tests match the tested copy.
Final evidence index: `runtime-fix-verification.json` in the review folder.
Evidence: `/Users/markrogers/Desktop/art/reviews/soulbound-runtime-fixes-7029bf9/`
and `/Users/markrogers/Desktop/art/reviews/soulbound-audio-fix-7029bf9/`.
