# Expedition campaign implementation

## Request and boundaries

Implement the October 7 expedition campaign handoff end to end, with fitting new visuals. Work mode; local task commits authorized. Push, release workflow dispatch, merge, deployment and installed-app replacement are not authorized.

## Verified starting state

- Application checkout: `/Users/markrogers/ARPG`.
- Remote default and local HEAD: `claude/focused-fermat-m7jhtk`, `3fe4ea0426e9ef48d2d04d34b75daa90345313a6`.
- Feature branch: `feature/expedition-campaign-v1`, created without moving HEAD.
- Only initial change: `project.godot` feature marker `4.6` → `4.7`; original index empty. Preserve this exact hunk, exclude it from commits.
- Private starting patches/status/project copy: `/Users/markrogers/Documents/Codex/2026-10-07/ple/work/arpg_checkpoint/`.
- Godot: `/opt/homebrew/bin/godot`, 4.7.2.
- Initial import built the missing global class cache. Existing `.glb.import` changes caused by this import are generated task churn to remove before completion.
- Baseline unit tests: `ALL TESTS PASSED (58588 checks)`, exit 0. The known deliberately broken-save error is expected; no baseline script errors.

## Architecture and ownership

See `INTERFACES.md` for shared API and save/state contracts. Campaign owns banked state, scene shell and account reward receipts. Every mission receives a copied departure and creates fresh combat state. Classic `run.save` and settlement remain separate. Boss arrival is 900 seconds with no fight deadline.

- Core worker: campaign state/catalog/controller/save/shell, profile receipts, item identity/RNG/serialization, title and pause entry.
- Combat worker (isolated `work/arpg-combat`): main combat adapter, mission objectives/profiles/terminal arbitration, collaborator guards and combat tests.
- UI worker (isolated `work/arpg-ui`): town/backdrop/route/service/result presentation and UI checks.
- Parent: architecture acceptance, repository preservation, integration, independent review, verification evidence and commits.

## Current verified state

The feature is on `feature/expedition-campaign-v1`, based on `3fe4ea0`. Task commits are `125043d`, `d0196d9`, `4be1500`, `a35ee41`, `3b67fec`, `aede952`, and `473d471`. The original `project.godot` 4.7 feature marker remains a local uncommitted change and is excluded from those commits. Do not push, release, replace the installed app, or merge as part of this handoff.

The campaign core, combat integration, UI, save/recovery behavior, and Classic compatibility checks are complete. Evidence includes 58,594 legacy checks, 865 core checks, 110 real Shell/Main lifecycle checks, 33 combat arbitration checks, Classic smoke/resume/inventory UI checks, and rendered UI behavior checks. Six full finale simulations succeeded across the three biomes and varied builds/clauses; all reached the 900-second boss arrival. Some earlier fresh Ember attempts were limited by the bot orbiting outside the meteor lure radius. A corrected-lure fresh run still failed at 924.92s with three of four seals broken and 33,527.8 boss HP remaining; this is one automated result, not a balance conclusion. A separate tank attempt also failed. These outcomes do not establish that every build or seed wins.

Four short missions succeeded through real combat and controller settlement: Hunt (300s), Breach (360s, three seals), Cursed Cache (360s, cache claimed), and Elite Hunt (302.68s, elite defeated). One normal-speed Hunt completed at 300 simulation seconds over about 304 wall seconds, with time scale 1 and periodic visual observation. These are automated-input demonstrations, not human-play or enjoyment validation.

The continuous journey passed: all 12 real Main settlements succeeded across 12 unique attempts and three biome clears. Actual guardian kills were at 995.74s, 916.64s, and 989.77s. It used an automated full-Necromancer account fixture, proving end-to-end progression but not human balance or enjoyment. Later harness-only artifact/failure-preservation edits received parser checks; the journey was not rerun after those edits. See `VALIDATION.md` for invariant results and exact evidence.

Final comparison in the actual custom-user-data directory found all six MetaProgress, Classic run, and campaign primary/backup fingerprints matching the starting checkpoint; `project.godot` also matches its checkpoint byte for byte. During test setup, two empty campaign fields were temporarily written and then restored; no progression values changed. A test fixture's `MetaProgress.disabled` initial value was corrected. Generated task import churn was restored. Baseline and current Godot shutdown ObjectDB/resource warnings can occur; accepted logs show no script errors, so this work is not described as warning-free.

## Evidence and next step

Parent review and local acceptance are complete. User playtest is the next step; any remote push requires separate authorization. See `VALIDATION.md` for evidence and limits, and keep automated results distinct from subjective player judgment.
