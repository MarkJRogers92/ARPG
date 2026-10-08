# Playing Expedition Campaign

Open this checkout in Godot 4.7.2, or launch `/opt/homebrew/bin/godot --path /Users/markrogers/ARPG`. Choose an unlocked class on the title screen, then **New Campaign**. **Continue Campaign** restores its last durable checkpoint. Classic Night, Daily and the Classic resume slot remain separate.

## The journey

The Last Lantern connects Hollow Graveyard, Frozen Wastes and Ember Rift. Preview the available connected routes, choose one, resolve its event if present, then depart. Clear exactly three short expeditions in a biome to unlock its guardian. The guardian arrives after 15 minutes; winning requires its actual death and has no new time limit.

- Hunt: survive five minutes.
- Seal the Breach: activate three beacons and survive six minutes; if seals remain, close them before the seven-minute deadline.
- Elite Hunt: the marked elite arrives at five minutes; defeat it before seven minutes.
- Cursed Cache: survive six minutes; opening the marked cache is optional and adds danger/reward.

Short success freezes combat and returns you after a two-second ritual. Death loses the attempt's unbanked gains and retains the committed route for retry. Save & Leave during combat restarts that departure checkpoint; it does not preserve partial mission gains.

## Town preparation

Campaign gear, gold, talents, specialization and up to three veterans persist. Combat XP, level-up cards, ordinary army, cooldowns and temporary effects reset on each departure. Three starting talent points grow to a maximum of 18 before the final boss; specialization unlocks after your first short clear. Visit the Trainer for free talent and specialization changes.

Use Equipment and the Market to compare exact rolled gear against what you currently wear, equip, lock favorites, mark junk, sell, buy finite stock and reforge once per item per biome. Both services show backpack space used and capacity. When it is full, sell or discard an item to free a slot before buying, claiming, or unequipping gear; the Market links to Equipment for this. You can still equip or swap gear while full. The results screen and Ferryman use the same read-only comparison, including both legendary power descriptions and Added, Increased and More modifier totals. New stock appears only after a new combat clear. Full-inventory rewards wait safely in the reward tray; resolve it before departing. No departure fee or healing bill applies.

After an expedition, the results recap shows its outcome, recorded damage causes and objectives, progression, and exact gold/talent changes. It distinguishes banked field or reward gear from prizes still reserved by the Ferryman. Choosing a town shortcut acknowledges the result first and opens the service only when that succeeds. Reports omit details that were not recorded; they do not score an overall item or build.

The route board's **Before You Depart** panel lists required blockers separately from optional preparation and opens the service for each required action. Optional talent spending, specialization, and veteran deployment never block departure. A pending reward delivery can be retried from the campaign record after leaving.

Available route previews show base gold scaled by biome before event adjustments or shard conversion. Cursed Cache may add a scaled optional bonus. Short routes award one talent point; early finales award three; the last finale awards none. A Rare prize assigned to a specific node remains reserved with the Ferryman until claimed, while the final Legendary prize is banked. Veiled routes do not reveal their reward details.

Deploy one veteran at the Crypt. Its maximum effective rank is Veteran, Hero or Legend according to the destination biome. A fallen veteran returns for a later attempt. A pledged veteran stays unavailable until its committed node is cleared.

The Ferryman reserves one settlement prize. Take it or risk it at the displayed odds: 70% for the first crossing, 45% for the second. A veteran pledge adds 10 percentage points to the first; approved event bonuses are capped at 85%. The Ledger offers at most two optional bargains per biome, each showing its real boss complication. A zero-gold character can always continue without a bargain.

## Controls

WASD or arrows move; Space dashes; E interacts; Tab opens inventory; K inspects talents; Q changes army stance; Esc pauses. Existing key rebinding and gamepad bindings remain available. Town buttons support keyboard focus/navigation and activation. Campaign talents are view-only during combat; change them at the town Trainer.

Combat guidance names the current contract action and the guardian's existing mechanic. Seal Breach uses each marked seal; Elite Hunt's marked target arrives at five minutes; the Cursed Cache is optional; Hunt extraction is automatic. Lich wards are broken by destroying raised phylacteries, the Colossus exposes itself after fracture lines strike, and the Tyrant's meteors must be led onto cinder seals. These hints explain existing rules and do not alter combat.

## Persistence

Campaign uses `campaign.save`; Classic uses `run.save`; account rewards use receipt-protected profile delivery. A failed write leaves the previous checkpoint and a retryable error. Pending earned rewards must deliver before replacing or abandoning a campaign. Unsupported/corrupt files are preserved, with validated backup recovery. The installed application and online releases are not updated by this feature branch.
