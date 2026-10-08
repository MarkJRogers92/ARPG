# Expedition Campaign Interfaces

Task ID: task_00000001. Content version: `expedition-v1`.

## Ownership

Core owns `scripts/campaign/{campaign_catalog,campaign_state,campaign_save,campaign_controller,campaign_shell}.gd`, `scenes/campaign.tscn`, `scripts/meta_progress.gd`, `scripts/items/{item,item_generator}.gd`, title entry and pause presentation. UI owns additive `scripts/campaign/campaign_town.gd` and its visual assets. Combat owns `scripts/campaign/expedition_director.gd`, `scripts/main.gd` and the required combat collaborators. Coordinate shared-file changes before editing. The parent owns Git checkpoints and acceptance.

## Shell and combat boundary

`CampaignShell` owns a `CampaignController`. It mounts a fresh `scenes/main.tscn` instance only after the prior scene has exited and static combat bindings have been cleared. Before adding combat to the tree, set `main.expedition_spec = controller.depart()["spec"]`. On an interrupted active-save load use `controller.resume_spec()` instead; this returns the exact saved departure and attempt ID.

The combat root exposes:

- `var expedition_spec: Dictionary = {}` (empty means Classic).
- `signal expedition_finished(result: Dictionary)` after frame-level terminal arbitration and frozen combat.
- `signal expedition_quit_requested` for save and quit; active campaign checkpoint remains committed.

The shell settles through `controller.settle(result)` and then mounts town. On a failed save it keeps the frozen combat/result and offers retry; no new scene launches. Combat never calls Classic account banking, account Crypt death, realm/Ascension/Daily win, persistent nemesis mutation, or `RunSave` for a campaign attempt.

## Controller API

`CampaignController extends Node`; `state: Dictionary` is authoritative and views use `snapshot()` (deep copy). `changed(state: Dictionary)` and `error_raised(message: String)` publish committed changes/errors. Every command returns `{ok: bool, error: String}` plus optional `spec`, `result`, or `payload`. Commands accept optional `operation_id: String = ""`; generated receipts are returned as `operation_id`. Reusing an ID with the same command returns its existing result; reuse for another command fails.

- `create(hero_class: String = "", campaign_seed: int = 0)`; refuses replacement until outstanding profile rewards deliver.
- `load_campaign()`, `snapshot()`, `available_routes() -> Array`, `resume_spec() -> Dictionary`.
- `choose_route(node_id, operation_id="")`, `resolve_event(choice_id, operation_id="")`.
- `depart(operation_id="")`, `settle(result: Dictionary)`, `acknowledge_result(operation_id="")`.
- `buy_item(stock_id, operation_id="")`, `sell_items(item_ids: Array, marked_only=false, operation_id="")`.
- `equip_item(item_id, operation_id="")`, `unequip_item(slot, operation_id="")`.
- `mark_item(item_id, locked: bool, junk: bool, operation_id="")`.
- `claim_item(item_id, operation_id="")`, `discard_item(item_id, operation_id="")` (tray/backpack only; protected/equipped excluded).
- `reforge_item(item_id, operation_id="")`, `resolve_reforge(keep_new: bool, operation_id="")`.
- `allocate_talent(node_id, operation_id="")`, `refund_talent(node_id, operation_id="")`, `reset_talents(operation_id="")`, `choose_specialization(path_id, operation_id="")`.
- `choose_veteran(veteran_id, operation_id="")`, `recruit_veteran(candidate_id, replace_id="", operation_id="")`, `decline_veteran(operation_id="")`.
- `accept_clause(clause_id, slot="weapon", offer_index=0, operation_id="")`; Stolen Arsenal offers from `clause_offers(slot) -> Array` are persisted before choice.
- `wager(pledge=false, operation_id="")`, `take_wager(operation_id="")`.
- `deliver_outbox()`, `abandon()` (game UI confirms first).

Town operations are allowed during TOWN, EVENT_PENDING and DEPARTURE_READY; settlement is already committed during RESULT_PENDING, and acknowledge only changes presentation phase. Departure requires an empty reward tray, no pending reforge, no unresolved event, and an ended wager/candidate decision. A failed attempt leaves the same node committed. Account-delivery failure retains settlement/outbox and blocks replacement/abandonment, not inspection.

## State shape

`{schema_version, content_version, campaign_id, seed, revision, phase, hero_class, biome_index, gold, profile_snapshot, inventory, talents, specialization, roster, deployed_veteran, graph, selected_node, cleared_nodes, clauses, effects, event, event_count, shop, shop_generation, wager, reforge, veteran_candidate, departure, result, receipts, successful_nodes, outbox, item_serial, attempt_serial, completed}`.

Phases: `TOWN`, `EVENT_PENDING`, `DEPARTURE_READY`, `EXPEDITION_ACTIVE`, `RESULT_PENDING`, `CAMPAIGN_COMPLETE`, `ABANDONED`.

`inventory = {items: {stable_id: item_record}, equipped: {slot: stable_id}, backpack: [stable_id], tray: [stable_id]}`. Each record is `{id, data: Item.to_dict(), locked, junk, valuation, reforged_biomes: []}`. IDs identify copies; runtime `Item.uid` never identifies a campaign transaction. `Item.campaign_id` is backward-compatible and round-trips in `to_dict/from_dict`.

`talents = {points, allocated: [SkillData node ids], earned}`. Only successful settlements increase earned budget (3 start + 9 short clears + 6 first-two-boss grants = 18). `profile_snapshot = {mods: [...], relic, start_weapon, rerolls, cards}` captures account stats/Bestiary and selection once.

Veteran record: `{id, name, swarm, label, role, elite, deeds, rank, nights, pledge_node}`. `rank` uses current Army semantics; destination reconstruction caps at biome index+1. `pledge_node = "next"` until the next route commitment, then its stable node ID, and clears only on that node success. Campaign veteran combat copies use `crypt=-1`.

Graph: `{seed, content_version, start: [node ids], nodes: {id: {id, depth, contract, elite, seed, event, next: [ids], reward_slot}}}`. Depths 1–3 are combat; depth 4 is `finale`. Available routes follow the last cleared node's saved edges. Cleared nodes never replay.

## ExpeditionSpec dictionary

Required fields: `{campaign_id, biome_id, biome_index, node_id, attempt_id, contract_id, profile_id, mission_seed, content_version, duration, deadline, final_boss, loot_band, item_level, elite, objectives, effects, clauses, starting_loadout}`.

`starting_loadout = {hero_class, profile_snapshot, inventory: Inventory.to_dict() [equipped item dictionaries + backpack dictionaries], talents: {points, allocated}, specialization, veteran: record or {}, gold}`. Combat receives a deep copy, constructs new PlayerStats/Inventory/SkillTree/Army, applies account snapshot → class → relic/weapon → inventory → talents → specialization → scoped effects, then heals. Combat skill-point writers are disabled. Neither combat nor its inventory screen sells/discards banked items.

`effects` is an array of catalog-scoped records; `mods` is an array of PlayerStats modifier dictionaries; `borrowed_battalion` includes `minions: 3`. `clauses` uses IDs `advance_payment`, `stolen_arsenal`, `borrowed_battalion`. Combat director may query `CampaignCatalog.CONTRACTS`, `BANDS`, and `CLAUSES`.

## ExpeditionResult dictionary

Required identity fields echo spec. `{campaign_id, node_id, attempt_id, outcome: "success"|"failure"|"retreat", elapsed: float, objectives: Dictionary, inventory: Inventory.to_dict(), loose_shards: int, kills_by: Dictionary, veteran: record or {}, report: Dictionary}`. `inventory` includes actual collected loot, with existing campaign IDs preserved and new stable IDs supplied by combat (prefix `attempt_id + ":drop:" + local_counter`). New drop data is validated against catalog vocabulary and campaign tier. Unpicked world loot is absent. The controller derives Gold, talent and account payment; result-supplied financial values have no authority.

`objectives` contains `seals: int`, `elite_dead: bool`, `cache_claimed: bool`, `boss_dead: bool` as relevant. Finales require boss_dead and elapsed >=900. Breach needs three seals and elapsed >=360, <=420; Elite Hunt needs elite_dead and elapsed >=300, <=420. Hunt >=300; Cursed Cache >=360. Player-death wins a same-frame tie. Combat ends at its simulation completion timestamp and cosmetic return seconds do not accrue time or rewards.

## Deterministic generation and save behavior

`ItemGenerator.generate(ilvl, quality=0, rng: RandomNumberGenerator=null)` and `generate_with(ilvl, rarity, slot, rng=null)` preserve Classic default global RNG and permit independent campaign streams. Generated graph/stock/offers/wager outcomes persist as actual facts. `CampaignSave.path` is a test-overridable `user://campaign.save`, with `.bak`; `CampaignSave.fail_stage` supports write/replace failure injection. Variant saves never deserialize objects. Validation runs before save and load. Profile reward IDs persist in `MetaProgress.campaign_receipts` with shards/kills/completion data atomically; controller outbox replay is exact-once.
