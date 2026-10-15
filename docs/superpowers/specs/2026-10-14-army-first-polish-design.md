# Army-first expedition polish

Approved direction: make the first resurrection memorable, strengthen attachment
to veterans, make guardian stance opportunities readable, and recognize the
army's actual contribution on return. This is an expedition polish pass, not a
new progression system. Implementation choices below are the builder's defaults.

## Behavior
- On the opening Graveyard route, a player without an existing army gets enough
  normal souls from the first ordinary slain enemy to bind one ally on pickup.
  This happens once per attempt, respects army-restricted trials, and does not
  raise an elite, bypass pickup, change capacity, or grant permanent rewards.
- The first ally actually bound from collected souls receives a non-pausing
  campaign spotlight naming its enemy type and showing the rebound stance key.
  Prepared recruits, restored armies, and deployed veterans do not trigger it.
  During a boss fight, retain the normal named raise toast rather than replacing
  the boss's danger introduction with the tutorial banner.
- Track only this mission's army kills, promotions, named losses and close calls.
  A veteran's lifetime kills must not masquerade as mission contribution. Keep
  telemetry ephemeral until it joins the existing optional result report.
- At camp, show a short army account with one named standout when earned. State
  whether that ally survived; never describe failure or retreat as banking a
  veteran or rewards. Legacy/malformed optional reports remain safe to display.
- Keep the existing Lich wards, Colossus fracture/exposure and Tyrant meteor seals.
  During campaign Lich wards, Swarm can prioritize reachable phylacteries over
  the invulnerable boss. Clear this priority when wards/boss end. Hunt/Guard retain
  their behavior. Give situational, rebound-key stance tips only with an army;
  do not auto-switch stances or require an army to defeat any guardian.

## Constraints and evidence
- Existing Godot/GDScript, assets, sound and UI patterns; no dependencies/art spend.
- Preserve Classic combat behavior, save schema, economy outside the one bounded
  opening soul drop, existing rank ceilings and veteran settlement authority.
- Worktree and local `override.cfg` isolate QA from the real player profile.
  The override is local-only and must never be included in a published change.
- Test first, run focused and full headless suites, run a 420-simulated-second smoke
  bot and inspect actual rendered first-binding/camp/guardian presentation.
- Initial implementation did not authorize publication. The user subsequently
  authorized push, merge and installation; use the existing release workflow,
  preserve newer default-branch features, verify provenance, and back up the app.
  Deletion of player data remains prohibited.
