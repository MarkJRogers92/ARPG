# Report-driven first pass · 2026-10-10

## Source and delivery boundary

The attached `Soulbound-Improvement-Report.zip` compares the published Soulbound
revision `c7953dc345b8408ceeaf18292c2ab0f091d07cf9` with four reference games.
GitHub review found that same default-branch revision, a successful Build run
`38054873634`, and no open issues or pull requests. Local work is on
`feat/report-driven-improvements`; it is not a new publication or installation.
The reference report informs design decisions only: no decompiled reference
code, game data or third-party assets were copied into Soulbound.

## Implemented

### Build guide and upgrade clarity

- During combat, **Escape → Build guide** lists the existing evolution recipes
  compatible with the hero, weapon **card** rank/max, catalyst ownership,
  readiness and whether an evolution was already taken. Recipes are openly
  listed; this is an explicit discovery policy, not a new unlock system.
- Class/item-granted ability access is distinguished from card rank. Campaign
  checks use the committed account-card snapshot, not later account unlocks.
- A single optional pinned recipe appears in Pause. It lasts only this scene's
  night/expedition, not save/resume, retry, or another run. It does not change
  upgrade weights, offers, prerequisites or gameplay.
- Upgrade and golden evolution cards show affected systems and before/after
  effective values. A disposable stats copy goes through the actual
  `Upgrades.apply` path, including first-card access, rounding, caps, cooldowns
  and indirect Soul Link army damage. These are stat previews, not measured DPS.
- Frostbite's later ranks identify Shatter, Melt and Overload reactions rather
  than claiming generic bolt damage. Chance values display as percentages.
- Evolution announcements include the existing effect description. Settings
  and guide pages scroll with keyboard focus to keep controls reachable at 720p.

### Friendly-spell readability

- **Escape → Friendly bolts / aura opacity**, persisted as `friendly_opacity`,
  defaults to the original 100% and clamps finite values to 15–100%. Invalid
  values fall back to 100% on load and write.
- Live updates affect **Magic Bolt and Frost Aura only** through friendly-only
  shader materials. Other friendly attacks/effect bursts are intentionally not
  included: shared glow/particle/beam materials also serve hostile hazards.
- Hostile shots, danger warnings, actor markers, damage/hitboxes, Calm effects
  and Bold warnings are independent and unchanged. Weak material references
  avoid keeping discarded scenes alive.

### Campaign facilities and concrete funding goals

Investments travel with this campaign through all towns; no facility is required
to progress and no account-wide upgrade is granted.

| Existing service | Tier 1 | Tier 2 |
| --- | --- | --- |
| Route Board · Wayfinder Desk | 60 G: partial danger/base-Gold scouting one connected junction ahead | 120 G: extend to two junctions |
| Market · Workshop | 90 G: append Magic boots and amulet offers now and after successful clears | 180 G: 20% cheaper reforges |
| Crypt · Veteran Hall | 80 G: +1 army capacity | 160 G: 15% more minion damage and life |

- Scouting does not unlock future roads or persist reveal flags. An Ash Map
  still reveals full saved event/equipment-prize details, beyond partial scouting.
- Workshop additions have a separate deterministic stream. Buying a facility
  does not reroll the six existing offers, replace item copies, or refresh on a
  failed expedition. Reforging remains once per item per biome; the fee is
  48/96/144 G with tier 2, otherwise 60/120/180 G.
- Army bonuses are read from committed departure tiers. Town's starting-build
  preview uses the same loadout path; resume/retry retain owned tiers without
  charging again. No veteran is required for the capacity or damage bonuses.
- The next specific tier can be pinned as a **saved town goal**. Service panels
  show exact cost, current bank and after-purchase bank. The Route Board shows
  expected contract Gold on a successful clear and the remaining goal shortfall;
  optional bonuses and Soul Shard conversion are explicitly excluded.
- Upgraded stations gain bounded signs/props and tier-2 light accents. They use
  existing Soulbound assets and retain service positions, use ranges and blockers.
- Purchases and goals use the existing cloned-command, validate, save-then-publish
  controller, including operation receipts and failed-write rollback behavior.
  Schema-v1 saves without facility fields remain valid at zero tiers, including
  already-active departures; loading alone does not rewrite them.

## Deliberately deferred

The report's pacing/spawn-ceiling experiments, weighted tags and banish, richer
measured ability statistics, optional objective variants/challenge rewards,
source-themed gear pools, preparation attrition/fatigue and broader campaign
decision density need separate balancing, economy or instrumentation work.
The 200-seed facility budget probe is a conservative contract-Gold sanity check,
not evidence of completed route playthroughs or balanced purchase timing.

## Verification and preservation

Four new suites are registered in `tools/run_tests.sh`: `build_guide_test.gd`,
`friendly_opacity_test.gd`, `report_improvements_ui_test.gd`, and
`campaign_facilities_test.gd`. The existing GitHub runner automatically includes
them; release workflow files and production project/export identity are unchanged.

Tests and native Compatibility captures run in disposable copies using the
`Soulbound_ReportIntegratedQA_20261010`, `Soulbound_ReportFinalQA_20261010`, and
`Soulbound_ReportFacilitiesQA_20261010` profiles, never the production profile. The durable
verification record, logs, native captures and source delta are kept separately
under the report implementation evidence directory. The previously installed
main app, comparison apps and unrelated local documentation are not replaced.

Native fixtures cover 1280×720 and 1440×900 on Apple M2, plus close-ups of all
three tier-2 stations. This is not Windows/Intel gameplay verification or an FPS
guarantee. The existing headless campaign resource-at-exit warnings remain;
normal native UI/facility fixtures are checked for script and engine errors.

Final checks: all **34 suites** passed on a fresh final-source copy, including
1,949 build-guide checks, 46 opacity checks, 22 scene-UI checks and 334 facility
checks. Native fixtures passed 29 UI checks at each size and 337 facility checks;
20 captures were retained and key menus, paired opacity and station close-ups
were visually reviewed. All five hero smoke scenarios (420 seconds of fixed-frame
steps) passed without deaths or script errors. Smoke gameplay source matches the final code; the final
safe-deferred-focus and station-sign placement refinements were instead checked
by the final-source full suite and native fixtures. The first smoke attempt hit
an overly short 240-second wall timeout; the completed rerun used the existing
CI-scale allowance, not a gameplay code change.

Final evidence: `Desktop/art/reviews/soulbound-report-improvements-20261010/`.
The installed app's seven files, all 372 production-profile files since the
integration checkpoint, production/export settings and three pre-existing local
documents were byte-preserved. No commit, push, merge, publication or installation
was performed for this pass.

Actual contributors: GPT-6.1 Sol (campaign, integration, 3D station dressing,
visual review and final checks); Kimi K2.7 Code (initial guide implementation);
DeepSeek worker (friendly-only opacity); Claude Haiku 5.5 (read-only safety
reviews). GPT-6 Luna inspected the guide but could not implement because its
worker lacked write/execute tools; the bounded assignment moved to Kimi Code.
