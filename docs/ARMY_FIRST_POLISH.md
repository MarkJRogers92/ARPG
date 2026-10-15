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
- A fresh post-fix Graveyard Hunt completed and settled successfully at **300
  seconds**: 601 kills, including 178 credited army kills and one promotion.
  Its named standout earned 85 kills during that mission; settlement preserved
  the report. This is one automated scenario, not a general balance result.
- Classic smoke passed with the prescribed `-- 420` fixed-60Hz frame budget
  (25,200 frames; game clock 388.9 seconds after pauses/slow motion), 12,041
  kills and 35 upgrades. No script errors were observed.
- Native Compatibility-renderer fixtures cover the real first-binding banner,
  all three guardian phases, and camp result at measured **1280x720**. Capture
  checks assert actual image dimensions and the banner's visible alpha.

The pre-delivery post-fix run passed **43/43 suites**, preceded by four affected/core
suites. Runtime and test source hashes were unchanged throughout the run.
Independent whole-change review found three missing producer paths (altar
sacrifices, Soulfire kills and zero-kill surviving close calls); all three were
fixed with failing regressions first, then independently re-reviewed:
**COMPLIANT / ACCEPT, no residual blockers**. Soulfire contributes to the army
total, not an unrelated surviving minion's lifetime deeds.

## Local preview and limits

The isolated worktree uses an **untracked, local-only** `override.cfg` with the
`Soulbound_ArmyFirst_20261014` profile and windowed QA settings. Do not publish
that file; opening a checkout without it uses the normal player profile.
The original 406 non-log player-file fingerprints, complete file set and
`project.godot` bytes were verified unchanged after final validation. Godot generated the new UIDs;
unrelated asset-import sidecar churn was restored.

Headless integration, Hunt and Classic smoke exits still report
ObjectDB/resources-in-use diagnostics; 13 of the 43 final suite logs contain
the resource diagnostic accepted by the existing runner. Native fixtures exited
without those diagnostics. This pass does not claim a shutdown-leak fix.
No full human campaign, subjective balance test or crowded-scene performance
benchmark was performed.

## User-authorized delivery

After accepting the local implementation, the user authorized **push, merge and
installation**. The default branch had advanced from the reviewed 9e17bdb source
to 4cbeab7 (PR57), adding five night systems and a world/UI overhaul. Integrate
those changes rather than replacing them, then revalidate the combined tree;
the 43-suite and visual evidence above is the pre-integration checkpoint.
Use the existing PR checks and release workflow, verify the release commit and
Mac asset integrity, and preserve an app backup and every original player file.

## Models

Primary implementation/integration: GPT-6.1 Sol. Army task: GPT-6 Luna through
the personal OpenAI route. Camp formatter/UI and final telemetry fix wave:
DeepSeek Flash direct API.
Independent integration review: Muse Spark 1.3 direct API; independent
whole-change review: a separate personal GPT-6.1 Sol worker. No premium Claude,
Astra, paid Go, free/contributor model or paid art generation was used.
