# Expedition campaign validation

Evidence is from Godot 4.7.2 on feature code HEAD `473d471`. Logs live in the projectless task folder `/Users/markrogers/Documents/Codex/2026-10-07/ple/work/`; they are evidence references, not project deliverables.

## Automated checks

| Scope | Result | Evidence |
| --- | --- | --- |
| Campaign core | 865 checks, exit 0 | `work/task10_core_tests.log` |
| Legacy suite | 58,594 checks, exit 0 | `work/logs/units-final-isolated.log` |
| Shell/Main lifecycle | 110 checks, exit 0 | `work/logs/lifecycle-final-art.log` |
| Combat arbitration | 33 checks, exit 0 | `work/logs/combat-33-final.log` |
| Classic compatibility | Smoke, resume, and inventory UI passed | `work/logs/classic-smoke-final.log`, `classic-resume-final.log`, `classic-ui-final.log` |
| Campaign UI behavior | Passed; 26 rendered scenarios at 720p and 1080p | `work/logs/ui-behavior-final-art.log`; rendered fixtures in task outputs |

Godot can print ObjectDB/resource shutdown warnings seen in baseline and feature runs. The accepted logs have no script errors; they do not support a warning-free claim.

## Reproduce the checks

From the project root, use the Godot 4.7.2 executable below. Journey and combat bot runs use disposable campaign/profile paths; the UI fixture is in-memory.

```sh
GODOT=/opt/homebrew/bin/godot
$GODOT --headless --path . -s tools/campaign_tests.gd
$GODOT --headless --path . -s tools/tests.gd
$GODOT --headless --path . -s tools/campaign_lifecycle_test.gd
$GODOT --headless --path . -s tools/campaign_combat_tests.gd
$GODOT --headless --path . -s tools/campaign_ui_test.gd -- behavior
$GODOT --headless --path . --fixed-fps 60 -s tools/campaign_journey_bot.gd -- 31
```

An isolated finale fixture uses this argument form. Every finale fixture prepares preceding route successes with controller settlement fixtures; `full` gives it a fully progressed profile. It is not natural journey evidence:

```sh
$GODOT --headless --path . --fixed-fps 60 -s tools/campaign_combat_bot.gd -- finale graveyard 7 greedy 30 full
```

These commands document reproduction steps; they were not rerun for this documentation update.

## Real mission and finale simulations

Four short missions completed with real combat results settled through the controller: Hunt 300 s, Breach 360 s with three seals, Cursed Cache 360 s with the cache claimed, and Elite Hunt 302.68 s with the elite defeated. The associated logs are `work/logs/{breach,cursed-cache,elite-hunt}.log` and the campaign run record. One normal-speed Hunt completed at 300 simulation seconds in about 304 wall seconds with time scale 1; see `work/logs/normal-speed-observation-v2.log`. Input was automated and visually observed at 25, 120, 240, and 299 seconds. This does not measure human enjoyment.

Six full finale runs succeeded; each recorded the boss arriving at 900 seconds and being killed. These isolated runs use prepared route progress, so they do not establish a continuous campaign:

| Biome | Build / clauses | Result | Log |
| --- | --- | ---: | --- |
| Graveyard | Fresh Battlemage, midboss kite | 955.749 s | `finale-graveyard-fresh-battlemage-midboss-kite.log` |
| Graveyard | Full Necromancer, two clauses | 968.212 s | `finale-graveyard-two-clauses-full-necromancer-boss-aware.log` |
| Frozen Wastes | Full Necromancer, no clauses | 907.570 s | `finale-frozen-full-necromancer.log` |
| Frozen Wastes | Full Stormcaller, two clauses, seed 31 | 931.632 s | `finale-frozen-two-clauses-full-stormcaller-seed31.log` |
| Ember Rift | Full Stormcaller, two clauses, seed 7 | 1026.191 s | `finale-ember-two-clauses-full-stormcaller-seed7.log` |
| Ember Rift | Full Stormcaller, no clauses, seed 7 | 997.514 s | `finale-ember-zero-clause-full-stormcaller-seed7.log` |

Some earlier fresh Ember attempts had the automated player orbit at radius 6.8 while the meteor lure requires staying within radius 4; those runs show a bot limitation. A later corrected-lure fresh Ember run still failed at 924.92 s after breaking three of four seals, with 33,527.8 boss HP remaining. This is one automated outcome, not a balance conclusion. A tank attempt also failed at 1038.812 s with 16,326 boss HP remaining. The six successful finale runs above remain valid; results do not establish that every build or seed wins. Ledger reinforcement boundary fixtures passed 33 targeted checks. For Frozen Wastes, the boss died before the +45 s trigger, so no actual reinforcement was observed there. In Ember Rift with two clauses, Advance Payment and Stolen Arsenal were observed at 900 s and 968 s.

## Journey and preservation notes

The continuous journey passed in `work/logs/journey-seed31-final.log` (exit 0, no errors or warnings): all 12 real Main settlements succeeded across 12 unique attempts and three biome clears. Actual guardian kills were Graveyard 995.74 s, Frozen Wastes 916.64 s, and Ember Rift 989.77 s. All nine final invariants passed: 18 talent points (17 spent plus 1 remaining), empty reward outbox, exactly one account-completion receipt, town reload after four clears, and every new Main began at level 1 with 0 XP. The run used an automated full-Necromancer account fixture; it demonstrates end-to-end campaign progression, not human balance or enjoyment.

After this run, later test-harness changes for test-only artifacts and failure preservation received parser checks; the full journey was not rerun after those harness-only edits.

Final fingerprint comparison in the actual custom-user-data directory found all six MetaProgress, Classic run, and campaign primary/backup files matching the starting checkpoint. `project.godot` also matches its checkpoint byte for byte. During test setup, two empty campaign fields were temporarily written and then restored; no progression values changed. The MetaProgress disabled test fixture was corrected to start as disabled.

Art and presentation were inspected from the actual 720p and 1080p campaign renders, including the Last Lantern sanctuary. Visual review supports layout/art presence, not subjective player acceptance. The installed application and online release were not changed.
