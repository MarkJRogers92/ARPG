# One-handed guardian: Ogre Warlord-sized opt-in mid-boss

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
- One mid-boss starts nearby. G summons it only when none is alive; the encounter
  admits at most **one living mid-boss**.
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

- The reusable swarm has a hard ceiling of **3 live skeletal actors + 3 retiring
  death actors** for lifecycle stress checks. The playable encounter admits **one
  living mid-boss**, rather than a pack. Deferred deletions
  are cleared on the following scene-tree frame. The large MultiMesh horde path
  is not rewritten. The legacy body is hidden; the existing batched shadow remains.
- Chase moves the canonical row through the existing scenery-circle slide solver.
  Frost slows movement and the Walk playback rate. Walk timing accounts for the
  enlarged stride. Attack/Hit hold the actor root;
  facing locks for the cut so a sidestep can evade it.
- The reviewed skeletal motion is unchanged. Runtime stretches only its early
  wind-up: **0.65 s** warning, active **0.65–0.95 s**, recovery to **1.45 s**, then
  a **0.90 s** pause (2.35 s minimum cadence). The local clip window is 0.40–0.70 s;
  its lowered final tip now participates in the cut. The fast cut is not slowed.
- At this height, aiming the body's centre directly at the hero swings above them.
  Commitment instead aims the late diagonal blade toward the target with a fixed
  -20-degree yaw offset, eased over the first 0.18 s. Facing then stays locked;
  moving after commitment does not steer the cut. The amber ground fan is a
  conservative directional warning, not a damage area, and closes on interruption.
- Combat samples the actual evaluated `SwordGrip` bone at up to **120 Hz**. The
  compact blade runs from local Y=0.25 to Y=0.962 m. Blade samples and base/mid/tip
  sweeps are tested against the upright hero capsule (0.5 m radius, Y=0.45–1.25 m
  center line), with a 0.06 m local blade margin (0.129 m at this scale). The hilt does not deal damage.
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

The actual CPU-skinned Idle body measures **4.668999 m**, matching the existing
Ogre Warlord's mesh height **4.6689997 m** within 1 mm. Uniform scale is
`4.6689997 / 2.1674886 = 2.154106`; actor and weapon scale together. Standing feet
remain 0.022 m above the flat floor, matching the source's tiny grounding offset.
The full silhouette is narrower than the Ogre Warlord, rather than stretched wider.

Encounter tuning is **900 HP, 2.4 m/s chase, 1.2 m world collision/targeting radius,
3.0 m attack engagement, 24 sword damage, 75 XP and a 50% normal loot roll**.
The existing global loot token budget still applies. Knockback multiplier is 0.1.
These are early opt-in prototype values, not late-game campaign balance. The enemy
is additive: no Ogre Warlord identity, existing boss or campaign table is replaced.

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
godot --headless --path . --fixed-fps 60 -s tools/guardian_encounter_smoke.gd -- 45
godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420
```

Local validation uses Godot 4.6.3 / Compatibility. For this resized mid-boss:

- Guardian integration: **125 checks, 0 failures**. Includes CPU-skinned Ogre height
  match/grounding, one-mid-boss encounter admission, authoritative blade contact,
  warning duration, no radial damage at close/far positions, a side-step after
  350 ms reaction, dash immunity, Hit/Death interruptions, frost/shock/burn,
  chase/knockback, XP/loot delivery, stable-ID swap removal, 12 repeated three-actor
  diagnostic spawn/death cycles, deferred cleanup and normal-title return.
- Headless Main encounter, 45 s: **1 guardian kill, 2 distinct IDs, 1 blade contact /
  24 damage, 8 dodge attempts**, all five states observed; hero survived at 100 HP
  after normal healing/level-up. No more than one live mid-boss was admitted.
- Existing aggregate: **40/40 suites passed**. A fresh-cache reconstruction of the
  exact changed sources imported without script/parse errors and passed all
  **125 focused checks** again.
- Rendered Main encounter, 45 s: **1 guardian kill, 2 distinct IDs, 1 blade contact /
  24 damage, 9 dodge attempts**, all five states observed; hero survived at 100 HP.
  The original Main camera captured 1280x720 at 60 fps. No new camera or injected
  damage/animation/reward events were used.
- Normal Classic smoke rerun, 420-second fixed-fps bot duration: **passed**, 12,376
  kills, 36 upgrades, hero survived. Normal hitstop reduces the in-game clock.
- Godot can report ObjectDB/resources still in use at shutdown, also seen in the
  unchanged Classic smoke. This existing diagnostic is filtered by the repository
  runner; it has not been resolved by the guardian work.

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
