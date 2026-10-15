# Army-first expedition polish

## Player-facing changes

- The opening Graveyard attempt supplies one ordinary ally's worth of souls
  from the first ordinary kill, still requiring pickup. Existing starter armies,
  elite/boss souls, later routes and army-restricted trials do not get extra aid.
- A first soul-funded binding introduces the enemy that now fights for you and
  the currently mapped stance key. No pause, forced stance, or extra flash is
  added. Boss danger introductions take priority over the tutorial banner.
- Army accounts record mission-only kills, promotions, named losses and a real
  named standout/close call. Lifetime veteran kills are not counted again.
- The pending camp result recognizes those deeds in a short sentence. Legacy
  results remain readable, and failed/withdrawn attempts do not claim to bank
  a veteran or rewards.
- Guardian advice follows the existing ward, fracture/exposure and meteor-seal
  phases. Campaign Swarm can focus reachable Lich phylacteries instead of the
  invulnerable boss; Hunt, Guard and Classic targeting are unchanged.

## Verification

Tests use the existing runner and Godot **4.6.stable.official.89cea1439**. New
focused suites are `army_story_test.gd`, `army_first_integration_test.gd`, and
`campaign_army_story_test.gd`, registered in `tools/run_tests.sh`.

- Five affected suites passed before implementation; new feature assertions
  were observed failing before their implementation.
- A natural opening-combat check (no injected kills, souls or combat stats)
  bound its first ally at **8.42 seconds**, after one kill.
- A fresh integrated Graveyard Hunt completed and settled successfully at **300
  seconds**: 595 kills, including 132 credited army kills and one promotion.
  Its named standout earned 92 kills during that mission; settlement preserved
  the report. This is one automated scenario, not a general balance result.
- Classic smoke passed with the prescribed `-- 420` fixed-60Hz frame budget
  (25,200 frames; game clock 382.4 seconds after pauses/slow motion), 10,315
  kills and 36 upgrades after upstream integration. No script errors were observed.
- Native Compatibility-renderer fixtures cover the real first-binding banner,
  all three guardian phases, and camp result at measured **1280x720**. Capture
  checks assert actual image dimensions and the banner's visible alpha.

The post-fix checkpoint passed **43/43 suites**. After integrating PR #57, the
final combined run passed **63/63 suites** with unchanged runtime/test hashes.
All 60 upstream suites and the three army-first suites are retained. Eight
affected/compatibility suites passed first; 39 new combined assertions cover
Requiem overflow, source-specific binding, dance kill/promotion attribution,
invulnerability and target reacquisition. Independent compatibility review
accepted the exact combined runtime and test delta without blockers.
Independent whole-change review found three missing producer paths (altar
sacrifices, Soulfire kills and zero-kill surviving close calls); all three were
fixed with failing regressions first, then independently re-reviewed:
**COMPLIANT / ACCEPT, no residual blockers**. Soulfire contributes to the army
total, not an unrelated surviving minion's lifetime deeds.

## Local preview and limits

The isolated worktree uses an **untracked, local-only** `override.cfg` with the
`Soulbound_ArmyFirst_20261014` profile and windowed QA settings. Do not publish
that file; opening a checkout without it uses the normal player profile.
The original 406 non-log player-file fingerprints and complete file set were
verified unchanged after integrated validation. The feature adds no project,
export, workflow or asset changes relative to PR #57; its menu/gamepad and dance
bindings are preserved. Godot generated the new UIDs; unrelated asset-import
sidecar churn was restored.

Headless integration, Hunt and Classic smoke exits still report
ObjectDB/resources-in-use diagnostics; 23 of the 63 integrated suite logs contain
the resource diagnostic accepted by the existing runner. Native fixtures exited
without those diagnostics. This pass does not claim a shutdown-leak fix.
No full human campaign, subjective balance test or crowded-scene performance
benchmark was performed.

## User-authorized delivery

After accepting the local implementation, the user authorized **push, merge and
installation**. The default branch had advanced from the reviewed 9e17bdb source
to 4cbeab7 (PR57), adding five night systems and a world/UI overhaul. Those
changes were integrated and revalidated, including native 720p first-binding,
guardian and camp captures using the newer world/UI. The only merge conflict
combined the new soul-binding signal with existing Requiem overflow.
Publication uses the existing PR checks and release workflow; release commit
and Mac asset verification, app replacement and startup are delivery gates, not
claims made by this pre-publication document. The existing signed app and saves
were copied and byte-compared before replacement.

## Models

Primary implementation/integration: GPT-6.1 Sol. Army task: GPT-6 Luna through
the personal OpenAI route. Camp formatter/UI and final telemetry fix wave:
DeepSeek Flash direct API.
Independent integration review: Muse Spark 1.3 direct API; independent
whole-change review: a separate personal GPT-6.1 Sol worker. No premium Claude,
Astra, paid Go, free/contributor model or paid art generation was used.
