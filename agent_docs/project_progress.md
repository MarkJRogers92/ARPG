# Project progress

## Expedition campaign

Feature work is integrated on `feature/expedition-campaign-v1`, based on `3fe4ea0`. Task commits: `125043d`, `d0196d9`, `4be1500`, `a35ee41`, `3b67fec`, `aede952`, and `473d471`. Campaign core, combat/UI integration, persistence and Classic compatibility checks are recorded in `docs/expedition_campaign/VALIDATION.md`.

The continuous 12-mission journey passed with 12 successful real Main settlements, 12 unique attempts, and three biome clears. It used an automated full-Necromancer account fixture and demonstrates progression, not human balance or enjoyment. Later harness-only artifact/failure-preservation edits received parser checks; the full journey was not rerun after them.

Overnight checkpoint 1 is integrated through `3254886`; checkpoint 2 at `c221155`; checkpoint 3 at `9211a01`. Checkpoint 3 clarifies biome-scaled base gold before event/shard changes, optional Cursed Cache bonus, talent awards by mission and realm, and reserved Rare versus banked finale Legendary prizes. Veiled-route and existing reveal/availability/commit behavior is preserved. Parent reviewed the diff and inspected 720p/1080p fixtures; integrated UI passed (exit 0, no ERROR/WARNING). This view-only change did not affect controller, catalog, economy, gameplay, save, or art. The full journey was not repeated. See `docs/expedition_campaign/OVERNIGHT.md`. Overnight work remains active until 7:00 a.m. Chicago time; next bounded opportunity is to inspect one concrete combat/objective feedback moment or town friction against current state. No release action is authorized.
