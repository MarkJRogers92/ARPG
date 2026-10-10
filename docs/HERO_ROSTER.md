# Approved hero roster

Mark approved the isolated five-hero preview and authorized pushing, merging and
installing it into the full game on October 10, 2026. This includes the previously
approved allied brawler, hero locator, hostile-shot and danger-warning polish
documented in `HERO_ARMY_READABILITY.md`.

## Runtime scope

- All five classes use the supplied 18-bone rigs: Aegis Battlemage, Necromancer,
  Pyromancer, Stormcaller and Reaper. Supplied GLB shapes are unchanged.
- `scripts/visual/aegis_battlemage_model.gd` is the shared presentation adapter.
  Delta/velocity-driven directional walking, grounded boots, thigh-weighted split
  robes, damped cape follow and cast/reap gestures retain gameplay ownership.
  Imported demonstration AnimationPlayers are disabled to avoid pose races.
- Each class retains its cloth, metal and emissive surfaces. Per-instance material
  overrides enable vertex colors; cached copies adapt linear glTF colors to the
  Compatibility renderer. No source GLB or shared imported material is mutated.
- Native class weapon exports use their authored grip origin at a `hand.R` socket.
  The embedded weapon is hidden. Alternate equipped categories keep existing
  meshes with corrected handle alignment. Actual attacks still originate and
  trigger in the existing gameplay/ability code, not in animation.
- Class switching leaves one body visible, preserves equipped items and resets
  changed-class poses. Same-look town presentation does not interrupt movement.
  Five lazily created rigs and a single current native-weapon mesh per model keep
  appearance caching bounded; repeated equipment presentation reuses its mesh.
- `visuals/aegis_battlemage` and `visuals/imported_roster` enable approved visuals.
  Flag-off configurations and unknown/custom palettes retain procedural bodies.

## Production boundaries

The application remains **Soulbound**, bundle identifier
`com.markrogers.soulbound`, using **Godot/app_userdata/ARPG**. Production export
presets, renderer, fullscreen behavior and release workflow are unchanged.
No test-profile name, bundle identifier, copied progress, class-unlock helper or
test save files ship. Original class costs/unlocks, stats, powers, collisions,
attack timing, projectile origins, progression and save schemas are unchanged.
Test-profile free class unlocks must never be transferred to production progress.

Assets live under `assets/heroes/aegis/` and `assets/heroes/roster/`; pack READMEs
retain author provenance. Editable Blender masters remain in the supplied packs.

## Verification and limits

The accepted test build passed Godot **4.6.stable.official.89cea1439** checks:

- 30/30 headless suites; 13,781 roster, 3,654 Aegis and 793 procedural-hero checks.
- All ordered class switches, all four weapon categories for each class, actual
  Reaper timed-throw/cast coupling, material/cache isolation, respawn and deferred
  frees, stationary/forward/backward/strafe movement and same-frame socket poses.
- 673 exported-pack checks, 900 native motion frames, 70 close-up views, four
  actual-town captures and 12 crowded fixtures (each new class in all three realms).
- Five gameplay smoke bots, each configured for up to 420 simulated seconds.
  Some bots died normally; survival is not a balance-acceptance criterion.
- Sixteen alternating native comparisons (two runs per appearance/class), at
  720p with approximately 800 enemies and 40 allies. No slowdown appeared in
  those small sampled fixtures; no general speedup or FPS guarantee is claimed.

Production-source/release checks are rerun during delivery; release/installation
results are recorded separately rather than treating preview evidence as proof
of installed production behavior. Core commands:

```sh
bash tools/run_tests.sh -t "tools/hero_roster_test.gd tools/aegis_visual_test.gd tools/hero_visual_test.gd tools/combat_readability_test.gd"
bash tools/run_tests.sh
```

Run native fixtures only in an isolated profile. `combat_readability_qa.gd` accepts
realm, output directory, stage, class and optional `legacy` benchmark selection.
`aegis_visual_qa.gd` accepts output directory and optional class. Smoke accepts
seconds, optional realm and optional class. Tools are excluded from exports.

These are rigid-weight models, not cloth simulation or a guarantee of no clipping
in every possible pose. Depth-tested markers/locators can still be occluded in a
dense horde. Automated fixtures do not replace human playtesting. Apple M2 native
views use Compatibility; Intel is included in the universal app but not executed.
Known Godot ObjectDB/resource-in-use shutdown warnings remain in some headless or
long-run logs; clean native startup does not claim to fix those engine warnings.

## Participants and durable evidence

- GPT-6.1 Sol: all supplied-model 3D adaptation/animation, integration, visual
  inspection, tests, packaging and production delivery.
- Claude Haiku 5.5: independent read-only code/deployment-safety reviews only.
- The earlier army/readability pass's actual participants are listed separately
  in `HERO_ARMY_READABILITY.md`; no premium modeling agent was used.

Accepted preview evidence:
`/Users/markrogers/Desktop/art/reviews/soulbound-roster-integration-20261010/`.
Production rollout evidence:
`/Users/markrogers/Desktop/art/reviews/soulbound-production-rollout-20261010/`.
