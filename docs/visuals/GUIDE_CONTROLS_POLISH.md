# Build Guide and Controls polish

This presentation pass continues the shared [run UI](RUN_UI_POLISH.md) and
[menu continuity](MENU_CONTINUITY.md) styling. It changes the Guide and Controls
surfaces without changing card grants, evolution rules, rewards, saves or balance.

## Changes

- The Build Guide separates its recipe checklist from the selected evolution's
  details. The next step counts the actual remaining weapon cards and missing
  catalyst, with singular/plural wording and no request for an already-owned
  catalyst. Ready recipes retain the existing random-offer rule when more than
  one evolution qualifies. Already-evolved recipes are labeled accordingly.
- Card upgrades remain distinct from hero/equipment access. The unchanged
  `BuildGuide.affected_text` supplies every actual stat preview. Recipe rows,
  selected details and the pinned goal have a restrained hierarchy; Back stays
  outside the scroll areas. Pins remain session-only and are explicitly not saved.
- Keyboard users can move from a recipe to Pin and into the detail pane, then
  scroll long previews with the arrow keys. Stale rows/pins cannot change the
  current selection after the list is rebuilt.
- Controls groups Movement and Actions into two columns. All eleven bindings,
  Reset and Back fit the existing 720p logical canvas. Rebinding keeps focus on
  the edited action and identifies the key being captured, successful changes,
  actual key swaps and cancelled capture. Escape during capture cancels only
  that edit. The existing `Controls.rebind` and `Controls.reset` still own the
  mapping and settings behavior; arrow/controller alternatives are unchanged.
- The Pause opacity setting now says “Bolt / aura opacity”, matching the
  existing limited effect coverage. Its detailed tooltip is unchanged.

Reward quantities and help outside these surfaces were audited but not churned.
No new font, asset dependency, paid service or credit use was needed.

## Validation

Godot 4.6 stable, Compatibility renderer, isolated cloud Linux profiles:

- Fresh source archive/import plus byte-matched final candidate: **49/49 aggregate suites**.
- New `tools/guide_controls_test.gd`: **118 headless checks, zero failures**.
- The same real Main UI test with a display: **124 checks, zero failures**,
  including six successfully saved screenshots.
- Physical windows 1024×576, 1280×720 and 1920×1080 use the existing 1280×720
  logical stretch. Both columns and Back/Reset remain in bounds.
- Covered keyboard navigation and real key input; guide pin/unpin and a long
  preview; partial, single-ready, multiple-ready and evolved recipes; exact stat
  text for all compatible recipes; null/empty data; stale controls; repeated
  open/close; Escape cancellation; real binding swaps, dynamic key tags and
  reset; unchanged player HP, modifiers and upgrade levels; unchanged alternative
  arrow/controller mappings.
- Existing build-guide, report/UI, menu and campaign suites also pass in the
  aggregate. `git diff --check` passes.

The matched images use the prior `34364dc` source and the new source with the
same Main scene seed, camera and four Sharper Bolts cards. The Controls pair
shows actual Dash key capture in both versions. These are controlled UI
fixtures with combat held during inspection, not a natural playthrough.

## Reproduce

```sh
export GODOT=/path/to/Godot_v4.6-stable_linux.x86_64
bash tools/run_tests.sh -g "$GODOT"
"$GODOT" --headless --path . -s tools/guide_controls_test.gd
"$GODOT" --path . --fixed-fps 60 -s tools/guide_controls_test.gd \
  -- --output=/absolute/screenshots
```

Use disposable profiles. The focused test disables profile writes and resets
its temporary bindings. The three Guide screenshots deliberately extend the
details text to prove scrolling; they are stress-test images, not the polished
matched comparison.

## Limits

No native exports, physical gamepad hardware, translations or ultrawide displays
were tested. The seven-minute combat smoke was not repeated for this UI/help
pass. Rendered tests use Mesa llvmpipe, so capture speed is not a game performance
claim. Existing resource/ObjectDB shutdown warnings remain; final logs contain
no script or parse errors. Changes are published to the review branch only.
