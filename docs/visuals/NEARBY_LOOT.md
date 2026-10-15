# Nearby loot: inspect before making room

Local candidate `codex/nearby-loot-choice`, based on default commit
`f33c220b6e663bb0b9b28c90b9359ec202918695`. The separate, completed field-forge
candidate is preserved unchanged; this patch does not include it.

## What changes

The Equipment screen now has **Backpack** and **Nearby** tabs. Nearby shows only
items inside the existing automatic pickup radius. Select a drop to see its
actual build-impact and rolled-stat comparison before deciding whether to make
space. The full-backpack notice points to this view.

**Collect** picks exactly the selected item while combat remains paused. Normal
pickup rules still apply: an empty slot equips immediately; otherwise the item
enters the backpack. With no room, the button is disabled and explains what to
do. After collection the selection clears, so a repeated click cannot silently
turn into Equip. Equipping from the backpack remains a separate action that
preserves the original item.

Nearby items cannot be discarded through this view. Classic's existing explicit
carried-item Discard action and Campaign's no-discard protection remain. No
capacity, drop rate, rarity, automatic pickup order, currency or save-format
changes. The list is bounded by the existing forty-ground-drop cap and sorted
by rarity, distance and stable identity. This ordering is not an upgrade claim.
Work runs only when the paused inventory opens/refreshes or selection changes.

## Ownership and persistence

Collection revalidates range, capacity and live drop ownership. The manager
removes the ground record before emitting inventory signals. Stale clicks,
trimmed/deleted drops and re-entrant Collect/Equip/Discard/Quick-equip calls cannot
duplicate or delete the collected item. Current items are never replaced just
because a ground item is previewed.

Collected gear uses the existing inventory save/restore path. Uncollected ground
loot remains transient and is **not saved with a Classic run**, as before; the
Nearby tab explicitly states this. Campaign copy IDs still use Main's normal
pickup callback and new field loot is kept only on a successful return. This
feature does not add ground-loot persistence or change failure settlement.

## Evidence

- Final aggregate: **51/51 suites passed**.
- Focused: **71 headless assertions**; **75 rendered assertions** at physical
  1024×576, 1280×720 and 1920×1080. Re-entry guards and long-name collection receipts are included in the final
  rendered flows and aggregate rerun.
- Includes full-pack compare/free-space/collect/explicit-equip, default empty-slot
  pickup, no blind auto-equip on repeated input, stale/deleted/out-of-range/dead
  selection, Campaign discard protection, a capped forty-drop pile with long
  names and keyboard scrolling, RNG/ID/order preservation, and disk save/resume.
- 420-second frame-budget smoke passed: hero alive, **10,889 kills, 37 upgrade
  choices**, gameplay clock 381.0 seconds (menus and slow motion consume frames).
  No script/parse errors; existing ObjectDB/resource shutdown diagnostics remain.
- The 13.77-second Main video uses a controlled starting inventory and Legendary
  drop. Normal input opens the screen, compares, discards one selected carried
  item, collects, equips separately, and resumes movement/combat. No injected
  enemy damage or invulnerability; one natural kill occurs.
- Before/after images use the same seeded full inventory, ground item and camera.
  They are controlled gameplay fixtures, not a natural-drop balance study.
- The movie uses Mesa llvmpipe and 413 frames at an intended 30 FPS. Software
  capture throughput is not a native hardware performance result.

Native exported builds, physical gamepad hardware and a full human playthrough
are unrun. No assets, dependencies, paid generation or credits were added.
The original candidate was validated locally; combined integration and release
verification are recorded in `FORGE_NEARBY_INTEGRATION.md`.

## Reproduce

```
GODOT=/path/to/godot bash tools/run_tests.sh
"$GODOT" --headless --path . --fixed-fps 60 -s tools/smoke_test.gd -- 420
"$GODOT" --path . --fixed-fps 60 -s tools/nearby_loot_test.gd -- --small
"$GODOT" --path . --fixed-fps 60 -s tools/nearby_loot_test.gd -- --large
"$GODOT" --path . --fixed-fps 30 -s tools/nearby_loot_review.gd
```
