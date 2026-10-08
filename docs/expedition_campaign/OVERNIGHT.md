# Overnight campaign improvements — October 8, 2026

## Authority and deadline

Mark requested continued feature development through the morning. Target cutoff: 7:00 a.m. America/Chicago, October 8. Hourly follow-ups are attached to this chat as `soulbound-overnight-improvements`, with a schedule ending at the cutoff. Continue safe bounded packages; do not start new work after the cutoff. No push, merge, release, deployment, installed-app replacement, purchases, or paid generation.

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
