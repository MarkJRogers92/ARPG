# Crowded combat text

Developed from `cb00ee8038a059a3d64fcf93554e6b2df35fa936`.
The actual Main-camera stress scene exposed overlapping damage numbers across
enemy bodies and warning edges. This pass changes only the existing floating
text renderer, not enemies, attacks, collision, damage, rewards or save data.

## Presentation policy

- The existing pool still contains 48 reusable labels. At most 16 numeric hits
  plus four reaction/status words are displayed concurrently. Calm lowers the
  numeric limit to ten and removes the size pop, including after a live toggle.
- Nearby hits use a 1.5 m cosmetic spacing region. A critical hit can replace
  an ordinary hit; a reaction/status word has priority over either. Rapid
  repeated numbers retain a minimum 0.16-second reading window. Expiry remains
  0.8 seconds. These are presentation distances/times, not gameplay hitboxes.
- Ordinary damage retains the old every-fifth-hit sampling. Additional
  low-priority or overlapping cosmetic labels can now be omitted. Damage and
  telemetry still record every actual hit. A displayed number is the unchanged
  rounded value of one hit, never an average or accumulated total.
- Critical/reaction emphasis is smaller and steadier. Normal/critical font
  sizes are 30/46, versus the prior 36/64. Scale emphasis is at most 1.18 instead
  of 1.6, and exactly 1.0 in Calm. Reactions use 44 rather than 56.
- Suppressed numeric labels still consume the same three cosmetic random draws
  as the old renderer, so suppression does not shift subsequent gameplay rolls.
  The existing Damage numbers setting still bypasses new text; already-active
  labels expire normally within 0.8 seconds.

No new particles, models, text aggregation, source attribution heuristics,
screen shake or paid assets were introduced. Veteran names and threat geometry
are unchanged. World-space spacing reduces congestion but is not a guarantee
that every label's screen rectangle is disjoint.

## Validation

Godot 4.6 stable, Compatibility renderer, isolated cloud Linux profiles:

- Fresh source archive/import with byte-matched final files: **50/50 aggregate
  suites passed**; `git diff --check` passed.
- New `tools/combat_text_test.gd`: **105 headless checks, zero failures**;
  rendered variant **108 checks, zero failures**, including Normal, Calm and
  Numbers-off captures in the actual Main camera.
- Tests cover exact rounded values; crit/reaction priority; rapid repeated hits;
  numeric/reaction limits; existing sampling; node reuse; expiration; a tiny
  one-label pool; unchanged RNG consumption; three real Pause settings cycles;
  unchanged Main player stats; and identical enemy damage and complete telemetry
  from 80 real `Elements.hit` calls in each visibility mode.
- Existing combat readability/parity, combat ledger, cues, campaign and save
  suites pass in the aggregate. No production source outside the floating-text
  renderer changes.
- Before and after crowded Main simulations both completed 420 fixed-step
  frames, with **784–829 enemies**, **40 allies**, **90 hostile shots** at peak,
  two simultaneous hazard warnings and the invulnerable fixture hero alive.
  Actual movement, attacks, statuses and hazards continue; enemies and allies
  are made unusually durable for repeatable density, and SFX calls are disabled
  to avoid wall-time-dependent random draws. This is not a human balance trial.
- Pre-merge integrated recheck: **50/50 suites** and the **420-second frame-budget
  Classic smoke** passed (Battlemage alive, **13,487 kills, 39 upgrade choices**).
  The smoke completed at 417.4 seconds on its gameplay clock because level-up
  pauses consume some fixture frames. No script/parse failures were reported;
  ObjectDB and 20-resource shutdown diagnostics remain.

The before/after images use matching frame 130, seed, camera and simulation
setup. The separate short 60 fps movie presents the same controlled encounter
at simulation speed; its recording wall time is much longer on software graphics.

## Performance proxies

On cloud Mesa llvmpipe, the matched non-movie crowded runs measured median
frame intervals of **180.492 ms before / 170.109 ms after**, and p95
**215.406 / 206.479 ms** (300 samples each, screenshot readbacks excluded).
These single-run figures include the entire game and shared-machine variation;
they do not establish a native GPU speedup or a playable hardware frame rate.

A headless label-only stress loop (80 incoming hits per frame, ten 60-frame
sample rounds after warmup) measured median CPU wall time of **0.116 ms before /
0.250 ms after** per frame; p95 **0.205 / 0.448 ms**. The priority scan therefore
has a small measured CPU cost, while visible labels in that loop fall from
48 to 16. Both versions retained 48 pooled nodes and produced the identical
next random value. No new per-hit nodes or unbounded history are allocated.

## Reproduce and limits

```sh
export GODOT=/path/to/Godot_v4.6-stable_linux.x86_64
bash tools/run_tests.sh -g "$GODOT"
"$GODOT" --headless --path . -s tools/combat_text_test.gd
"$GODOT" --path . --fixed-fps 60 -s tools/combat_text_test.gd \
  -- --output=/absolute/settings-captures
"$GODOT" --path . --fixed-fps 60 -s tools/combat_readability_qa.gd \
  -- graveyard /absolute/crowd-captures crowd battlemage
```

Use disposable profiles. The settings captures inject controlled label values
with Main combat held; the separate crowd run exercises live Main simulation.
Physical controller hardware, native-GPU profiling and other biome crowd
captures were not run for this presentation pass. Existing ObjectDB/resource
shutdown diagnostics remain; final tests contain no script/parse failures.
Native exported builds require separate platform verification; successful CI
exports alone do not establish that the builds have been played on each platform.
