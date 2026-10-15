# Crossroads shrines

A normal-play discovery upgrade on the review branch. Random Classic shrine
arrivals can now offer two distinct, visible blessings. Enter either circle and
hold it for the existing 3.5-second charge; committing grants that blessing for
30 seconds and removes both alternatives. Walking out decays partial charge,
so the player can change their mind while enemies continue attacking.

## Design and boundaries

- Uses the existing Fury, Haste, Plenty and Warding modifiers. No new damage,
  armor, economy or permanent-progression values. Choice is more agency than a
  random shrine, so human balance/playtesting is still needed.
- Each altar names its effect and duration in world space. The ordinary Main
  interaction line gives the closest choice and remaining hold time. Existing
  objective, landmark, Ferryman and rift interaction prompts keep priority.
- One shared discovery marker; at most one paired event alive. This adds at
  most one extra shrine model/light and two depth-tested labels relative to a
  single shrine. Meshes are existing cached procedural assets. No new assets,
  textures, libraries or licenses, and no paid generation.
- Both footprints must clear solid scenery and the choice circles cannot
  overlap. If none of eight orientations fits, the original single shrine is
  used. The existing event cadence and 90-second unused expiry remain.
- Campaign recovery still creates its authored single Warding shrine and its
  committed reward. The paired discovery is on the normal random-event path.
- Choices, active blessings and Warding charges remain transient across Classic
  suspend/resume, matching existing RunSave semantics. Version 1 is unchanged.
- The grant commits before emitting callbacks; stale/reentrant completion
  cannot grant the second option. Completion and expiry free both altar trees.

The in-engine reward capture exposed an existing long-toast overflow: Warding's
message extended off the left edge and covered bottom hints. Notices now wrap
inside a half-viewport-wide column (maximum 620 pixels), sit above interaction
prompts, and retain at most four visible entries. No text is truncated.

## Verification

Godot 4.6 stable, Linux Compatibility / Mesa llvmpipe, isolated test saves.

- `crossroads_shrine_test.gd`: distinct choices, non-overlapping/clear footprints,
  cap/one marker, partial charge, changing sides, exactly-once grant and cleanup,
  modifier expiry, no extra permanent/currency reward, repeated pause/death/
  expiry cases, blocked allocation, authored campaign opportunity and random
  event path, actual Main prompt, disk save and fresh-scene resume.
- Rendered checks inspect the real Main camera at 1280×720.
- `crossroads_shrine_smoke.gd`: normal-speed real movement, combat, switching
  choice, charging and grant. Only the event arrival is accelerated near spawn
  for an 11-second bounded demonstration. Normal hero stats, no invulnerability,
  no injected damage or rewards. One Warding grant; ordinary enemies keep
  fighting. This is automated play, not evidence of human enjoyment/balance.
- Final aggregate: **44/44 suites passed**. New focused checks: **42 shrine**
  and **46 combat cues**; rendered variants: **44** and **49**. Existing real-
  cursor aim test passed.
- Fresh source-only import succeeded; both new suites, existing guardian
  integration (125 checks), and Classic resume all passed. Runtime/test source
  bytes were checked against the published candidate.
- Final 420-second Classic smoke passed: hero survived, 12,084 kills and
  35 upgrade selections. This is an automated regression run, not a balance
  guarantee or comparison of player skill.
- Final normal-speed capture: 11.08 combat seconds, one Warding grant after
  switching from Haste, six ordinary kills, hero alive at full HP. No
  invulnerability. The recording encodes 670 frames at 60 fps; cloud recording
  ran slower than real time and is not a native-hardware FPS claim.

Commands:

```sh
bash tools/run_tests.sh -t 'tools/crossroads_shrine_test.gd tools/combat_cues_test.gd'
# Under a real display:
"$GODOT" --path . --fixed-fps 60 -s tools/crossroads_shrine_smoke.gd
```

No merge, release or native Windows/macOS export launch. Physical gamepad and
extended human playtesting are unrun. Existing ObjectDB/resource-at-shutdown
warnings can remain in headless tests; the runner's error filters are unchanged.
