# Mac validation — 2026-10-10

The two supplied commits applied cleanly to fetched default-branch base
`7029bf935c4fb537d5bf21bc5b58dd41bc91a595`. Library package version 1 passed
its ZIP SHA256, archive CRC, and all 53 internal hashes. No art was regenerated.

On Apple M2 with Godot 4.7.2 Compatibility, all 25 headless suites passed.
The creature suite passed 33,174 assertions. All three 420-second-budget smoke
bots passed progress checks; Graveyard and Frozen survived their frame budgets,
while Ember ended in hero death (4,623 kills and 20 upgrades). No in-run script,
parse, or shader exceptions were observed. Existing ObjectDB/resource warnings
at fixture shutdown remain and are not claimed fixed.

Actual Main-scene captures showed original and new Ember creatures together,
readable basalt/ash, warm lava cues, and the 720-second boss lighting tint.
These Retina captures were 2940×1846 pixels; the supplied cloud fixture's
hard-coded 1280×720 and software-renderer labels are not their physical size or
device identity. Their screenshot pauses and concurrent smoke runs make those
capture timings unsuitable for performance claims.

## Matched Mac performance screen

Separate serial comparisons used the actual old base and applied source,
1280×720 render textures, seed 38289, VSync disabled, a fixed simulation
timestep, and 270 frames with the first 60 discarded. No test or visual run
overlapped these measurements. Death-burst fixtures included 32 allies and
eight kill/replenish bursts. See `mac-performance.json` for raw summaries.

| Realm | Scenario | Enemies | Old mean / p95 ms | New mean / p95 ms |
|---|---|---:|---:|---:|
| Graveyard | Crowded | 1040 | 12.83 / 14.09 | 13.29 / 15.07 |
| Frozen | Crowded | 620 | 12.11 / 14.21 | 13.03 / 14.57 |
| Ember | Crowded | 1000 | 13.63 / 14.41 | 10.41 / 14.32 |
| Graveyard | Death bursts + allies | 1040 | 18.39 / 30.17 | 18.23 / 29.06 |
| Frozen | Death bursts + allies | 620 | 14.91 / 27.43 | 18.21 / 30.49 |
| Ember | Death bursts + allies | 1000 | 16.79 / 29.85 | 17.72 / 28.98 |

Frozen's initial death-burst mean increase was 22.2%. One bounded reversed-order
repeat measured old 16.89 / 29.24 ms and new 17.49 / 29.76 ms, a 3.5% mean
increase. Both results are retained; this short screen does not establish a
sustained 22% regression or an Ember performance improvement. Both versions
showed burst spikes. These are device measurements for controlled fixtures,
not a full-resolution, sustained gameplay FPS guarantee.

New-model swarms retained exactly 16 living detailed actors, with excess enemies
using original appearances. Replenishment reused slots without swapping living
models. The maximum observed cosmetic death pool was 24; its tested duration
remains 0.55 seconds. No gameplay, collision, RNG, save-schema, or art correction
was needed during Mac validation.

The original local checkout and its import edits were preserved. Validation
used a separate QA player-data folder; all 365 starting real player files kept
their hashes. Generated Godot 4.7 import-sidecar churn in the isolated worktree
was restored before publication. The existing app and player folder were copied
for rollback before replacement. The merged CI build and installed exact-build
launch are the remaining installation gates.
