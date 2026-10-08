# Campaign world and feedback preview

Branch: `preview/campaign-world-and-feedback`, based on `b9c0c2f` (approved PR #32). This follow-up is local and unmerged.

## Changes

- First-depth Graveyard expeditions reuse the established gate and add a processional path, seeded roofless chapel, and memorial courts around actual objectives. Placement checks the player's initialized scenery region, existing obstacles and objective sites. Dressing adds no combat collisions.
- Preparation names the actual destination. A crossing sound, compact arrival card and distinct success/withdrawal/failure return cards mark the journey. Return text does not claim rewards were saved before controller settlement.
- Campaign combat displays a readable badge for the nearest on-screen marker. Labels stay within the viewport. Elite defeat, final seal closure and cache claim give specific acknowledgements. Replaced title animations are cancelled; calm-mode campaign cards remain still. Terminal return clears obsolete objective guidance.
- Last Lantern gains a first-return memorial, Lich trophy after Graveyard, Frost trophy after Frozen Wastes, and a completion arch/garden. The Ferryman's short line changes with existing campaign milestones. Frozen-town lighting is softened. Existing save fields drive everything; no save schema, balance or economy changes.

## Play

Use the task output **Play Soulbound Next Preview.command**. It launches the isolated checkout at 1280×720, with a one-time copy of the original player profile. Preview progress stays in `Godot/app_userdata/Soulbound_NextPreview_20261008` under macOS Application Support. Choose New Campaign to see the first Graveyard branch, or Continue for the copied checkpoint. Town additions appear as milestones are earned.

The untracked `override.cfg` is intentionally excluded from Git. Checking this branch out elsewhere does not isolate saves by itself. Original profile and project settings fingerprints matched the protected starting snapshot after verification.

## Verification

Godot 4.7.2 integrated checks passed: authored-world progression, seven-station walk town, first expedition, repeated departure/return audio, UI behavior, combat (70), guidance (27), lifecycle (150, zero failures), and a 60-second Classic smoke (137 kills, one upgrade, survived). Placement coverage disables Main's normal first-frame decor initialization so the deferred Shell test proves the director initializes the correct region itself. Elite signal-first coverage supplies a live player and wave before polling.

Independent native Sol actual-diff review caught and confirmed corrections for guardian ordering, placement initialization, elite signal acknowledgement, superseded HUD tweens and badge bounds. Parent reviewed integration, final test fixes and 1280×720 renders. Busy-combat, return-card and milestone images are controlled fixtures, not a human playthrough or balance claim. The first Graveyard composition is deliberately scoped; later-realm environment passes remain future work.

All targeted processes exited successfully without script errors. Shutdown cleanup diagnostics remain: integrated first-expedition/audio 14 ObjectDB objects / 7 resources, world 22/8, lifecycle 32/10, Classic smoke 45/15. Do not describe the run as warning-free. The verbose integrated lifecycle run identified all 32 retained objects as audio stream/playback types, with no Node/Mesh instances in its leak list; the underlying cause and any player-visible impact remain unresolved. The windowed field capture completed with 12/6 shutdown diagnostics. See task `work/next-pass-evidence/integrated/` for logs. No full campaign balance matrix was repeated.

## Focused reproduction

From a checkout with isolated saves:

```sh
godot --headless --path . --script tools/campaign_world_progression_test.gd
godot --headless --path . --script tools/campaign_combat_tests.gd
godot --headless --path . --script tools/campaign_guidance_test.gd
godot --headless --path . --script tools/campaign_lifecycle_test.gd
godot --headless --path . --script tools/campaign_ui_test.gd -- --screen=behavior
```

Rendered captures require a windowed renderer. Nothing from this follow-up has been pushed, merged, or released.
