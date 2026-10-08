# Project diary

## 2026-10-08 — Expedition campaign handoff

Integrated the expedition campaign across campaign state/save/controller, fresh combat instances, mission objectives and finales, town preparation, item/economy services, and campaign presentation. Added the Last Lantern sanctuary presentation using native assets. Detailed contracts remain in `docs/expedition_campaign/INTERFACES.md`; player instructions and tuning live in `PLAYING.md` and `TUNING.md`.

Validation includes core, legacy, lifecycle, combat arbitration, Classic compatibility, rendered UI, four short mission successes, one normal-speed mission observation, six isolated finale wins, and a continuous journey pass with 12 successful real Main settlements, 12 unique attempts, and three biome clears. The journey used an automated full-Necromancer account fixture; it demonstrates progression, not human balance or enjoyment. Later harness-only artifact/failure-preservation edits received parser checks but were not followed by another full journey run. Earlier fresh Ember automation failures are documented without using them as a general balance conclusion. All six save/profile primary and backup fingerprints and `project.godot` matched the starting checkpoint in final comparison. See `VALIDATION.md` for details.

## 2026-10-08 — Overnight checkpoint 1

Integrated through `3254886` from the overnight start `4c641f3`. The route board distinguishes required blockers from optional preparation and links blockers to services; the sanctuary reflects biome progress and earned guardian trophies; combat offers concise objective and guardian-mechanic guidance from authoritative state. No combat, economy, or drop tuning changed. Focused checks passed; lifecycle shutdown reported 20 ObjectDB and 7 resource warnings. Protected player files and `project.godot` matched the starting checkpoint, and 53 task import-metadata files were restored. The 12-mission journey was not rerun for presentation/guidance-only changes. Details and evidence limits: `docs/expedition_campaign/OVERNIGHT.md`. Work continues hourly until 7:00 a.m. Chicago time; after-action reward/choice guidance is the next opportunity.

## 2026-10-08 — Overnight checkpoint 2

Integrated at `c221155`. Results now recap recorded cause, objectives, progression, and exact gold/talent changes; distinguish banked gear from Ferryman-reserved prizes; and expose town shortcuts only after successful acknowledgment. Armory, market, results, and Ferryman share read-only current-versus-offered comparisons, including legendary power descriptions and ADD/INC/MORE aggregation. No automatic transactions or overall item/build score were added. Focused import, UI behavior, and 116-check lifecycle evidence passed; shutdown still reports 20 ObjectDB instances and 7 resources in use. Fixture screenshots are not live-play proof. Original player files and `project.godot` matched; 53 generated import sidecars were restored. No journey or balance matrix repeat was warranted. Next: read-only inspection for confirmed route/reward discoverability friction; see `docs/expedition_campaign/OVERNIGHT.md`.

## 2026-10-08 — Overnight checkpoint 3

Integrated at `9211a01`. Route previews clarify scaled base gold before event/shard changes, the optional Cursed Cache bonus, talent awards by mission and realm, and reserved Rare versus banked finale Legendary prizes. Veiled routes and existing reveal/availability/commit behavior remain intact. Parent diff review caught a vacuous state-preservation test, which the worker repaired; focused integrated UI passed with exit 0 and no ERROR/WARNING. Parent inspected 720p/1080p fixture previews, not live-play proof. Protected files matched the original snapshot; no import churn. The full journey was not repeated for this view-only change. Overnight work remains active through 7:00 a.m. Chicago time; next bounded inspection is one concrete combat/objective feedback moment or town friction. Details: `docs/expedition_campaign/OVERNIGHT.md`.


## 2026-10-08 — Overnight checkpoint 4

Integrated at `131a328`. Breach guidance now follows configured survival/deadline values, shows a countdown for incomplete seals after the survival target, and keeps extraction guidance when all seals are closed. Both breach aliases are covered; deadline-free specs invent none. Parent review prompted tests that assert successful completion. Integrated combat (50) and guidance (22) checks passed, exit 0 with no ERROR/WARNING. Parent inspected a 720p fixture, not live-combat proof. Protected player files and original `project.godot` bytes matched; no import churn. No full journey/lifecycle rerun for the two-method presentation change. Details: `docs/expedition_campaign/OVERNIGHT.md`.
