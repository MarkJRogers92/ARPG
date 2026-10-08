# Campaign content and tuning

The authoritative rules are `scripts/campaign/campaign_catalog.gd`; transactions live in `campaign_controller.gd`, mission schedules/objectives in `expedition_director.gd`, and bounded wave growth in `WaveDirector.configure_expedition`. Catalog version: `expedition-v1`. Saved graphs/offers/outcomes are materialized; changing a seed algorithm does not reroll an existing campaign.

## Economy

Starting gold: 60. Hunt/Breach/Elite Hunt/Cache pay 100 / 110 / 140 / 100; finales pay 250. Biome multipliers 1 / 2 / 3 apply. Unspent mission shards convert 1:1, with short caps of 50 × biome and finale caps of 150 × biome. Failed attempts bank none of their gains. First short clears give 5 account shards; biome bosses give 20. Finite six-item stock refreshes only on a new combat clear.

Catalog valuations by rarity are 20/50/100/220 × biome; sale values are at most one quarter of the saved valuation. Reforge costs 60 × biome once per copy per biome, consumes its use even when keeping the old roll, and retains copy identity. Biome item-level bands are 1–12/10–24/20–36, using route depth and source rather than reset combat level.

Ordinary field loot accrues roughly one budget token per minute. Guaranteed objective/settlement rewards are separate explicit content. The six-to-ten short-expedition target includes the Ferryman's reserved prize; five collected field items plus that prize reaches the lower end. This is a tuning target, not a guaranteed drop count.

## Combat profiles

Campaign pressure remains 1 and never uses health-driven adaptive escalation. Ordinary spawn rates begin at 0.48 with linear 0.0045 and quadratic 0.000004 growth. Realm spawn factors are 0.72 / 0.82 / 0.92; HP factors are 0.8 / 0.9 / 1.0. Elite routes apply 1.25 spawn and 1.15 HP factors. Derived growth age runs at 2.4 for shorts, capped at 420, and 1.8 for finales, capped at 900. The actual mission clock continues normally.

Final guardians arrive at 900 actual combat seconds. Campaign guardian HP factors 0.035 / 0.04 / 0.045 apply on top of the capped derived HP multiplier; Classic values remain unchanged. Final mechanics remain Lich wards/phylacteries, Colossus fractures/exposure and Tyrant seals/meteors. The 2–4 minute boss-fight duration is a design target and is not guaranteed across fresh and fully upgraded builds.

Short midboss arrival: 150 s, interval: 360 s; finale midboss arrival: 180 s, interval: 210 s. Short atmosphere compresses toward extraction independently from combat time. Seal/cache/elite beacons and edge markers use the current objective state. Terminal arbitration runs after damage sources, prioritizes player death, and records combat time before the two-second frozen return ritual.

## Content extension rules

Keep new contracts/events in the authored catalog, define safe zero-gold choices and explicit effect expiry, and validate all saved IDs. Do not award persistent talents from combat levels or landmarks. New item sources must use campaign item-level rules and stable copy IDs. New transactions must validate a copied next state and commit its operation receipt before UI success.

The Ledger is capped at two obligations per biome: Advance Payment adds one Collector at guardian arrival; Stolen Arsenal adds two elite shieldbearers once below half health; Borrowed Battalion adds two reinforcement waves at +45/+90 seconds. Borrowed soldiers are three additional ordinary minions for every attempt of the committed next node. Failed attempts retain obligations; boss victory clears the biome ledger.

## Visual identity

The Last Lantern is native low-poly geometry and existing Soulbound props. Astra authored its new flagstone court, ruined apse, indigo standards and brass/cyan beacon, with warm forge light, cool soul light and drifting motes. The town renders one isolated 3D viewport; opaque service panels preserve text contrast. There are no paid media services, downloaded textures or new asset production dependencies.

Overnight checkpoint 1 added presentation and player guidance only. It did not change damage, boss timing, economy, item rates, or drop quality. Its automated journey evidence remains the earlier baseline run; see `OVERNIGHT.md` for the limited focused checks and visual-review scope.
