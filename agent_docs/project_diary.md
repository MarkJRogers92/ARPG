# Project diary

## 2026-10-08 — Expedition campaign handoff

Integrated the expedition campaign across campaign state/save/controller, fresh combat instances, mission objectives and finales, town preparation, item/economy services, and campaign presentation. Added the Last Lantern sanctuary presentation using native assets. Detailed contracts remain in `docs/expedition_campaign/INTERFACES.md`; player instructions and tuning live in `PLAYING.md` and `TUNING.md`.

Validation includes core, legacy, lifecycle, combat arbitration, Classic compatibility, rendered UI, four short mission successes, one normal-speed mission observation, six isolated finale wins, and a continuous journey pass with 12 successful real Main settlements, 12 unique attempts, and three biome clears. The journey used an automated full-Necromancer account fixture; it demonstrates progression, not human balance or enjoyment. Later harness-only artifact/failure-preservation edits received parser checks but were not followed by another full journey run. Earlier fresh Ember automation failures are documented without using them as a general balance conclusion. All six save/profile primary and backup fingerprints and `project.godot` matched the starting checkpoint in final comparison. See `VALIDATION.md` for details.
