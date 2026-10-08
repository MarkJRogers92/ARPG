# Overnight campaign improvements — October 8, 2026

## Authority and deadline

Mark requested continued feature development through the morning. Target cutoff: 6:00 a.m. America/Chicago, October 8. Mark shortened the deadline at approximately 4:03 a.m.; this overrides all older 7:00 a.m. continuation notes below. Quarter-hour follow-ups are attached to this chat as `soulbound-overnight-improvements`, with a schedule ending at the cutoff. Continue safe bounded packages; do not start new work after the cutoff. No push, merge, release, deployment, installed-app replacement, purchases, or paid generation.

Schedule and queue statements in earlier checkpoint entries record their status at that time; the morning continuation below records the latest accepted state.

The cutoff was followed by an explicit user renewal documented under “Morning continuation” below. The scheduled automation remains paused and was not restarted. This later accepted work supersedes the cutoff as the latest code state; the older schedule statements are historical.

## Starting checkpoint

- Repository: `/Users/markrogers/ARPG`, branch `feature/expedition-campaign-v1`, HEAD `4c641f3`.
- Existing complete campaign has a passing real 12-mission automated journey; see `VALIDATION.md` for scope and limitations. Do not repeat the entire journey for presentation-only changes.
- Preserve the original uncommitted `project.godot` 4.6-to-4.7 feature marker and all player saves. Initial overnight patch is in the chat's `work/overnight/starting.patch`.
- Native Work routing; Jev's `routing_advice` tool is not exposed. Astra remains explicitly selected for new art/models, Luna for bounded implementation, Sol for architecture/integration and independent acceptance.

## Accepted first checkpoint

Integrated on `feature/expedition-campaign-v1` through `3254886` (after `4a553ae` and `76d80aa`); starting checkpoint remains `4c641f3`. Parent independently reviewed the actual changes and rendered views.

- Town readiness now separates required departure blockers from optional build choices and links required actions to their existing services. Sanctuary reflects journey climates and earned guardian trophies.
- Combat now gives contract objectives and guardian mechanics concise instructions drawn from the existing authoritative objective/final-mechanics state. No damage, timing, economy, or drop tuning changed.
- Parent reviewed the actual 720p town view, plus frozen and victory sanctuary states at 720p/1080p. Guardian/contract HUD screenshots are fixture-only, not live-combat evidence.
- Focused evidence: town UI behavior passed; guidance checks passed 22; lifecycle passed 110 checks with zero failures; backdrop and town render passed; import exited 0; no `SCRIPT ERROR`. Lifecycle shutdown reported 20 ObjectDB instances and 7 resources still in use. Combat arbitration's 33 checks passed in the worker package and were not rerun by the parent.
- All six protected player-file fingerprints and `project.godot` matched the starting checkpoint; 53 task import-metadata files were restored. The 12-mission journey was not rerun because this checkpoint changed presentation and guidance only; prior journey evidence applies to the baseline gameplay.

Workers are done for this checkpoint. Continue hourly follow-ups through 7:00 a.m. Chicago time. The next bounded opportunity is an after-action report that helps players compare rewards and choose a useful next step. Loot quality remains evidence-led; no blanket drop increase is justified by this checkpoint. No external release action is authorized.

## Accepted checkpoint 2 — after-action decisions

Integrated at `c221155`. The results recap records cause, objectives, progression, and exact gold/talent changes. Reward comparisons use the current worn item and accurately label banked field/reward gear versus reserved Ferryman prizes. Compact town shortcuts open only after successful result acknowledgment. Armory, market, results, and Ferryman share read-only current-versus-offered modifier comparisons, including both legendary power descriptions and correct ADD/INC/MORE aggregation. There are no automatic transactions or overall item/build score; older reports leave unknown fields unspecified.

Parent reviewed the actual diff through two correction rounds and inspected the 720p results view and 1080p comparison view. Screenshots are fixture visuals, not live-play proof. Integrated import exited 0; campaign UI behavior passed; lifecycle passed 116 checks with zero failures. Shutdown still reported 20 ObjectDB instances and 7 resources in use; no `SCRIPT ERROR` occurred. The parent restored 53 generated `.glb.import` sidecars; all six original player-file fingerprints and original `project.godot` bytes match the checkpoint. Gameplay, economy, and save controller behavior are unchanged apart from four optional report fields. A full journey or balance matrix was not repeated.

The hourly continuation remains active through 7:00 a.m. Chicago time. No external release action is authorized.

## Accepted checkpoint 3 — route reward terms

Integrated at `9211a01` on `feature/expedition-campaign-v1`. Available route previews now show catalog base gold scaled by biome and label it as the pre-event, pre-shard-conversion amount. Cursed Cache shows its optional scaled bonus. Short routes show +1 talent; early finales show +3; the last finale shows 0. Rare prizes for the displayed slot are labeled as reserved for the Ferryman, while the finale Legendary prize is labeled as banked.

Veiled routes remain veiled, and existing availability, reveal, selection, and commit behavior is preserved. Changes are limited to route view/UI tests; no controller, catalog, economy, gameplay, or save changes, and no new art. The parent reviewed the actual diff, requested and verified a state-preservation test correction, and integrated the behavior. Integrated UI passed with exit 0 and no ERROR/WARNING in `work/route-choice/integrated-ui.log`; focused tests cover all three finale biomes, cache bonus, reveal/veil/unavailable commit, and unchanged supplied state. Parent inspected 720p and 1080p fixture previews; these are not live-play evidence. The full journey was not repeated because this is a view-only change; prior 116-check lifecycle evidence belongs to checkpoint 2.

[720p route preview](/Users/markrogers/Documents/Codex/2026-10-07/ple/outputs/route-rewards-720.png) · [1080p route preview](/Users/markrogers/Documents/Codex/2026-10-07/ple/outputs/route-rewards-1080.png)

Root `project.godot` bytes and all six protected player files matched the original snapshot; no import churn remains from this pass. The next bounded opportunity is to inspect one concrete combat/objective feedback moment or town friction against current state before proposing changes. Do not duplicate active work. The hourly task remains active until 7:00 a.m. Chicago time.

Checkpoint 3 ownership is closed: native Luna implemented; parent Sol independently reviewed and integrated. Jev advice was unavailable; no external classification was requested. No active worker package remains.


## Accepted checkpoint 4 — seal deadline feedback

Integrated at `131a328` on `feature/expedition-campaign-v1`, based on `7573849`. The breach HUD now uses the configured survival target and seal deadline: if seals remain incomplete at the survival target, it displays a seal-deadline countdown and instructs the player to close the remaining seals by the deadline. Both breach aliases are covered. When all seals are already closed, guidance continues to describe surviving until extraction; deadline-free specs invent no deadline.

The change is limited to director presentation and focused combat/guidance tests. Arbitration, timings, gameplay, controllers, saves, and art are unchanged. Parent independently reviewed the actual diff and had the worker repair tests to assert success rather than terminal-only completion. Parent inspected the 720p seal-deadline fixture using catalog durations 360/420 and elapsed 398; [preview](/Users/markrogers/Documents/Codex/2026-10-07/ple/outputs/seal-deadline-720.png) is a fixture, not live-combat proof. Integrated combat tests passed 50 and guidance tests passed 22 (both exit 0, no ERROR/WARNING); logs are in `work/objective-feedback/integrated-{combat,guidance}.log`. Protected player-file states and original `project.godot` bytes matched after tests; no import churn remains. No full journey/lifecycle rerun was made because only two presentation methods changed.

Native Luna implemented; parent Sol reviewed and integrated. Jev advice was unavailable; no external advice was requested. Workers are done. The hourly continuation remains active through 7:00 a.m. Chicago time. Next bounded entry: inspect actual campaign friction or a concrete bug before adding anything; avoid repeated metadata-only polish and speculative changes. No push, release, purchase, or art generation.



## Accepted checkpoint 5 — backpack capacity actions

Integrated at `cb7b961` on `feature/expedition-campaign-v1`, based on `8a02b93`. Market and Armory show backpack usage against `Inventory.BACKPACK_SIZE`. At capacity, Buy and Unequip are disabled with guidance to free space; the full Market view links to Equipment. Existing Claim protection remains, and Equip/swap stays available. Sidebar selection now refreshes its highlight during render.

This is a town UI change; controllers, economy, saves, and art are unchanged. Parent reviewed the actual diff and inspected the 720p full-Market fixture ([preview](/Users/markrogers/Documents/Codex/2026-10-07/ple/outputs/backpack-full-720.png), not live-play evidence). Integrated campaign UI checks passed with exit 0 and no errors or warnings; coverage includes the existing real-controller workflow, full-pack action gates, freeing a slot, navigation/highlight refresh, and render-state preservation. Log: `work/town-flow/integrated-ui.log`. The six protected player-file states and original `project.godot` bytes matched after tests; no import churn remains. No full journey/lifecycle rerun was warranted for this UI-only change.

Native Luna implemented; parent Sol independently reviewed and integrated. Jev advice was unavailable; no external classification was requested. No worker package remains active. Continue only until the 7:00 a.m. Chicago cutoff; inspect a concrete player workflow or functional issue before choosing the next task. No external release action is authorized.


## Latest accepted checkpoint — `36a3c1d`

Work since starting HEAD `370204c` is integrated on `feature/expedition-campaign-v1`: cached native objective props; equipment filters/sorting and stable focus; Market/Trainer focus; shared loadout assembly and starting-build summaries on Route/Trainer; mounted-combat preview parity; talent detail footer/specialization wrapping; and cooldown display precision. Accepted commits: `ddcc4ab`, `de92a86`, `f1fef28`, `de56730`, `6162495`, `6b84318`, `5f7109a`, `36a3c1d`.

Parent reviewed the actual diffs and screenshots; native Sol reviewed the shared assembler and stacking behavior. Integrated checks passed: props, combat 50, loadout 98, talent UI, and lifecycle 137 checks with zero failures. Lifecycle shutdown still reported 12 ObjectDB instances and 6 resources in use. Import exited 0 without `SCRIPT ERROR`; 53 generated import sidecars were restored. Fixtures show UI state, not live-play performance or player acceptance. The `f1fef28` source baseline was run after the shared assembler extraction, so it is not a pre-change run. The build preview reconstructs ephemeral runtime item IDs and advances the counter, but does not mutate saved state. No gameplay balance/economy tuning or save-format change was made.

All packages are closed. Until 6:00 a.m. Chicago time, follow-ups should inspect current state, then implement and verify one useful bounded improvement when justified; no package is currently owned or queued. At cutoff, start no new implementation, record a safe final checkpoint, and pause the automation. Do not repeat journey/lifecycle checks without a relevant code change. No push, merge, release, deployment, purchase, paid generation, or installed-app replacement is authorized. Final preservation check confirmed original `project.godot` bytes and all six protected player-file states match. Saved automation readback confirms the bounded quarter-hour schedule remains active through the cutoff.


## Previous accepted checkpoint — 5:17–5:30 a.m.

Integrated at `762d7ac` on `feature/expedition-campaign-v1`, based on `18943da`. Ledger displays full details for the selected offer and compares it with the worn item while retaining slot/index acceptance and keyboard focus. Recruitment displays incoming veteran details with readable role, rank cap, kills, and nights; pledged veterans cannot be replaced, and confirmation names both veterans. The focused UI behavior run passed (`CAMPAIGN_UI_BEHAVIOR PASSED`, exit 0, no warnings/errors), including exact selected-offer and replacement IDs and cancel-without-change checks. Parent Sol reviewed the actual diffs and fixtures. Fixture previews are not live-play evidence.

Native Luna implemented the two packages in isolated Ledger and roster worktrees; parent Sol reviewed the actual diffs, requested a Ledger keyboard/test correction, then integrated both packages. Jev routing advice was unavailable; the work used native assignments. Both ownerships are closed. The commit changes only `scripts/campaign/campaign_town.gd` and `tools/campaign_ui_test.gd`. No controller, economy, save, or art changes were made. After integrated UI, original `project.godot` bytes and all six protected player-file fingerprints matched; the pre-existing local `project.godot` modification remains preserved. Earlier lifecycle shutdown warnings (12 ObjectDB instances and 6 resources in use) remain unresolved; lifecycle checks were not repeated for this view-only pass. No new implementation is queued. Quarter-hour follow-ups remain active through 6:00 a.m. Chicago time and may inspect current state or complete justified bounded work; at 6:00 stop new implementation and pause the automation. No push or release action is authorized.

- [Ledger selected-offer preview](/Users/markrogers/Documents/Codex/2026-10-07/ple/outputs/ledger-offers-720.png)
- [Ledger worn-item comparison](/Users/markrogers/Documents/Codex/2026-10-07/ple/outputs/ledger-comparison-720.png)
- [Veteran recruitment preview](/Users/markrogers/Documents/Codex/2026-10-07/ple/outputs/veteran-recruitment-720.png)
- [Play Soulbound Campaign.command](</Users/markrogers/Documents/Codex/2026-10-07/ple/outputs/Play Soulbound Campaign.command>)


## Final overnight cutoff — reforge recovery

Accepted at `1c72f95` on `feature/expedition-campaign-v1`. The UI now treats pending reforge values as complete item records, compares original and reforged stats/powers, and shows rarity, level, and the already-paid fee. Market displays pending choices after resume even when local selection is empty. The focus/scroll correction waits for a process frame, rechecks the target and focus ownership, then captures, toggles, scrolls, and restores focus synchronously; it holds no shared property across an await. Native Sol consultant review caught an overlap race in the first helper version; the worker repaired it, and parent acceptance verified the two-restores-before-next-frame full-row test.

Integrated final UI runs passed at 720p and with configured 1920×1080 arguments, with no errors or warnings. The latter is not an independent physical viewport measurement. Save/reload tests confirm exact old/new inventory records and gold, one paid fee, and no duplicate items. Post-test checks confirmed original `project.godot` bytes and all six protected save fingerprints. The inspected `reforge-recovery-720.png` is a fixture, not live-play proof. No real-profile test or release was performed. Earlier lifecycle shutdown warnings (12 ObjectDB instances and 6 resources) remain unresolved and were not rerun. No controller, economy, save-format, or art changes. All implementation is closed with nothing queued; the quarter-hour automation was successfully paused at 6:00 a.m. Chicago time. Logs: `work/reforge-recovery-integrated-final-720.log` and `work/reforge-recovery-integrated-final-1080.log`.

## Morning continuation — accepted at `996ba37`

Mark explicitly renewed implementation after the cutoff; overnight automation stayed paused. Starting HEAD was `beccb9b`. Seal and Cursed Cache prompts identify the nearest eligible site using the current rebound interaction key; Cache guidance warns that opening it summons guardians. Objective interactions take priority over nearby landmarks, preventing one press from activating both. Prompts clear during the return ritual after success or death; dead fallback guidance is suppressed. No art/models, balance, economy, or save changes.

Native Luna implemented; native Sol independently reviewed the actual diff and identified terminal/test issues. Parent verified corrections and byte identity of all six integrated files, then committed. Integrated combat (66) and guidance (23) checks passed. Same-source lifecycle checks passed 145/145, while exit still reports 12 ObjectDB instances and 6 resources. Audio harness experiments involving stopping, clearing, and freeing players did not resolve those warnings; ongoing Ogg playback is not established as their cause, and no player-visible leak is proven. The 720p objective prompt fixture was inspected, not live-play evidence. Six protected save states and original `project.godot` were verified unchanged after integration. The earlier 12-mission automated Necromancer journey remains baseline evidence; it was not rerun and supports no general balance claim. Jev `routing_advice` was unavailable, so the work followed the native plan. No release action. Next useful step: playtest early-campaign prompts/readability and build balance.

Logs: `/Users/markrogers/Documents/Codex/2026-10-07/ple/work/morning_checkpoint/combat.log`, `guidance.log`, and `lifecycle.log`. Fixture: `/Users/markrogers/Documents/Codex/2026-10-07/ple/outputs/objective-prompt-720.png`.
