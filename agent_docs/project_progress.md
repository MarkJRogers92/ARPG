# Project progress

## Expedition campaign

Feature work is integrated on `feature/expedition-campaign-v1`, based on `3fe4ea0`. Task commits: `125043d`, `d0196d9`, `4be1500`, `a35ee41`, `3b67fec`, `aede952`, and `473d471`. Campaign core, combat/UI integration, persistence and Classic compatibility checks are recorded in `docs/expedition_campaign/VALIDATION.md`.

The continuous 12-mission journey passed with 12 successful real Main settlements, 12 unique attempts, and three biome clears. It used an automated full-Necromancer account fixture and demonstrates progression, not human balance or enjoyment. Later harness-only artifact/failure-preservation edits received parser checks; the full journey was not rerun after them.

Overnight checkpoint 1 is integrated through `3254886` (starting from `4c641f3`): town readiness guidance, sanctuary progress/trophies, and objective/guardian combat hints. Focused UI, guidance, lifecycle, render, and import checks passed; see `docs/expedition_campaign/OVERNIGHT.md` for evidence and limits. The 12-mission journey was not rerun because this checkpoint changed presentation and guidance only. The overnight task remains active until 7:00 a.m. Chicago time; the next opportunity is after-action reward/choice guidance. No push, merge, release, deployment, or installed-app replacement is part of the task.
