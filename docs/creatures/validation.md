# Validation record

Base `7029bf935c4fb537d5bf21bc5b58dd41bc91a595`, Godot 4.6.3 Compatibility.

## Automated coverage

- Baseline: 24/24 existing headless suites.
- Final integration: 25/25 suites, including the new creature suite.
- Focused creature run: 33,150 checks, zero failures.
- Three standard smoke invocations with a 420-second frame budget passed their
  progress assertions. Graveyard survived (9,845 kills); Frozen ended on hero
  death at displayed 317.9 s (5,432 kills); Ember at 395.5 s (10,290 kills).
  Thus these are not three complete seven-minute survival runs. No SCRIPT ERROR
  appeared. Shutdown diagnostics are disclosed below.
- Creature coverage: six imports and vertex contracts, acyclic rig metadata,
  identical role movement/HP/RNG consumption, original/new render partition,
  charge and contact animation signals, hit/burn cues, death removal, bounded
  death pool, stable 16-creature admission, slot reuse and despawn cleanup.
- Portable animations: all 30 clips imported and produced nonzero CPU-skinned
  vertex motion at sampled phases. Nondeath grounded poses within 1 mm; raven
  hover ~0.45 m. Death intentionally folds/sinks.

## Matched crowded-scene screen

One serial old/mixed pair per realm; 180 frames, first 60 discarded, fixed seed,
1280x720, llvmpipe (LLVM 19.1.7, 256 bits). This is a **software-renderer stress
screen**, not target hardware FPS or a calibrated performance guarantee.
Baseline disables only this new pack; existing specialist variants remain.

| Realm | Enemies | Old mean ms | Capped mean ms | Change | Old p95 ms | Capped p95 ms |
|---|---:|---:|---:|---:|---:|---:|
| graveyard | 1040 | 126.47 | 138.44 | +9.5% | 138.12 | 153.69 |
| frozen | 620 | 94.62 | 106.33 | +12.4% | 102.89 | 117.19 |
| ember | 1000 | 137.16 | 138.48 | +1.0% | 155.24 | 148.03 |

Initial uncapped 50/50 models increased mean frame time by ~77–133% on this
software device and were rejected. Stable admission limits reduce that to
~1–12% in these samples. This remains a cost, not a zero-regression claim;
short sample noise is visible in p95. Preserve the budget until matched tests
on the target Mac establish headroom, including death bursts and allied armies.

## Visual review limits

The gallery shows all six GPU rigs in neutral close-up lighting. Real gameplay
checks use current realm lighting, camera, HUD and input actions with durable
targets and an invulnerable player. They are not human balance playtests. Ember
remains very dark because its existing realm lighting was preserved.

No Mac installation, target-Mac benchmark, exported release, push or merge has
been performed by this task. Source files and a review patch are the delivery.

## Shutdown diagnostics

The unchanged smoke harness exits directly with live game/static resources.
ObjectDB/resource-in-use warnings also appear with CreatureModels disabled
(60-second legacy-path smoke: passed, 16 resources reported at shutdown). The
longer new-pack runs reported 18–23. These are not claimed to be identical clean
shutdowns or a proven memory-leak fix. No in-run script exceptions were observed.
A 30-second diagnostic was too short to earn an upgrade and therefore failed the
smoke harness's progress assertion; the 60-second legacy check passed.

Final rendered checks: all three realms completed 480 frames with 15 gameplay screenshots total; no script exceptions, parse errors or shader compilation failures. Frozen exercised charge anticipation, charging and recovery; contact attack was exercised in the matched-horde fixtures and focused assertions. Engine shutdown resource warnings also occurred in visual fixtures, so these are not described as error-free exits.
