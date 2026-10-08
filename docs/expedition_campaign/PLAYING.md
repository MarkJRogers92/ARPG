# Playing Expedition Campaign

Open this checkout in Godot 4.7.2, or launch `/opt/homebrew/bin/godot --path /Users/markrogers/ARPG`. Choose an unlocked class on the title screen, then **New Campaign**. **Continue Campaign** restores its last durable checkpoint. Classic Night, Daily and the Classic resume slot remain separate.

## The journey

The Last Lantern connects Hollow Graveyard, Frozen Wastes and Ember Rift. Preview the available connected routes, choose one, resolve its event if present, then depart. Clear exactly three short expeditions in a biome to unlock its guardian. The guardian arrives after 15 minutes; winning requires its actual death and has no new time limit.

- Hunt: survive five minutes.
- Seal the Breach: activate three beacons and survive six minutes; finish before seven minutes.
- Elite Hunt: the marked elite arrives at five minutes; defeat it before seven minutes.
- Cursed Cache: survive six minutes; opening the marked cache is optional and adds danger/reward.

Short success freezes combat and returns you after a two-second ritual. Death loses the attempt's unbanked gains and retains the committed route for retry. Save & Leave during combat restarts that departure checkpoint; it does not preserve partial mission gains.

## Town preparation

Campaign gear, gold, talents, specialization and up to three veterans persist. Combat XP, level-up cards, ordinary army, cooldowns and temporary effects reset on each departure. Three starting talent points grow to a maximum of 18 before the final boss; specialization unlocks after your first short clear. Visit the Trainer for free talent and specialization changes.

Use Equipment and the Market to compare exact rolled gear, equip, lock favorites, mark junk, sell, buy finite stock and reforge once per item per biome. New stock appears only after a new combat clear. Full-inventory rewards wait safely in the reward tray; resolve it before departing. No departure fee or healing bill applies.

Deploy one veteran at the Crypt. Its maximum effective rank is Veteran, Hero or Legend according to the destination biome. A fallen veteran returns for a later attempt. A pledged veteran stays unavailable until its committed node is cleared.

The Ferryman reserves one settlement prize. Take it or risk it at the displayed odds: 70% for the first crossing, 45% for the second. A veteran pledge adds 10 percentage points to the first; approved event bonuses are capped at 85%. The Ledger offers at most two optional bargains per biome, each showing its real boss complication. A zero-gold character can always continue without a bargain.

## Controls

WASD or arrows move; Space dashes; E interacts; Tab opens inventory; K inspects talents; Q changes army stance; Esc pauses. Existing key rebinding and gamepad bindings remain available. Town buttons support keyboard focus/navigation and activation. Campaign talents are view-only during combat; change them at the town Trainer.

## Persistence

Campaign uses `campaign.save`; Classic uses `run.save`; account rewards use receipt-protected profile delivery. A failed write leaves the previous checkpoint and a retryable error. Pending earned rewards must deliver before replacing or abandoning a campaign. Unsupported/corrupt files are preserved, with validated backup recovery. The installed application and online releases are not updated by this feature branch.
