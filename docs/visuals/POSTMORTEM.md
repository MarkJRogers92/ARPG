# Post-mortem follow-up

This is the existing **Why you died / Run Report** feature and the campaign
**after-action report**, not a crash-dump service. Built on visual-polish
checkpoint `30f7558744129431b43d5858bbcfe276fc4c98f2` for review on the same branch.

## Fixed and improved

- Reproduced a 1280×720 death screen where the restart and realm buttons fell
  outside the clipped scrolling area. Those actions now remain in a fixed
  footer. Long reports and the four-action victory/daily variant fit; keyboard
  and controller action events can enter and scroll the report and return to
  the footer. Cause of death now comes before outgoing damage statistics.
- Reproduced a double activation of Rise again calling an already-detached
  Main scene, causing a null SceneTree script error. End-screen navigation is
  now one-shot until another end screen is opened. This also guards realm and
  Endless transitions; copying a daily code remains independently available.
- Added bounded recent incoming-damage history and one **factual** takeaway:
  which recorded source caused the greatest share of recent applied damage.
  It does not claim a death was avoidable or infer unseen player behavior.
- Sub-second outgoing damage samples display their duration to hundredths of a
  second and withhold DPS until at least one second is measured. A 0.02-second
  encounter no longer reads as thousands of DPS divided by rounded “0.0 s”.
- Instant deaths no longer show an artificial one-second health-chart duration.
  A chart requires real time-separated samples; its endpoint uses actual time.
- Empty/unknown causes remain explicit, malformed optional history is ignored,
  and invalid negative/non-finite damage inputs cannot corrupt HP/accounting.

## Telemetry and persistence

`Player.take_damage` records only positive HP actually removed, after armor and
clamped for overkill. Blocked/invulnerable/dashing/shielded damage is excluded.
Healing and recovery effects do not turn this gross incoming-damage measure
into net HP change. Death is recorded before its signal fires.

The clock is Main's combat time. Town, pause, Night Market and the death
animation do not age the trail. Repeated contact/burning ticks are grouped into
0.5-second buckets; each row's displayed age uses the latest damage in that
bucket and is explicitly a group, not an invented individual hit. Whole buckets
within the preceding ten seconds are retained, at most 21 buckets with 16 source
entries each; additional distinct sources are combined under “Other sources
(grouped)”. The display shows the latest four groups, with at most two named
sources plus the remaining aggregate per group. The takeaway uses all retained
groups, not just those displayed.

Classic suspend/resume keeps this optional field in the existing version-1
save. Old saves load with empty recent history. Campaign settlement copies it
into the pending result, which survives reopening and can be acknowledged using
the existing Continue to town action. Defeat still leaves the selected route
committed for retry; it grants no success rewards. Existing final-boss, damage,
reward, campaign identity and save-format mechanics are unchanged.

## Reproduce

Use an isolated profile. The focused test creates disposable run/campaign
files and weakens starting HP for fast reproducible deaths. End-to-end cases
use the real guardian blade collision and an ordinary Ogre's contact damage;
they never emit the death signal or inject the killing damage call. Separate
unit cases directly exercise accounting and malformed data. The long-text
layout stress is synthetic and is not presented as combat evidence.

```sh
bash tools/run_tests.sh -g /path/to/godot
/path/to/godot --headless --path . --fixed-fps 60 -s tools/postmortem_test.gd
/path/to/godot --path . --fixed-fps 60 -s tools/postmortem_test.gd -- --capture-dir=/absolute/output
```

## Validation

- **42/42 aggregate suites passed** on Godot 4.6 stable (`89cea1439`).
- **72 focused post-mortem checks passed**; the rendered 1280×720 version
  passed **78 checks**, including six saved screenshots. The final small chart
  correction was followed by another core/post-mortem run and rendered pass.
- **125 guardian integration checks passed**. An additional clean source-only
  import had no script/shader errors; post-mortem, guardian and combat-ledger
  suites all passed again there.
- The focused cases cover armor/overkill, unknown and malformed data, bounded
  history, sub-second DPS, instant-death charts, real guardian and Ogre deaths,
  duplicate death/navigation calls, two guardian runs, clean new-run data,
  title return, long reports, four-action footer, keyboard scrolling, optional
  save-field round trips and old version-1 saves.
- Actual campaign death returned through Main and CampaignShell to the pending
  report; it survived a disk reload, its real Continue button scrolled into
  keyboard reach and returned to the hub, and a stale duplicate result was
  rejected without rewards.
- A separate **normal full-health** guardian run (no weakened HP) reached death
  at about 12.6 seconds and displayed the real multi-hit recent trail, capped
  final hit, lifetime source shares, weapon metrics and accessible actions.
  This stationary automated run is functional evidence, not a balance judgment.
- The ordinary **420-second Classic bot passed**: survived, 13,696 kills,
  35 upgrade choices in that run. Valid gameplay damage/animation values and
  guardian asset hashes are unchanged.
- Some headless processes still reported ObjectDB/resource shutdown warnings.
  No script exceptions occurred in the final focused/rendered checks. The
  standard runner's existing failure handling was not relaxed.

## Limits

Automated Linux Godot 4.6 Compatibility checks and actual rendered UI, not
human gameplay acceptance or a physical controller-device test. Controller
navigation uses the same action events as keyboard/D-pad. Existing
ObjectDB/resource shutdown warnings may still appear in test processes; this
pass does not claim to fix that engine teardown behavior. No merge, release,
paid generation, AI-service dependency or new art assets.
