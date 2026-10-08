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
