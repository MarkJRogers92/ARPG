# Run UI polish

## Scope

Presentation pass over the run HUD, Equipment, cursed-chest choices, shrine
guidance and notifications. Shared styling lives in `scripts/visual/run_ui.gd`:
charcoal panels, parchment text, worn-bronze borders and muted teal objectives.
It reuses the existing Godot font and existing item/model assets. No new asset
license, purchase, generation or Meshy credits were needed.

- **Chest choices:** two compact cards separate the original Hunt from optional
  Sealbound. The cards retain champion counts, legendary reward, 5 base shards,
  up to 10 total with the 5-shard bonus, radius, charge time and deadline.
  Shared rules retain decay, timeout protection of the base reward, and the
  Save & Quit limitation. The original Hunt has initial focus; the optional ritual requires selecting its own action.
- **Equipment:** compact item header, restrained rarity accent and a three-column
  NOW / AFTER comparison. Health-cap loss and power changes come first; ordinary
  comparisons show several actual stat rows before scrolling. Item rolls remain
  available in their existing tab. Long names cannot push actions offscreen.
- **HUD:** framed vitals and quieter objectives/counters. Shrine world labels
  use concise names/effects; detailed Warding terms are retained in a brief
  complete notice. Accepted rituals do not retain the inspect prompt.
- **Notices:** at most three, with short copy, restrained border accents and
  full hover detail for unusually long messages. Routine notices stay 4.5 seconds
  before fading; important save failures stay 7 seconds and cannot be evicted
  by ordinary loot notices. Timers stop during pause. Only important notices
  remain visible above the pause screen. Reward reveals are compact side cards,
  with existing Enter dismissal and menu-input protection.
- **Input/layout:** explicit focus neighbors for choice cards, generation-safe
  deferred focus and stale-action guards. Overflow scrolls with focus instead
  of moving actions outside the modal.

No encounter arithmetic, balance, equip algorithm, reward grant path, save
schema or campaign tables changed. Save version 1 remains unchanged. Unfinished
chests, guardians, ritual progress and uncollected drops remain transient on
Save & Quit; the choice screen still says so.

## Verification

Godot 4.6 stable, Compatibility renderer. Checked on the cloud Linux workspace.

- Fresh source archive/import plus candidate files: **47/47 aggregate suites**.
  A final dynamic shrine-duration and singular/plural copy adjustment was
  followed by another **2/2 affected suites** (shrines and Sealbound).
- New focused UI regression: **64 headless checks, 0 failures**.
- Rendered UI regression: **70 checks, 0 failures**, including physical windows
  **1024×576, 1280×720 and 1920×1080**. The existing stretch configuration keeps
  the logical canvas at 1280×720; this does not claim every arbitrary aspect ratio.
- Focus, keyboard choice navigation, original-challenge default focus and safe leaving, rapid close/reopen,
  stale actions, long labels/copy, scrolling, pause stacking and reward Enter
  handling were exercised. Twenty routine notices could not displace an
  important save failure; the important notice remained above pause.
- Gear previews/cancellation leave stats and inventory unchanged. The existing
  gear-impact (317 checks) and Sealbound (63 checks) suites remain in the passing
  aggregate; only presentation assertions/accessors changed.
- Required 420-second frame-budget smoke bot: **passed**, 417.5 simulated combat seconds,
  **11,382 kills, 33 upgrades**, hero alive at 138.6/139 HP.
- Actual Main UI/combat recording: inventory open, item selection, Build impact /
  Item rolls navigation and cancellation, then chest inspection/choice, movement
  out of and back into the seal, normal combat and reward reveal.
  **7 champions, one base grant, one bonus grant, decay observed, hero alive**;
  25.439 simulated combat seconds, 47 kills, no invulnerability or injected
  damage. The controlled fixture used eight existing upgrade cards (level 9)
  and a Cap/Circlet comparison pair; inspection did not swap equipment.
- Encoded video: **33.633 seconds / 2,018 frames at 60 fps**, including the UI
  inspection prelude. The visible game clock advances normally. Rendering used
  Mesa llvmpipe software capture and took about 3m11s. Its render speed is a
  capture limitation, not a native-hardware performance benchmark.
- Core text palette against the panel background measured at least **8.37:1**
  contrast (primary text 14.20:1). This is a limited color check, not a full
  accessibility audit.

The rendered UI harness and long smoke still emit existing ObjectDB/resource
shutdown diagnostics (6 and 17 resources respectively). No script, parse or
shader errors were observed. Headless focused UI exits cleanly.

## Reproduce

```sh
GODOT=/path/to/Godot_v4.6-stable_linux.x86_64 bash tools/run_tests.sh
"$GODOT" --headless --path . -s tools/run_ui_polish_test.gd
"$GODOT" --path . -s tools/run_ui_polish_test.gd -- --capture-dir=/absolute/output
"$GODOT" --path . --write-movie /absolute/output/ui.avi \
  -s tools/run_ui_polish_smoke.gd -- --output=/absolute/output
"$GODOT" --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420
```

Set GODOT in the shell before running the direct commands. Use an isolated
test profile for fixtures. The video smoke intentionally authors a reproducible
early encounter; it is not an unmodified fresh-start player playthrough.

## Review evidence and remaining limits

Matched before/after images cover chest choices, Equipment and HUD, using the
same seed, camera, item pair and actual accepted-ritual state. Their clock is
deliberately frozen for matching; the interaction video is the running flow.
Evidence is delivered separately from source; no test profiles or private logs
are bundled.

Physical gamepad hardware, native Windows/macOS exports, broad human usability
testing, ultrawide/mobile layouts and native-GPU performance were not tested.
This is a review-branch presentation candidate; it has not been merged or
released.
