# Combat cues: readiness and calmer warnings

Review-branch follow-up to the visual polish. These changes run in normal Main,
Campaign combat and the opt-in guardian encounter. No combat values, rewards,
input bindings or save formats changed.

## Changes

- Below the existing one-third-health threshold, the HP bar also says **LOW
  HEALTH**. The cue no longer depends on noticing a red animated screen edge.
- Calm effects makes the low-health edge tint steady and gentler, and lowers
  contact-hurt tint to 30% strength. Normal effects retain the existing pulse.
  Returning to full health clears the warning. Safe Night Market frames now
  decay stale hurt edges instead of leaving the last combat tint frozen.
- Dash reads **READY** or the actual remaining seconds, rounded up to tenths.
  A positive remainder never shows “0.0 s” or READY. The key hint stays visible
  and follows rebinding. Warding uses the same countdown and keeps its expiry
  tooltip. No timer is reconstructed from a changed cooldown stat.
- The existing bottom hint now reports **AUTO**, **MOUSE** or **STICK**, including
  when mouse takeover is disabled. Stick release and the mouse toggle are
  reflected from Player's real state, without extra overlays or sounds.

## Verification

Godot 4.6 stable, Linux Compatibility renderer. The new `combat_cues_test.gd`
uses isolated settings and a real Main scene: actual dash input, rejected repeat
input, cooldown recovery, real mouse event/toggle/stick state changes, key
rebinding/reset, three pause/settings/resume cycles, low-health threshold/heal,
ward charge/expiry, and actual Night Market entry/exit. A controlled HP fixture
and invulnerability keep these UI checks repeatable; they are not balance tests.

- Focused: 46 assertions. Rendered variant: 49 checks, including captures.
- Existing real-cursor `aim_test.gd`: passed under a 1280×720 display.
- Rendered longest hint fits the 1280×720 viewport; headless uses its virtual
  viewport and is not evidence of physical screen layout.
- Final combined aggregate: 44/44 suites passed. A fresh source-only import
  passed both new suites, guardian integration and Classic resume. The final
  combined 420-second Classic smoke also passed.
- Long reward notices now wrap within the viewport above interaction guidance;
  the visible stack is capped at four. See CROSSROADS_SHRINES.md for the real
  reward capture that exposed the old overflow.
- Known engine ObjectDB/resource-at-shutdown diagnostics remain. No new error
  filter was added. Audio was disabled for cloud visual checks.

Before/after captures use identical seeded Main scene/camera/HP/cooldown fixtures.
Static captures demonstrate layout, not the temporal difference in pulsing.
Physical controller hardware, native exported builds and human playtesting have
not been run. This is a review-branch candidate, not merged or released.
