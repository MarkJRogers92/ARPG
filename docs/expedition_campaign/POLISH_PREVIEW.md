# Last Lantern expedition polish preview

Branch: `preview/last-lantern-expedition-polish`, based on Claude's merged town at `6768024`. Local preview only; no merge, push, release or installed-app replacement.

## Changes

- Wider town camera framing keeps all seven stations visible at 1280×720 while retaining Claude's town.
- Soft generated gravel footsteps, station/departure cues, town music, and a quiet return cue use the existing Music/SFX buses and settings.
- Music fade ownership cancels superseded tweens. Two rapid departure/return cycles exposed and now cover an audible town-layer fade race.
- First-depth Graveyard routes (`0:1:*`) have an open cemetery approach, stone causeway, layered gate piers, moss and a clearance-checked memorial. This is decorative scenery; it does not introduce combat collision or alter the existing world obstacle rules.
- A brief nonblocking arrival card names the real realm, contract and objective. Existing objective warnings, result panels and reward handling are reused.
- Three small foreground votives illuminate from the existing cleared-node list. No new progression or save fields.

## Play the local preview

Use the task's `outputs/Play Soulbound Preview.command`. It launches this isolated worktree with a local, untracked `override.cfg`. The custom profile is `Godot/app_userdata/Soulbound_Preview_LastLantern_20261008` under macOS Application Support. Existing player saves were copied once; preview progress stays separate.

Choose New Campaign for the first Graveyard approach, or Continue Campaign to inspect the copied checkpoint. Walk with the configured movement controls; use E (or your rebound interaction key) beside each station; Escape closes a service panel. Choose a route, resolve any road event, and depart. Return normally through the mission outcome, then acknowledge the result to walk the town again. The stock game and its profile remain unchanged.

The local override is deliberately excluded from the commit. Checking this branch out elsewhere does not itself isolate saves; use a separate profile before testing.

## Evidence (Godot 4.7.2)

- Forced-walk town test: real interaction input across all seven stations; movement freezes under overlays; event/result Escape behavior; progress lights.
- First-expedition test: real controller departure and Main mount, first-route scenery, arrival card and objective HUD.
- Sound lifecycle: two real Shell departure/return cycles, all town layers fade out during combat, same-realm ambient music resumes. Returns use retreat-result fixtures.
- Existing UI behavior passed; campaign lifecycle 145 checks passed; campaign combat 66 checks passed.
- Parent-run real Hunt: first node `0:1:1`, 300 seconds simulated combat, 700 kills, success and valid reward settlement. Automated full-profile Necromancer fixture; not a fresh-character balance or human enjoyment result. This ran before the final audio tween-only correction; the targeted audio test covers that correction.
- Parent inspected actual 1280×720 town milestone, Graveyard arrival and result-panel renders. They are fixtures, not human playthrough evidence. Final import and diff whitespace checks passed.
- Independent native Sol review found no blocking state/audio issue and accepted the fade correction. Review itself did not run tests.

Evidence logs/screenshots are in the task's `work/polish-evidence/`. Successful harness runs still report shutdown ObjectDB/resource warnings: first-expedition and audio tests 14/7; lifecycle 20/7; Hunt 49/18. Their root cause was not resolved here. Completed final logs contain no script errors. Earlier mis-invoked headless capture failures are kept separately and are not passing evidence.

Original `project.godot` and six primary/backup save fingerprints matched the starting checkpoint. Broader combat balance, controller glyph changes, new residents and structural town restoration remain future work after player review.

## Reproduce focused checks

From an isolated profile checkout:

```sh
godot --headless --path . --script tools/campaign_walk_town_test.gd
godot --headless --path . --script tools/campaign_first_expedition_test.gd
godot --headless --path . --script tools/campaign_sound_lifecycle_test.gd
godot --headless --path . --script tools/campaign_ui_test.gd -- --screen=behavior
godot --headless --path . --script tools/campaign_lifecycle_test.gd
godot --headless --path . --script tools/campaign_combat_tests.gd
```

Capture options require a windowed renderer, never `--headless`.
