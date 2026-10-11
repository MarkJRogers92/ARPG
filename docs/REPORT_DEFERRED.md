# Report follow-through · local implementation

The first-pass tree was archived before this work. Production saves are not QA
fixtures; repeated production-file audits are omitted at the user's request.
No publication or installed-app replacement is part of this task.
This follow-through supersedes the deferred list in the historical first-pass
`REPORT_IMPROVEMENTS.md`; it does not change that earlier evidence.

## Coverage checklist

| Report recommendation | Starting status | Follow-through |
| --- | --- | --- |
| Evolution checklist, pinned build goal, affected stats, reveal | Complete | Retain; add interaction previews |
| Friendly opacity, crowded captures | Complete (bolts/aura) | Retain protected hostile visuals |
| Modest offer weights, limited banish | Outstanding | Seeded weighted comparison; two bans per attempt/night |
| Three behavioral combinations | Outstanding | Frost Relay, Ashen Escort, Blade Wake; bounded live triggers |
| Early class goals, optional packages | Outstanding | Signature guidance and ownership-checked Reliquary presets |
| Authored phases and dangerous-role budgets | Outstanding | Real-time phase table plus living population/role limits |
| Reward opportunities, major reward reveal | Partial | Scheduled themed detour; nonblocking, dismissible reveal |
| Active-time DPS, targets, reactions | Outstanding | Actual damage ledger, explicit availability denominator |
| Existing Bestiary/realm goal | Outstanding | Account-state suggestion at Trainer/Reliquary |
| Choice-based unlocks | Outstanding | Earn interaction relic choices and tactic contracts with stars |
| Thematic reward pools | Outstanding | Army/elemental/mobility, legal fallback, committed node prize |
| Army, dash, reaction challenge contracts | Outstanding | Campaign-scoped fixed kit, restriction, measured goal and account relic choice |
| Facility trees, goal funding, scouting, visible town tiers | Complete | Retain and integrate preparation forecasts |
| Authored contracts with town consequences | Partial | Supplier, tools and veteran-service credits; settlement once |
| Optional preparation slot | Outstanding | Recovery / survey / recruits; paid once, consumed at departure |
| Veteran contract-fit planning | Outstanding | Rank/deeds/pledge/availability and fit beside next contract |
| Optional fatigue/recovery | Outstanding | Opt-in; successful-clear clock, ordinary-army fallback |
| Empowered shrine/dash experiment | Outstanding | One Warding dash charge; explicit reset/consumption rules |

## State lifetimes chosen before implementation

- Banish: two regular cards per Classic night or campaign attempt. Classic
  suspend keeps exclusions and remaining uses. Campaign resume restarts the
  committed attempt's combat as before; retry is a fresh attempt. Evolutions
  and healing cannot be banished.
- Thematic gear: no cross-item depletion; independent copies may duplicate.
  Within an item, existing stat/operation exclusion remains. Eligible thematic
  affixes/powers are preferred; incompatible slots fall back to broad legal gear.
  A contract prize is rolled and saved at route commitment, not on retry.
- Preparation: one paid town slot. Depart consumes the slot and freezes it in
  the attempt. Resume reconstructs that same kit without spending; after failure
  or retreat a retry has no preparation unless another is bought. Survey reveals
  one connected road on departure; that information survives failure.
- Town credits: one service use after the successful contract; unused credits
  expire at the next departure. The optional marked detour must be claimed as
  well as the contract cleared. Skipping it keeps the ordinary clear reward.
  Failure cannot grant or refresh credits.
- Fatigue: optional and off by default. Only successful node clears tick it:
  deployed veterans gain one (two means resting), idle veterans recover one.
  Failure, retry, menu visits and reload do not tick it. Ordinary recruits never
  tire; no veteran is needed to depart. Paid recovery clears fatigue immediately.
- Empowered Warding: charging a Warding shrine grants one non-stacking dash
  pulse; a successful dash spends it even if it hits nothing. Invalid dash input
  does not spend it. It expires with the blessing and is not Classic-suspended;
  campaign attempt restart/retry begins without shrine power.

## Implemented rules and scope

- Offers keep a positive exploration weight. Owned weapons get 1.5×, a relevant
  recipe catalyst 1.35× once (not per shared recipe), and early class-supported
  stats 1.25× through level 5, capped at 2×. Ready evolutions remain priority
  offers. The supplied RNG also chooses between ready evolutions. Banish
  replaces only its slot, not the other offers; exhausted pools still heal.
- **Frost Relay:** Chain Lightning hitting a chilled enemy sends one 1.6 m
  frost pulse 2 m beyond it, for 50% of the triggering base hit, once per 0.75 s.
  Lightning and a live chill source must both remain available.
- **Ashen Escort:** an army hit on a burning target sends one 1.6 m fire pulse
  for 50% of that base hit, once per second; requires army capacity and a burn
  source. **Blade Wake:** a successful dash with Spirit Blades sends three
  0.7 m pulses at 2/4/6 m, for 40% blade damage each. All are rank-one cards;
  the combined queue caps at five. Previews say what is missing and whether a
  card is dormant. Re-equipping counterparts does not require taking it again.
- **Themed rewards:** Hunt/Cache/Commander's Trial favour army gear; Breach and
  Resonance Trial favour elemental gear; Elite Hunt/Stormpath Trial and the
  labelled Market offer favour mobility. A legal themed affix is selected first
  when available; a Legendary prefers a compatible themed power. Remaining
  affixes and incompatible slots use legal broad fallback. Broad enemy drops
  exclude source-only army affixes and keep their original general membership.
  Wager upgrades retain the route theme. The labelled elemental shrine uses a
  committed Magic amulet roll in campaign; Classic uses a fresh thematic draw.
- **Tactic contracts:** unlock for newly created campaigns at 1/2/3 account
  Bestiary stars. Existing campaigns keep their creation-time ownership and
  road graph. Every road layer retains ordinary contracts. Trials target 3:00,
  with the existing 4:00 deadline arbitration: 100 army damage; eight dashes and
  30 Stormstride damage; or 100 reaction damage. All use actual, non-overkill
  damage. Army and dash trials disable hero auto-weapons. The elemental trial
  disables physical hero weapons and army recruitment, including veterans,
  borrowed soldiers and purchased recruits; neutral utility cards remain legal.
- Successful trial settlement grants **Ember Banner / Blade Compass / Relay
  Lens**, respectively, in the same account receipt as shards/kills. These are
  choices, never auto-equipped, and also have 3/4/4-star alternatives. Ownership
  survives a profile reload and failed outbox delivery is retriable. Existing
  one-relic/one-starting-weapon selections and paid weapon ownership govern the
  optional packages. No permanent-stat requirement was added.
- **Mission rhythm:** opening (0–14%), contract-biased surge (14–60%), recovery
  and elemental opportunity (60–74%), then finale. Fractions use real mission
  duration, not enemy-scaling age. Director-managed waves have living population
  limits of 700 Classic / 240 campaign, and dangerous-role spend limits of 70/24
  before phase multipliers. Ranged/charger/large costs are 2/2/3 and individual
  role caps derive from spend. Scripted bosses/event spawns are not suppressed
  or killed by this wave policy; this is not a global cap on every scripted actor.
- **Measured recap:** real damage, hits and unique targets by source; DPS uses
  source-availability combat seconds, excluding pauses, town and Night Market.
  Removed weapons stop accumulating time except for real lingering hits/statuses.
  Melt's proportional bonus belongs to Reactions and its base stays with the
  weapon. Reaction detail is explicitly included in, not added to, totals.
  Legacy snapshots retain damage with unmeasured denominators. Target sets cap
  at 20,000 per source and label the count as a lower bound after saturation.
- **Presentation:** progression goals at Trainer/Reliquary, class signatures,
  scrollable long panels, trial kit/goal/reward previews, optional detour markers,
  paid-slot forecasts and fatigue/pledge/contract-fit text. Reveals are
  presentation-only: Enter or the button dismisses them; Escape and dash remain
  available, and paused menu input is not intercepted.

No new hero models, meshes, skins, roster adapter or release settings changed.
The accepted robes, motion, Battlemage trim and Aegis hood remain as shipped.

## Participants and review resolutions

- GPT-6.1 Sol: planning, campaign/trial/metrics implementation, integration,
  corrections, native visual review, tests and evidence consolidation.
- Kimi K2.7 Code: weighted offers and interaction cards.
- DeepSeek V4.1 Flash (`opencode-go/deepseek-v4.1-flash`): mission phases and budgets.
- GPT-6 Luna (`opencode-go/gpt-6-luna`): untested reward-pool proposal, adapted and
  verified by Sol rather than accepted as tested implementation.
- MiniMax-M3 (`opencode-go/minimax-m3`) and Claude Haiku 5.5
  (`opencode-go/claude-haiku-5-5`): independent read-only reviews.

Resolved findings include banish acting as a free full reroll, lost wager themes,
pause/dash interception by reveals, an invalid Warding stats field, reaction-trial
army leakage and star checks overriding receipt-owned relics. Final presentation
review also corrected package labels to accept either stars or a trial clear;
weapon ownership is still required. Capture fixtures now freeze timed reveals,
reset spatial grids after despawning and reset retained service-scroll offsets.

## Verification

Final Godot **4.6.stable.official.89cea1439**, Compatibility / Apple M2:

- **40/40 registered headless suites passed** on the final runtime/test source;
  three focused suites also passed. Campaign planning passed 1,827 checks,
  including receipt-owned packages below their alternative star thresholds.
- Native **1280×720 and 1440×900** UI checks passed **50 assertions each**.
  Both crowded-combat checks produced real Frost Relay, Ashen Escort and Blade
  Wake damage. Sol inspected the 28 original-size controlled captures and both
  overview sheets, including scrolling, kit details and opacity 1.0/0.35 pairs.
  Final native logs contain no errors or warnings.
- All three kit-only tactic bots cleared and settled at **180.00 / 180.00 /
  180.01 combat seconds**, with natural spawning, legal upgrades and no
  invulnerability. The reaction trial kept an army count of zero.
- Classic bots passed all three **420-frame-second budgets**. Actual final
  combat times were Graveyard **387.5 s**, Frozen **419.1 s**, Ember **405.0 s**;
  level-up pauses consume harness frames, not combat time. The Necromancer bot
  survived **900.0 combat seconds** (seed 58103, greedy policy); it did not win
  the final-boss fight. Its 706 peak includes independently scripted actors.
- Smoke gameplay logic matches final; later changes are presentation-only:
  trial-aware signature toast, truthful army preview units, multiline detour
  copy and alternate-ownership Reliquary labels. Final-source tests and native
  checks cover those changes; both smoke/final manifests and their delta remain.
- No script errors occurred. Four registered-suite logs and one focused log
  retained known ObjectDB/resource-at-exit warnings. The core suite also emitted
  an intermittent post-pass ObjectDB `slot >= slot_max` lookup diagnostic; a
  separate same-source core rerun passed cleanly. These are recorded, not fixed
  or hidden. Five smoke logs retain resource-at-exit diagnostics.
- `git diff --check` passed. Both the full report patch against `c7953dc` and
  the deferred-only patch against the first-pass checkpoint were replayed and
  verified byte-for-byte. New script UIDs are engine-generated and unique.
- The seven installed-app files, original project settings and three protected
  pre-existing documents remain byte-identical. No report changes were committed,
  pushed, published or installed, and production saves were not QA fixtures.

Durable evidence, source archives, exact hashes, raw diagnostics and actual model
usage: `/Users/markrogers/Desktop/art/reviews/soulbound-report-deferred-20261011/`.
`verification.json` is authoritative for the final snapshot; the first-pass
checkpoint and comparison evidence remain separately preserved.

Balance values are original proposals, not copied reference-game values.
Automated runs cannot establish human enjoyment, empowered timing benefit,
representative performance or long-term campaign balance. Friendly opacity still
covers bolts/aura rather than every friendly effect. No new Windows/Intel gameplay
execution or full human campaign playthrough was performed.
