# Guardian readability and ground-material polish

Review candidate based on `61a9e4ace28695dfdac794cbb7090fd9e2754d04`.
This branch has not been merged or released.

## Changes

- **Guardian cut countdown:** a steady amber sector, dark keyline and advancing
  fill replace the flat translucent patch. The same 1.3–3.8 m, 100-degree
  conservative warning remains; evaluated sword geometry still decides hits.
  Ink vanishes on interruption/death and after the existing active window.
  Bold warnings increases stroke width and contrast. No pulse, extra light,
  particle system or camera shake was added.
- **Encounter readout:** the existing top-center boss bar shows spawn-relative
  HP and actual animation state (approaching, wind-up, cut, recovery or stagger).
  A native boss retains priority. The readout clears on despawn, death and
  game over. It exists only in the opt-in guardian encounter.
- **Readable hit feedback:** a short warm rim accent and small surface tint
  keep the dark armor/gold trim visible under repeated hits. Calm effects
  reduces this accent to one quarter. Status colors remain intact. Cosmetic
  material writes now happen once per frame, rather than each collision substep.
- **Ground shading:** existing soil, flagstone and snow noise drives shallow
  shading relief and material-specific roughness. Ground geometry, collision,
  colors and realm lighting are unchanged. There are no additional textures,
  noise loops, draw calls or purchased/generated assets.

The approved one-handed animation and both GLBs are byte-identical. Attack
windows, damage, size, movement, rewards, IDs, encounter cap, saves and campaign
placement are unchanged. The guardian remains an opt-in encounter, not a new
normal campaign spawn. The two-handed preparation candidate is untouched.

## Run and inspect

Use Godot 4.6 Compatibility. F5 runs the ordinary game with updated ground
shading. Open `scenes/pilot/guardian_encounter.tscn` and F6 for the guardian.
WASD/Space use the normal movement/dash controls. G summons only when no
living guardian exists; the encounter's existing automatic respawn remains.

Pause-menu Calm effects and Bold warnings apply live. The encounter uses its
existing isolated, non-resumable save context. It does not write campaign gains.

```sh
bash tools/run_tests.sh -g /path/to/godot
bash tools/run_tests.sh -g /path/to/godot -t 'tools/guardian_integration_test.gd tools/visual_polish_test.gd'
/path/to/godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420
/path/to/godot --path . --fixed-fps 60 -s tools/guardian_encounter_smoke.gd -- 45 /absolute/output
```

Matched static camera fixtures (not gameplay/balance tests):

```sh
/path/to/godot --path . -s tools/visual_polish_qa.gd -- /absolute/output graveyard guardian
/path/to/godot --path . -s tools/visual_polish_qa.gd -- /absolute/output graveyard guardian comfort
/path/to/godot --path . -s tools/visual_polish_qa.gd -- /absolute/output frozen terrain
```

Use an isolated profile for QA. The guardian fixture intentionally sets HP to
70%, samples the same wind-up pose and a 0.75 hit-flash signal, and freezes the
camera/time. Its initial clock is not evidence of a frozen gameplay timer.
Actual Main-loop video uses the ordinary moving camera, auto-weapons, damage,
dash, rewards, death and respawn without injected damage or pose commands.

## Validation

- Godot 4.6 stable (`89cea1439`), Linux cloud computer, Compatibility renderer.
- All **41 aggregate suites passed** (the previous 40 plus the new presentation
  suite). Core teardown handling and the runner's existing failure rules are
  unchanged.
- **125 guardian integration checks passed**, including scaled body height,
  actual sword contact, dodge, interruptions, status, rewards and cleanup.
- **47 presentation checks passed**, including monotonic countdown, active/
  recovery windows, immediate interruption hiding, live Bold/Calm settings,
  spawn-relative elite HP, native-boss priority and repeated spawn/despawn.
- Ordinary **420-second Classic bot passed**, survived, 11,562 kills and
  33 upgrade choices in this seed. This is regression evidence, not balance
  or human-play acceptance.
- A rendered **45-second actual Main encounter passed**: one guardian killed,
  two stable IDs, all five animation states, one 24-damage sword contact,
  nine dodge attempts, at most one live visual and one corpse, hero survived.
  The ordinary dawn timer advanced normally.
- Matched 1280×720 cameras inspected in Graveyard, Frozen Wastes and Ember Rift.
  No script/shader compile errors in the rendered checks.

- Fresh source-only import passed with no script/shader errors, then guardian,
  presentation and existing combat-readability suites passed again.
- Matched 600-frame crowd runs (first 120 discarded), same 1280×720 camera,
  fixed simulation step and 40 allies:
  - Graveyard, 784–831 enemies: median 168.141 → 168.619 ms (+0.28%);
    p95 200.956 → 199.568 ms (−0.69%).
  - Frozen Wastes, 776–816 enemies: median 136.771 → 138.059 ms (+0.94%);
    p95 168.469 → 172.393 ms (+2.33%).
  - Source variants had matching enemy ranges and peak projectile counts.
    These are single matched software-renderer samples, not a statistical
    performance guarantee. Ember was visually checked, not separately benchmarked.
- A 90-second before/after automated encounter with SFX calls suppressed for
  RNG isolation matched guardian kills (2), stable IDs (3), contact frame (178),
  blade damage (24), dodge attempts (16), hit-pose frames (504), total kills
  (266), levels (6), live/corpse caps and survival. Wall-clock hit-stop means
  elapsed time and regeneration are not bit-exact (about 0.016 s / 0.024 HP
  difference). No claim of full deterministic replay is made.
- An exploratory 45-second headless baseline did not reach the harness's
  kill/respawn quota; the longer isolated comparison above passed both sources.
  The ordinary rendered 45-second gameplay check did reach that quota.

## Limits and provenance

This is a review branch, not user visual acceptance or a production release.
No native Windows/macOS export launch or physical-GPU test was performed.
The cloud display is Mesa llvmpipe software rendering; timing is only a matched
regression sample, not a hardware FPS promise. The existing test harness can
report ObjectDB/resource warnings during engine shutdown; new presentation
assertions pass but this pass does not claim to fix upstream teardown behavior.

No new external art, reference upload, license acceptance or paid generation.
All art is reused from the repository with its existing provenance; procedural
shader/code edits introduce no third-party asset dependency. **Meshy spend: 0
of the authorized 200 additional credits.**
