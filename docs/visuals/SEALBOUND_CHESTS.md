# Sealbound: an optional chest encounter

Random Classic cursed chests now invite an explicit choice. Walking onto the
chest does not start anything. Press the current Interact binding within 3 m to
inspect; combat and event clocks pause while choosing. Hunt is focused first,
and Leave/Escape costs nothing. The player can walk away and inspect again until
the unused chest expires after the existing 90 seconds.

- **Hunt:** the original 5/6/7 champions by realm, an Army-themed Legendary
  and 5 Soul Shards after all guards die. No new stat modifiers or timer.
- **Sealbound:** exactly two more champions. Charge a visible **5 m radius**
  circle for **12 seconds within 35 seconds** for **5 additional shards**.
  Outside the area, progress drains at 0.5 seconds per second. The player can
  dodge or leave, then return; the deadline does not restart.
- Completing the charge secures the bonus, but it pays only once the guardians
  are defeated. If they die first, the base reward drops immediately while the
  optional ritual can still finish. Timeout never removes or replaces the base
  reward. Both outcomes are explicit in the panel and combat status text.

## Runtime boundaries

- Uses the current chest, champion types and themed reward generator. No new
  downloaded assets, models, licenses, paid generation or dependencies.
- Existing random-event cadence is unchanged; one choice chest is allowed at a
  time. No campaign reward/opportunity tables or authored chest constructors are
  switched to this route. The default constructor retains proximity activation.
- Encounter placement reserves all champions before spawning; unavailable
  capacity or blocked positions leave the offer unconsumed. A blocked five-metre
  ritual footprint disables Sealbound while leaving Hunt available. Planned
  champion positions avoid solid terrain and one another.
- Stable swarm IDs track the intended guards across row compaction. Unrelated
  enemies do not replace them. Base and bonus grants commit before callbacks;
  stale/double selections and completed-event updates cannot pay again.
- Dead players cannot choose, charge or receive post-death event completion.
  Paused menus stop the timer. Whole-scene cleanup removes the transient nodes.
- Main gives existing landmark/Ferryman/rift interactions priority. The new
  interaction is checked after the damage/death frame, preventing an inspection
  from opening on a dead player. The existing choice-panel layout is reused
  with separate heading/flavor fields; the Ferryman's defaults stay unchanged.
- One steady green outline, one progress disc and one depth-tested label are
  added only during an accepted ritual. The outline compensates for the existing
  glow shader's UV radius so its center follows the actual five-metre boundary.
  No camera shake, screen flash, input binding, permanent stat effect or save
  schema was added. Color is accompanied by text, seconds and champion counts.

## Save compatibility and balance limits

Version-1 saves remain compatible. As with existing random chests, the encounter,
guardians, optional charge and uncollected ground loot are not serialized. The
choice panel explicitly warns that Save & Quit ends unfinished rituals. Already
collected gear and banked run shards continue through the existing save path.
There is no replay-on-resume grant. This is **not** new persistent-encounter support.

The optional +5-shard reward and two extra champions are deliberate new balance
choices, not a claim of equivalent difficulty. Ordinary Hunt rewards and combat
stats remain unchanged. Automated checks do not replace human balance testing.

## Verification

Godot 4.6 stable, Linux Compatibility / Mesa llvmpipe, isolated test saves.

- Focused Main/UI tests cover explicit opt-in, leave/cancel, inspection pause,
  repeated/stale input, range, standard rewards, charge/decay/reentry, early kills,
  timeout preserving the base reward, stable IDs/compaction, all realm counts,
  full capacity, obstructed circle, unused expiry, death and fresh-scene resume.
- Rendered 1280×720 inspection and real Main combat show the offer, circle,
  countdown, return cue and outcome. Keyboard cancel is exercised; physical
  gamepad hardware remains unrun.
- `sealbound_chest_smoke.gd` uses a controlled early chest location and a level-9
  build from eight existing upgrade cards. It then uses actual movement,
  weapons, enemy AI, damage, drops and collection. No invulnerability or injected
  enemy damage. It deliberately leaves the circle, observes decay, returns and
  earns exactly one base reward plus one bonus. This is a development fixture,
  not a naturally leveled full playthrough or difficulty benchmark.

Final validation:

- **46/46 aggregate suites passed**, including **63 focused assertions** for
  this feature; **65 checks passed** in the rendered variant with two captures.
- Fresh source-only import: no script/parse/shader errors. Chest, resume,
  campaign-loadout and crossroads-shrine suites passed (4/4). The complete final
  runtime/test files and UIDs match that independently imported source copy.
- Required 420-second / 25,200-frame Classic smoke passed: 11,597 kills,
  35 upgrades, hero alive. Combat time was 393.1 seconds because upgrade menus
  pause the run. No script errors; existing shutdown diagnostics reported
  ObjectDB objects and 19 resources still in use.
- Final gameplay movie: **21.6 seconds**, 1,296 encoded frames at 60 fps;
  17.42 seconds of actual combat. Seven champions, one base grant, one bonus,
  26 kills, hero alive at 131.4 HP; leaving the circle and decay both observed.
  Base +5 and bonus +5 means **10 event shards in total**, separate from other
  ordinary combat drops. This fixture has no invulnerability or injected damage.
- The cloud software-rendered recording took 134 seconds to render. Its visible
  FPS counter and encoded 60 fps are **not native game-performance measurements**.
  The chronological movie frames and full-size offer/combat captures were
  inspected; the complete flow is available as `Sealbound_Chest_Gameplay.mp4`.

Commands: `bash tools/run_tests.sh`, and under a display,
`godot --path . --fixed-fps 60 -s tools/sealbound_chest_smoke.gd`.
Use the repository's isolated-profile workflow for test saves.

Native exports and extended human playtesting are unrun. Existing shutdown
ObjectDB/resource diagnostics can remain in unrelated harnesses; the runner's
error filters and release workflow are unchanged. Review branch only.
