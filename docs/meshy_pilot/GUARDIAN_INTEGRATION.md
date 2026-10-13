# One-handed guardian: opt-in Main encounter

This branch integrates the reviewed one-handed guardian into the real Soulbound
session. It inherits `scenes/main.tscn`: the normal player, auto-attacks, projectiles,
element reactions, camera, HUD, XP, loot and Soul Army registration remain active.
The default scene and normal wave mix are unchanged.

## Play

With Godot 4.6, open `scenes/pilot/guardian_encounter.tscn` and use **F6**, or run:

```sh
godot --path . res://scenes/pilot/guardian_encounter.tscn
```

- WASD/arrows move; Space dashes; the normal weapons auto-attack. T toggles mouse aim.
- One guardian starts nearby. G adds one, up to three living guardians.
- Five seconds after the cohort is cleared, one new guardian enters.
- Escape opens the normal pause menu. Quit to title returns to the normal Main title.
- This is an isolated test encounter: permanent progression is disabled, the normal
  suspended-run path is not used, and Save and quit is unavailable. In-run rewards
  still work. Restart reloads the encounter.

## Combat and lifecycle contract

`GuardianSwarm` subclasses `EnemySwarm`. Its authoritative `pos`, `hp`, `ids`,
status arrays and spatial hash remain compatible with existing targeting,
projectile deduplication, area attacks, status reactions and Main death rewards.
Visuals are keyed by stable ID, never a row index that can be swap-removed.

- At most **3 live skeletal actors + 3 retiring death actors**. Deferred deletions
  are cleared on the following scene-tree frame. The large MultiMesh horde path
  is not rewritten. The legacy body is hidden; the existing batched shadow remains.
- Chase moves the canonical row through the existing scenery-circle slide solver.
  Frost slows movement and the Walk playback rate. Attack/Hit hold the actor root;
  facing locks for the cut so a sidestep can evade it.
- The exact reviewed Attack is 1.20 s: wind-up to **0.40**, active **0.40–0.65**,
  recovery to **1.20**, followed by a 0.55 s pause before the next accepted attack.
- Combat samples the actual evaluated `SwordGrip` bone at up to **120 Hz**. The
  compact blade runs from local Y=0.25 to Y=0.962 m. Blade samples and base/mid/tip
  sweeps are tested against the upright hero capsule (0.5 m radius, Y=0.45–1.25 m
  center line), with a 0.06 m blade margin. The hilt does not deal damage.
- One contact attempt per stable enemy/swing pair. `Player.take_damage` remains
  authoritative for dash, shield, invulnerability, armour and death. A contact
  during immunity consumes that swing; it cannot hit again when immunity ends.
- Inherited touch damage is zero. No extra radial damage is layered over the blade.
- Nonlethal incoming hits request Hit, with a 3 s stagger cooldown so ordinary
  volleys do not permanently prevent an attack. Damage still applies during that
  cooldown. Frost/shock/burn use the existing Elements routes and visible tints.
- Death closes attack immediately, removes the live visual mapping, emits the
  existing reward once, then holds the 1.4 s authored Death until cleanup.
  Despawn clears live/death visuals without rewards. New spawns receive new IDs.

Initial encounter tuning is 200 HP, 2.2 m/s chase, 12 sword damage, 12 XP and a
15% normal loot roll. These are prototype values, not a full progression balance pass.

## Source and asset identity

Base repository commit: `c626246482537453954ae4972231f7227e28081e` on the repository's
default branch, `claude/focused-fermat-m7jhtk`. The integration branch is
`codex/guardian-enemy-integration`.

The GLBs are unchanged from the reviewed version-4 preparation package:

- `assets/meshy_pilot/guardian_one_hand.glb` SHA-256:
  `bc055890c4a13f71564b697aebf244a456d458a0839a9aea1fcf1ad320320923`
- `assets/meshy_pilot/soulforged_one_hand.glb` SHA-256:
  `d5f8764be334b5e388ff3d03770e8565986dd62451af5ec04d51d9929bee368e`

Import remains 120 Hz with animation optimization/compression disabled. The
presentation/foot-contact adapters are carried over; default asset paths now
resolve inside this repository. Gameplay does not re-author the clips. A small
project-style shader adds hit/status feedback and uses the enemy lighting layer.
No additional Meshy generation or credits were used.

## Validation

Run the aggregate and the added focused checks separately:

```sh
bash tools/run_tests.sh
bash tools/run_tests.sh -t tools/guardian_integration_test.gd
godot --headless --path . --fixed-fps 60 -s tools/guardian_encounter_smoke.gd -- 30
godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420
```

Final local results with Godot 4.6.3 / Compatibility:

- Existing aggregate: **40/40 suites passed**. An initial core suite run encountered
  an engine ObjectDB shutdown error after all 64,133 assertions passed; the focused
  retry and subsequent complete aggregate passed.
- Guardian integration: **110 checks, 0 failures**. Covers actual Main registration,
  blade window/deduplication, sidestep, dash immunity, Hit/Death interruptions,
  frost/shock/burn, chase/knockback, XP/loot delivery, stable-ID swap removal,
  12 repeated capped spawn/death cycles, deferred cleanup, scene re-entry and return
  to the unchanged normal title.
- Headless Main encounter, 30 s: **3 guardian kills**, **2 blade contacts / 24 damage**,
  all five states observed, repeated new IDs, hero survived.
- Rendered Main encounter, 30 s: **3 guardian kills**, **4 blade contacts / 48 damage**,
  all five states observed, hero survived. Recorded the unmodified
  `Main/CameraRig/Camera3D` at 1280x720, 60 fps. Renderer/input timing can alter the
  exact outcome; the test checks the same behavioural contract in either mode.
- Normal Classic smoke, 420-second fixed-fps bot duration: passed; 11,163 kills,
  38 upgrades, hero survived. The in-game clock can be slowed by normal hitstop.
- No final gameplay script/parse/shader errors. Godot sometimes reports resources
  still in use at shutdown; this also occurs in the unchanged Classic smoke and
  is an existing diagnostic filtered by the repository's runner.

The review capture runs actual normal weapons and inputs. It does not inject
hits, rewards, animation state changes or a replacement camera. Its script is
`tools/guardian_encounter_smoke.gd`; an optional second argument writes a JSON
summary and, with a real display, game-camera screenshots. `--write-movie` can
record the same run. Software llvmpipe rendering here is not a target-hardware
performance benchmark.

## Remaining limits

- Opt-in encounter only. No default wave, campaign encounter, save format, release
  workflow or production deployment change. Feature-branch pushes do not trigger
  this repository's default-branch release workflow.
- No full campaign/late-game guardian balancing or target-hardware stress test.
- Flat-ground animation contact correction only; no slope/stair terrain IK or
  ragdoll. World movement uses existing circle obstacles; sword/world-prop
  occlusion is not a separate physical-weapon simulation.
- Souls/rewards register normally; a raised guardian currently uses the existing
  procedural brawler ally representation, not another skeletal guardian.
- Two-handed assets and the alternate release-policy candidate remain in the
  preparation package; they are not wired into this one-handed encounter.
- No native Mac/Windows export or packaging checks in this cloud pass.
