# Field forge: keep or replace

Local review branch: `codex/field-forge-choice`, based on merged
`f33c220b6e663bb0b9b28c90b9359ec202918695` (PR #54).

## Player-facing change

Classic's Ember field forge previously charged immediately and destroyed the
worn weapon in favor of a random replacement. It now offers free inspection,
then an explicit **8 run-shard** payment for **one roll**. Choose **Keep original**
or **Take new weapon** after seeing the actual character-effective stat and power
changes. There is no guaranteed upgrade and no refund for declining a paid roll.
The existing same-rarity, player-derived item-level +3 generator is unchanged.
Campaign's town forge remains separate and unchanged.

- Leave/Escape before rolling is free. Insufficient funds still allow inspection.
- After payment, Escape keeps the original. Keep is the default focused action.
- The original remains equipped until acceptance. Taking the roll explicitly
  replaces it; neither weapon is added to the backpack. A full backpack is safe.
- Buttons invalidate their old callbacks before charging or swapping. Repeated
  input, leaving/returning and reopening cannot roll a paid forge again.
- Opening is deferred until Main's end-of-frame damage/modal arbitration.
- The optional `used_field_forges` field extends existing version-1 run snapshots.
  Existing snapshots without it load normally. Spent keys, the fee, and the chosen
  equipped weapon survive Save & Quit/resume.
- The choice pauses combat and normal Save & Quit is not accessible over it. If
  an external capture interrupts a paid undecided choice, the snapshot retains
  the original weapon and spent fee/forge. The unaccepted roll is discarded.
  This is not a new crash-autosave system. A real death signal closes the choice,
  rejects stale acceptance and releases its own pause for the death sequence.

## Validation

Godot 4.6 Compatibility, disposable profiles, no personal save files.

- Final aggregate: **51/51 suites passed**, including campaign facilities,
  lifecycle, loadout and UI, plus all existing gear-preview tests.
- Forge-specific: **48 headless assertions**, **51 rendered assertions** at each
  verified physical window size 1024×576, 1280×720 and 1920×1080.
- Covers free/paid cancel, default focus, keyboard acceptance/scroll, long text,
  stale/double input, insufficient funds, changed weapon/range, full backpack,
  actual preview/equip equivalence, modal priority, accepted and undecided disk
  save/resume, legacy/malformed save fields, and real fatal damage.
- 420-second frame-budget smoke passed: **11,602 kills, 33 upgrade choices,
  hero alive**. Its gameplay clock reached 392.6 seconds; choices and slow motion
  consume frames. No script/parse errors. Existing ObjectDB/resource shutdown
  diagnostics remain (9 resources in the forge test, 20 in the smoke run).
- Actual Main input movie: a naturally placed Ember forge at (17.29, 4.03),
  normal interaction, actual generated roll, Keep original, return to live Main.
  Starting level, shards and worn weapon are fixtures; the hero is invulnerable
  for capture. The trade-off still uses deliberate weapon values to expose
  power/stat loss. Neither is a full human playthrough or native-export test.
- No continuous per-frame effect or horde-renderer change. One panel is created
  lazily and reused. Software-rendered movie: 291 frames / 9.7 seconds at 30 FPS,
  recorded in 25 seconds; this is capture throughput, not hardware game FPS.

## Reproduce

```
GODOT=/path/to/Godot_v4.6-stable_linux.x86_64 bash tools/run_tests.sh
"$GODOT" --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420
"$GODOT" --path . --fixed-fps 60 -s tools/field_forge_test.gd -- --small
"$GODOT" --path . --fixed-fps 60 -s tools/field_forge_test.gd -- --large
"$GODOT" --path . --fixed-fps 30 -s tools/field_forge_review.gd
```

No new assets, paid services or credits. The original candidate was validated locally; combined integration and release
verification are recorded in `FORGE_NEARBY_INTEGRATION.md`.
