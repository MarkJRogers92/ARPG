# Settlement stories

Four authored encounters extend the existing walkable campaign waystops. Each uses the campaign controller’s normal cloned-state transaction, save validation, and operation receipts. New state is an optional `stories` member inside schema-v1 saves: older saves without it remain readable and receive empty story records on their next committed command. Supplied history must contain all four valid records; partial, unknown, or altered reward data is rejected.

## Mara’s lantern

Mara at Gravediggers’ Camp offers a free, optional field pickup for the next committed expedition. Its brass-blue marker uses the existing Use action, costs no time or gold, and takes precedence over nearby landmark prompts. The lantern is attempt-local: a death or retreat does not bank the pickup and the saved errand stays active for retry. A successful road clear without the lantern records the errand as missed, explicitly carries the empty hook forward, and never blocks campaign progress. A successful pickup pays a one-time 25 gold with expedition settlement. The following waystop displays a lit lantern memorial or an empty hook, and the journal/result retain that outcome. Reward, completion record, normal route reward, and waystop advance commit together.

## Whitepass Refuge

Hessa Vale is stranded while she waits for her brother and a supply convoy. The player can give 8 gold for a fire tonic (+8% damage), brace her signal brazier at no cost (+8% armor), or leave. The benefit applies to the next route selected (or the already committed route), survives failed retries, and clears only when that road succeeds. Choice and benefit are saved once.

## Sledwright’s Rest

Elian Rusk has a split sled runner. An iron shoe costs 15 gold and gives +8% move speed. The free canvas splint instead asks the player to lash and test it in two brief steps, then gives +10% armor. Either repair is a one-time choice, travels through retries on the next selected road, and clears when that road succeeds. The runner visibly changes to the selected repair.

## Redwake Caravan

Juno Calder lets the player inspect a scorched crate before accepting or declining. The one-time disclosed trade stakes 15 gold: a deterministic 60% win returns 32 gold (+17 net); otherwise the cargo is lost (-15 net). The fee, random draw, result, payout, and played state commit together, so reload or a new operation cannot reroll it. The opened crate shows coin or ash to match the saved result.

All paid choices show their exact cost and are unavailable below the required gold; free practical help or decline stays available. NPCs use the current rebindable Use action, have individual world props and motions, and their dialogue supports keyboard/gamepad focus. Story progress appears in the settlement journal and remains separate from any profile progression.

## Safe local sampler

Run from the repository root with Godot 4.7.2:

```sh
/opt/homebrew/bin/godot --path /Users/markrogers/ARPG -s tools/campaign_settlement_story_demo.gd
```

Choose one of four stops to mount the real campaign Shell and walkable town. Each selection makes a fresh timestamped checkpoint under `user://settlement_story_demos/`. The launcher disables account progression and never uses the normal `campaign.save` or profile save. Within a selected demo, continue and retry work normally; relaunching the sampler starts a new disposable demo.

## Focused verification

```sh
/opt/homebrew/bin/godot --headless --path /Users/markrogers/ARPG -s tools/campaign_settlement_stories_test.gd
/opt/homebrew/bin/godot --headless --path /Users/markrogers/ARPG -s tools/campaign_camp_life_test.gd
```

The settlement-story harness uses isolated saves and disabled profile progression. It covers command/save/reload, old-save compatibility, failed writes, retry semantics, NPC Use dialogue, trade bounds, mission pickup behavior, result payoffs, and persistent memorial geometry.
