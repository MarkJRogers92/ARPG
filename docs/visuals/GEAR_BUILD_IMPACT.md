# Gear decisions: exact build impact

The normal inventory now opens a **Build impact** tab for the selected item.
It previews equipping carried gear or removing worn gear. The original item-local
bonus/power comparison remains in **Item rolls**. Nothing is applied until an
actual Equip or Unequip action.

## What it explains

- Effective stats after the real slot replacement, including class modifiers,
  upgrades, other equipment, temporary buffs, integer rounding and stat caps.
- Current HP lost immediately when a lower maximum-HP cap would clamp it.
- Newly available or lost abilities and legendary powers. An ability not yet
  active is labeled **Inactive**, rather than suggesting its base numbers were
  already being dealt in combat. Reaper's unused Magic Bolt rows are hidden.
- Army damage changes derived through the existing Soul Link calculation.
- Whether owned Frost Relay, Ashen Escort or Blade Wake cards would gain or
  lose their stat prerequisites. This does not promise their in-combat trigger.
- Armor's actual reduction percentage; cooldowns in seconds with lower values
  treated as a gain. These are effective stats, not a DPS prediction.

The preview clones stats and the equipped-item map, then uses Inventory's real
slot synchronization. Item records are read-only, with no Item reconstruction,
new item IDs, RNG use, inventory signals, live HP changes, or persistence writes.
Work runs on selection/refresh while the inventory is open, not in the combat
frame loop. The existing quick-equip algorithm is unchanged and is now clearly
labeled **Quick-equip by item score**, with a tooltip explaining its limitations.

Full backpacks disable Unequip with an on-screen reason. Swapping a carried item
still works at capacity. Campaign combat's no-discard protection remains. Tab
navigation and focused text scrolling work with the existing UI action map.

## Validation

Godot 4.6 stable, Linux Compatibility / Mesa llvmpipe. Isolated test saves.

- `gear_impact_test.gd`: 317 focused assertions, 321 in the rendered variant.
  Generated swaps cover 96 combinations across all six slots, rarities, five
  hero modifier/power sets, buffs and caps. Every preview and removal is compared
  with the actual equip/unequip result; live state, item records/IDs and signals
  are checked for preservation.
- Additional cases cover innate-power retention, capped crit, slower cooldowns,
  link prerequisites, inactive attacks and unchanged global RNG after 1,000
  previews. That batch took 338 ms in a concurrent cloud-rendered run, about
  0.34 ms per preview plus text formatting. This is not a hardware guarantee.
- Actual Main UI: ground pickup, open/pause, inspect, keyboard tab/scroll,
  cancel/reopen, real equip with exact HP cap/ability result, full-pack blocked
  removal, full-pack swap, campaign discard guard, disk save and fresh resume.
- Matched 1280×720 Before/After captures use identical controlled gear/HP and
  Main camera fixtures. They demonstrate the decision view, not a natural drop.
- `gear_impact_smoke.gd` walks to a controlled drop, inspects/equips it, then
  resumes actual Main combat. Starting gear/HP and that drop are fixtures;
  enemies receive no injected damage and the hero is not invulnerable. Real
  Chain Lightning damage and visible arcs must be observed after the swap.

- Final aggregate: **45/45 suites passed**. A fresh source-only import has no
  script/parse/shader errors; gear-impact, UI, resume and campaign-loadout suites
  also pass there (4/4).
- The required 420-second / 25,200-frame Classic smoke passed: 9,916 kills,
  31 upgrades, hero alive. Actual combat elapsed was 386 seconds because upgrade
  menus pause combat time. No script errors were recorded.
- The 20-second rendered gear-to-combat capture passes with exact equip results,
  visible Chain Lightning and 111.1 tracked lightning damage / 12 kills after
  choosing the candidate. Its 15 seconds of combat excludes paused inspection.
  This is a controlled-drop gameplay proof, not a balance benchmark or native
  frame-rate measurement.

No new art or dependencies, no paid generation, and no save-schema,
equipment-stat, drop-rate or combat-balance changes.

Native exported builds, physical gamepad hardware and human playtesting are
unrun. Existing ObjectDB/resource shutdown diagnostics may appear. Error filters
and release workflows are unchanged. This is a review-branch candidate.
