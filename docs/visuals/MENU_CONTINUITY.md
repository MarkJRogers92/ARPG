# Menu continuity and safer exits

A bounded follow-on to [run UI polish](RUN_UI_POLISH.md), focused on level-up
choices, Pause and end-run return controls. The title and campaign town retain
their existing composition; their real scene transitions were exercised.

## Changes

- Upgrade cards share the RunUi palette, restrained border accents, smaller
  existing icons and left-aligned descriptions. Existing affected-ability
  numbers remain intact. Content determines minimum card height, with the
  existing scroll viewport handling overflow. Cards no longer bounce or enlarge
  under the cursor; focus uses a stable border. Reroll is keyboard-focusable.
- A generation guard rejects stale cards and deferred focus after offers are
  replaced. A selected card cannot spend the same choice twice. Banish counts,
  exclusions, rank grants and all upgrade data remain unchanged.
- Pause puts Resume, Save & quit and Abandon/Retreat above the settings. The
  save/resume limitation remains visible. Build Guide and Controls share a
  compact navigation row. Returning from Controls restores focus; rebuilding
  key bindings removes old rows before adding replacements.
- The old Abandon action was immediate. Moving it up warranted a protection:
  Abandon and campaign Retreat now open a cancel-focused confirmation describing
  the existing loss. Escape returns to Pause; Tab remains within the two choices.
  Cancellation preserves the live run. Stale and duplicate confirms cannot
  trigger an exit. Accepted actions still call the existing exit/retreat path.
- End screens use the shared panel and smaller type; their return buttons remain
  outside the report scroll. Routine combat notices no longer obscure the end
  screen. Important save failures remain visible.

No economy, balance, save schema, campaign reward/route rule,
controller mapping, paid asset or font dependency was introduced. Existing
classic/campaign save meanings and settings values are unchanged.

## Validation

Godot 4.6 stable, Compatibility renderer, isolated cloud Linux profiles.

- Fresh source archive/import plus final candidate files: **48/48 aggregate suites**.
- New `tools/menu_continuity_test.gd`: **109 headless checks, 0 failures**.
- Rendered regression: **117 checks, 0 failures**, with physical windows
  1024×576, 1280×720 and 1920×1080 under the existing 1280×720 logical stretch.
- Covered primary actions without scrolling, Resume focus, confirmation cancel
  and accepted Classic abandon, focus trapping, Guide/Controls back navigation,
  every regular upgrade's real description and affected text, stale offers,
  duplicate clicks, and keyboard rank selection.
- The flow starts at the actual title, selects Classic through keyboard input,
  opens/cancels Pause and its abandon confirmation, grants fixture XP through
  `Player.add_xp`, chooses one real rank, spawns a real chest and settles its
  guards through the unchanged reward path, triggers the real end-run screen
  through player damage, returns to the title, then opens a fresh campaign town.
  Chest payment is asserted once after two update calls.
- The isolated confirmation also checks campaign Retreat wording and one exit
  signal after duplicate confirmation. Existing campaign lifecycle, resume,
  gear/build and UI suites are included in the aggregate.

The 420-second frame-budget Classic smoke passed with **11,303 kills and 32
upgrades**, hero alive. It preceded the final end-notice visibility-only fix;
the affected focused/rendered checks and full aggregate were rerun afterward.

The short video (13.05 seconds, 783 frames at 60 fps) is a **controlled UI interaction fixture**, not a natural combat
playthrough or balance claim. XP, guard-defeating damage and fatal player damage
are injected to reach those transitions quickly; Main combat progression is
held while inspecting menus. The 0:00 end time is therefore expected. Classic
returns to the title, from which New Campaign enters the hub; it does not newly
return directly to a campaign town.

## Reproduce

```sh
export GODOT=/path/to/Godot_v4.6-stable_linux.x86_64
bash tools/run_tests.sh -g "$GODOT"
"$GODOT" --headless --path . -s tools/menu_continuity_test.gd
"$GODOT" --path . --fixed-fps 60 -s tools/menu_continuity_test.gd \
  -- --output=/absolute/screenshots
"$GODOT" --path . --write-movie /absolute/menu-flow.avi \
  -s tools/menu_continuity_test.gd -- --movie --output=/absolute/screenshots
"$GODOT" --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420
```

Use disposable profiles. The test redirects and cleans its own uniquely named
save slots. No player files, private profiles or raw logs are deliverables.

## Limits

Rendered evidence uses Mesa llvmpipe. Its capture speed is not a native-GPU
performance benchmark. Physical gamepad hardware, native platform exports,
ultrawide layouts and broad human usability testing remain unrun. Existing
resource/ObjectDB shutdown warnings may occur; script/parse errors are checked
separately. These are review-branch changes, not a merge or release.
