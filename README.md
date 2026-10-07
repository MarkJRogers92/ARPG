# Soulbound

A 3D survivors-like (Vampire Survivors / Soulstone Survivors style) with an ARPG
gear layer, built in **Godot 4.6** and designed from the start for **thousands of
enemies on screen**.

Pick a realm and survive its night: move, auto-attack, kill the horde, raise the
dead into your own army, level up, loot and equip gear. At dawn the realm's final
boss comes for you; kill it and you've won the night. (The title, "Soulbound",
is the `GAME_TITLE` constant in `scripts/title_screen.gd`.)

## Run it

1. Install [Godot 4.6](https://godotengine.org/download) (the standard build, no .NET needed).
2. Open `project.godot` in the editor and press **F5**.

| Input | Action |
|---|---|
| WASD / arrow keys / left stick | Move |
| Mouse / right stick | Aim (the hero faces and shoots where you point) |
| T / right stick click | Switch between mouse aim and auto-aim |
| Space / Shift / gamepad A or RB | Dash (invulnerable while dashing) |
| F11 / Alt+Enter / Ctrl+Cmd+F | Switch between fullscreen and a window |
| 1 / 2 / 3, click, Enter | Pick a level-up upgrade |
| R / gamepad X | Reroll the level-up cards (if you have rerolls) |
| Tab / I / gamepad Y | Open or close the inventory (pauses the game) |
| K / gamepad Back | Open or close the skill tree (pauses the game) |
| E / gamepad B | Use the set piece in reach (a gold ring marks usable ones) |
| Esc | Pause: music and sound volume, screen shake, damage numbers, back to the title |

Attacks fire on their own: *Magic Bolt* shoots whenever an enemy is in range, and
*Frost Aura* (an upgrade) damages everything around you. Aiming is twin-stick
style: once you move the mouse, the hero faces the cursor and shoots toward it
(a ring on the ground marks the spot) while WASD walks independently, so you can
back away while firing. The right stick aims the same way while held. Until you
touch the mouse, after you release the stick, or after pressing T, bolts auto-aim
at the nearest enemy.

The game starts fullscreen. The UI is laid out for 1280×720 and scales with the
screen (stretch mode `canvas_items`, aspect `expand`), so it stays the same size
relative to the screen at any resolution, and wider or taller screens show more
of the world. Project Settings → Display → Window has the starting mode.

The project uses the **Compatibility** renderer (OpenGL), which runs on nearly any
machine and is the one the game was tested with. If you'd like Forward+ (Vulkan),
switch it under Project Settings → Rendering → Renderer and restart the editor;
nothing in the game depends on the choice, but Forward+ has not been tried.

## Runs, realms and winning

The game opens on the **title screen**: pick a realm. A run is one **night**: the
clock at the top counts down to **dawn** (15:00). At dawn the realm's **final
boss** rises; kill it and the sun comes up, the horde burns away, and you win.
From the victory screen you can go back to the realms, play again, or carry on
in **Endless** mode (the night returns, the mid-bosses keep coming, and your
time past dawn is recorded). Winning a realm unlocks the next one; progress is
saved with the Soul Shards (`MetaProgress`).

| | The Hollow Graveyard | The Frozen Wastes | The Ember Rift |
|---|---|---|---|
| Look | mossy graves, flagstones, drifting embers, dusk to blood moon | snow, ice spikes, dead pines, falling snow, blizzard by the end | cracked ground glowing with lava, obsidian, rising embers and ash |
| Horde | ghouls, ogres, hellhounds, cultists | ice wraiths, frost trolls, ice wolves, frost witches (bolts chill you) | imps, magma brutes, hellhounds, fire cultists (fireballs burn you) |
| Hazard | graves burst open and ghouls climb out | ice shards fall, hurting and chilling everything they hit | meteors fall, hurting and burning everything they hit |
| Rule | +50% souls | chill lasts twice as long on enemies | (the hardest: enemies have the most HP) |
| Mid-boss | Ogre Warlord | Troll Chieftain | Magma Lord |
| At dawn | **The Lich King** | **The Frost Colossus** | **The Ashen Tyrant** |

Every hazard is telegraphed with a circle that fills up, and they hit the horde
too, so you can lead enemies into them. When the hero is chilled it moves at 60%
speed for a moment; when it's burning it takes damage for a second and a half.

The **final boss** slams the ground like the mid-bosses (harder and more
often), fires rings of shots in its realm's element, calls in waves of the
realm's foot soldiers around you, and gets faster below half health. With mouse
aim you can focus it; auto-aim tends to hit the soldiers in between.

A realm is pure data in `scripts/realm.gd` (ground colors and features,
scenery, lighting stages, enemy names, models and colors, bosses, hazard,
difficulty). `Realm.apply_gameplay()` runs before the enemy swarms build their
models; `apply_look()` changes the ground, scenery and light, and the title
screen uses it to preview each realm behind the menu. To add a realm, add an
entry to `REALMS` and its id to `ORDER`.

## Heroes

Pick a hero on the title screen. The Battlemage is free; the others are bought
once with Soul Shards and stay unlocked (`scripts/hero_class.gd`):

| Hero | Cost | Plays like |
|---|---|---|
| Battlemage | free | Bolts fire 10% faster and pierce one more enemy |
| Necromancer | 30 ◆ | +2 army size, +50% souls, minions +30% damage and they burst in soulfire when they fall (Lich Shroud); bolts deal 15% less |
| Pyromancer | 40 ◆ | Bolts ignite 35% of the time, +60% burn damage, and fire always spreads from the burning dead (Pyre) |
| Stormcaller | 50 ◆ | Starts with a faster, stronger Chain Lightning; dashes 30% more often and leaves lightning in its wake (Stormstride) |

Each has its own robe, cape, eye glow and starting weapon. A class is a set of stat
modifiers under the source `class` plus innate powers, the same flags that
legendary items grant, so adding one is a new entry in `HeroClass.CLASSES`.

## Night events

Every 40 to 55 seconds something worth walking to appears out of sight,
announced with a message and pointed to by an arrow at the screen edge (bosses
get arrows too). See `scripts/event_director.gd`:

- **Shrine.** Stand in its circle for a few seconds to charge it and get a 30 s
  blessing: Fury (+60% damage), Haste (+35% move and attack speed), Plenty
  (double XP and souls) or Warding (much less damage taken). The HUD shows
  the time left.
- **Treasure goblin.** A thief that runs from you for 22 s. Catch it for 3
  items, a shower of XP gems, 3 Soul Shards and a health orb.
- **Cursed chest.** Opening it summons a ring of elite guardians (more in
  later realms). Kill them all to break the curse for a Legendary and 5 Soul
  Shards.
- **Health orbs.** Half of all elites drop one (other enemies very rarely).
  Walk over it to heal a quarter of your health.

Unused events fade after 90 s.

## Sound and music

Every sound effect and all the music are made by a script,
`tools/audio/make_audio.py` (numpy, plus ffmpeg for the .ogg files): additive
and subtractive synthesis, noise, filters and a convolution reverb. To change
or regenerate them:

```
pip install numpy && python3 tools/audio/make_audio.py   # about 3 minutes
```

It writes 41 effects to `audio/sfx/*.wav` and 7 music loops to
`audio/music/*.ogg`. Each realm has two 38 s loops at 100 BPM that play in sync:
a calm one (pads, choir, bells) and a drum layer that fades in as the horde
grows and the night goes on. A boss layer comes in whenever a boss is alive.
`scripts/audio/sound.gd` plays them. Each effect has a rule (minimum gap, volume,
pitch variation, how many at once) so a thousand kills a second makes a crunchy
patter, not a wall of noise. Music and effects go through their own buses,
which the pause menu's sliders control.

## Every night is different

- **Omens** (`scripts/run_modifiers.gd`): every run rolls one rule, shown at
  the start and under the army bar. The eight are Blood Moon, Soul Tide, Glass
  Cannon, Midas Night, Swift Night, Restless Dead, Ferryman's Favor and Quiet
  Night. Each has an upside and a cost.
- **Pact of Night** (title screen, once you've conquered a realm): stack
  opt-in curses. Swarming Dark, Iron Hide, The Hunt and Elite Uprising add 1
  heat each; Bleak Night and Wrath of Dawn add 2. Each heat point adds +25% to
  the Soul Shards earned.
- **Bestiary** (title screen): kills of each enemy kind across every night.
  100, 1,000 and 5,000 kills earn a star, and every star is +1% damage, for
  good.
- **Daily Night** (title screen): today's realm, omen and seed are the same
  for every run today. Your best kill count is kept.
- **Run report** on the end screen: the share of damage dealt by each weapon,
  the army, reactions and burning, plus the omen and heat.

The permanent save is written to a temporary file and swapped in, with the
previous save kept as a backup; a broken save falls back to it.

## Weapons, paths and finales

**Reaping Scythe** (level-up card): thrown toward the nearest enemy (or your
aim), it spins out about 8 m and flies back to wherever you are. It cuts each
enemy once on the way out and once on the way back, and the return cut does
1.5x. Walking reshapes the second cut.

**Funeral Bell** (level-up card): every kill within 11 m adds a toll. At 30
tolls (fewer with ranks) it rings: a shockwave around you that hurts
everything in reach and hurls the horde back. Its own kills don't refill it.

**Paths:** at level 10 each hero chooses one of three paths for the night,
shown as cards (`scripts/specializations.gd`):

| Hero | Paths |
|---|---|
| Battlemage | Arcane Sniper (pierce and range, one bolt fewer) · Artillery (+2 bolts, weaker) · Spellblade (Frost Aura, speed, weaker bolts) |
| Necromancer | Lord of Champions (stronger, fewer minions) · Endless Legion (+4 army, frailer) · Grim Reaper (the Scythe, smaller army) |
| Pyromancer | Wildfire (ignite and burn) · Detonator (Nova and reactions, less health) · Frostfire (chill and melt) |
| Stormcaller | Arc Master (+4 jumps) · Thunderstrike (heavy lightning and the Funeral Bell) · Tempest (dash, speed) |

**Final bosses** (`scripts/final_mechanics.gd`) each pose one problem, on top
of the shared slams, shot rings and summons:

- **The Lich King:** at 66% and 33% health he wards himself and raises three
  phylacteries around you. He takes no damage until they're shattered.
- **The Frost Colossus:** every 12 s, four lines of ice race out from him
  (step off them). Then he's exposed for 3 s and takes double damage.
- **The Ashen Tyrant:** four cinder seals take 75% of his damage. He calls
  meteors down on you; stand by a seal so a meteor breaks it.

**Feel:**
- Elite kills and bell tolls land a tiny hit-stop, and the final kill drops
  into slow motion.
- Bosses arrive with a title card.
- Killing fast builds **Frenzy** (shown by the kill count): three tiers of
  faster bolts and movement that drain away when you stop.

## The Ferryman's bargains

A spectral boatman who trades in souls and risk (`scripts/ferryman.gd`,
`scripts/wager_panel.gd`). He appears twice a night (around 2:30 and 7:00)
near the hero; an arrow points the way. Walk up, press E, and his table
opens (the game pauses):

- **The prize:** a Rare item for a random slot. **Take it**, or **wager it**:
  70% it becomes a Legendary, 30% it's lost to the river. Win, and you may
  wager again: 45% for a second Legendary, 55% to lose both. You can take
  your winnings at any point.
- **Pledge a minion:** +10% on the first coin. It leaves the army and comes
  back after 60 s, win or lose.
- **Borrow power:** +50% damage for 90 s. 45 s later a **Debt Collector**
  comes for you: a tough, fast elite that seizes a minion every time it
  touches you. Kill it and they all come back, plus its guaranteed loot.

Mid-bosses come with his **side bet**: slay the boss within 45 s (a countdown
under the timer) for a Legendary and 10 Soul Shards.

Every outcome uses the Ferryman's own random stream, is rolled the moment you
choose (the spinning coin is just for show), and pays out once.

**The Ferryman's Obol** (a level-up card) flicks a heavy coin at the nearest
enemy. It ricochets between enemies, 4 hits at first. Each hit has a 20% chance
to land heads: a gold flash, double damage and one more bounce.

## Landmarks you can use

Some set pieces do something (`scripts/landmarks.gd`). Usable ones near the
hero get a gold ring. In reach, a prompt at the bottom of the screen says
what it does, and E (gamepad B) uses it. Each works once; its identity is
its kind and position, so walking away and back doesn't reset it.

| Set piece | Use |
|---|---|
| Bell gibbet, wind chime, chained gong | Ring it: 4+ elite champions rise around it; kill them all for two good items and 6 Soul Shards |
| Soul altar | Sacrifice a minion: +12% damage for the night (stacks per altar) |
| Stone well, frozen pond | Toss in 5 run shards: a Rare item, a full heal, a blessing, +10 shards, or nothing |
| Forge | 8 run shards: reforge your weapon at the same rarity, 3 item levels higher |
| Cauldron | 6 souls: brew a 45 s blessing |
| Fishing hut | Rest: heal to full |
| Forbidden tome | +1 skill point, -8% max HP for the night |

## The army's roles

A raised minion keeps a piece of what it was (`Army.role_of`):

| Role | From | Fights |
|---|---|---|
| Brawler | most enemies | cleaves around its target |
| Caster | ranged enemies, gravediggers | soul bolts from 7 m |
| Bulwark | big enemies (brutes) | every 3 s a ground slam that hurls the horde back |
| Skirmisher | fast enemies, lancers | darts in with quick strikes |
| Tyrant | bound bosses | a crushing slam on a long cooldown |

Damage per second is the same across roles; the rhythm and reach differ.

## Specialist enemies

- **Lancers** (Bone Lancer, Rime Lancer, Hellspear) stop and show a red line
  along their path, which grows as the wind-up runs out. Then they charge
  straight down it for 14 damage and recover. Sidestep the line and punish
  the recovery; a Lancer that hits a wall is stunned longer. At most six wind
  up at once.
- **Gravediggers** (Gravedigger, Frozen Sexton, Ash Sexton) hang back about
  8 m from the hero. Every ~6 s they raise three fresh enemies from the
  ground and swallow the uncollected souls nearby. Kill them first.

## Imported scenery

52 hand-made Blender props (`assets/environment/arpg_pack/`) share the world
with the code-built scenery, about 17 per realm. A 53rd, the Treasure Chest,
is the cursed-chest event's model. `AssetProps` (`scripts/visual/asset_props.gd`)
loads each GLB once and finds its mesh. It bakes in any node transform and
copies the surfaces into an ArrayMesh with kit-shader materials, so the props
share the world's lighting, rim light and fog. `WorldDecor` draws them with one
MultiMesh per kind, like every other prop. Sizes are as authored (1 unit = 1 m),
and fronts face the camera.

- **Glow.** Opaque surfaces never glow. Emissive surfaces glow evenly at UV.x
  0.72 strength. UV.x isn't used, because these exports put non-zero UV.x on most
  opaque vertices too.
- **Placement.** Each realm's `props` density chooses the kinds. Imported
  kinds use their own seed per chunk and kind, so they never move the
  code-built props, and the same chunk always grows the same scenery.
- **Set pieces.** At most one per chunk, near its middle, in roughly a third
  of the chunks. They keep at least 12 m plus their footprint from the start,
  and code-built props never grow inside one.
- **Smaller pieces.** They stay inside their chunk by their footprint, never
  overlap, and keep the start clear.
- **Collision** (`scripts/obstacles.gd`). Walls, gates and big set pieces are
  solid: a few circles fitted to their ground footprint (see the table). The
  hero and every enemy are pushed out of them and slide around, toward their
  goal and away from the rest of the piece, so a horde flows around a wall
  instead of piling up behind it. Arches and the skull gateway keep their
  openings walkable. Bolts, enemy shots, loot, gems and the spectral army pass
  through. Events spawn clear of solid scenery.
- **Cost.** A flag grid with 1 m cells means most enemies pay one array read.
  Hordes of 3,000+ check on alternate frames per enemy. Measured enemy step,
  with and without the obstacles of a busy view: +0–1 ms at 1,000–2,000 enemies,
  about +3 ms at 8,000.
- **Occlusion.** When the hero walks behind a set piece, a dithered window
  opens in it so the hero stays visible (`shaders/kit_landmark.gdshader`;
  shadows stay whole).
- **Ambient effects.** Glowing pieces give off motes near the hero: soul
  wisps in the graveyard (violet from the crystals), embers in the rift.

Not imported:
- Stone_Bridge_Span and Stone_Stairs look walkable, but the world has no height.
- Coin_Cache looks like loot you can't pick up.

The code-built pillar, crystal, grave and ash tree are thinner where an
imported counterpart shares the job.

| Kind | Asset (pack) | Realm | Role | Collision | Glow motes |
|---|---|---|---|---|---|
| `rune_gravestone` | Rune Gravestone (01) | Graveyard | prop | walk-through |  |
| `soul_brazier` | Soul Lantern Brazier (01) | Graveyard | prop | walk-through | yes |
| `ruined_pillar` | Ruined Pillar (01) | Graveyard | prop | walk-through |  |
| `crystal_cluster` | Violet Crystal Cluster (01) | Graveyard | prop | walk-through | yes |
| `tome_pedestal` | Ancient Tome Pedestal (02) | Graveyard | prop | walk-through | yes |
| `barrel` | Barrel (02) | Graveyard | prop | walk-through |  |
| `crate_stack` | Crate Stack (02) | Graveyard | prop | walk-through |  |
| `weapon_rack` | Weapon Rack (02) | Graveyard | prop | walk-through |  |
| `offering_bowl` | Offering Bowl (02) | Graveyard | prop | walk-through |  |
| `sarcophagus` | Sealed Sarcophagus (03) | Graveyard | prop | walk-through |  |
| `prison_cage` | Iron Prison Cage (03) | Graveyard | prop | walk-through |  |
| `gravedigger_bench` | Gravedigger Bench (05) | Graveyard | prop | walk-through |  |
| `lantern_post` | Procession Lantern Post (05) | Graveyard | prop | walk-through | yes |
| `mausoleum` | Graveyard Mausoleum (04) | Graveyard | set piece | 5 circles |  |
| `soul_altar` | Soul Altar (01) | Graveyard | set piece | 1 circle | yes |
| `broken_archway` | Broken Archway (02) | Graveyard | set piece | 2 circles |  |
| `ruined_wall` | Ruined Wall (02) | Graveyard | set piece | 3 circles |  |
| `ruin_corner` | Ruin Corner (02) | Graveyard | set piece | 5 circles |  |
| `portcullis` | Portcullis (02) | Graveyard | set piece | 3 circles |  |
| `guardian_statue` | Broken Guardian Statue (02) | Graveyard | set piece | 1 circle |  |
| `soul_obelisk` | Soul Obelisk (02) | Graveyard | set piece | 1 circle | yes |
| `stone_well` | Abandoned Stone Well (03) | Graveyard | set piece | 1 circle |  |
| `ritual_door` | Sealed Ritual Door (03) | Graveyard | set piece | 3 circles | yes |
| `iron_fence` | Crooked Iron Fence (04) | Graveyard | set piece | 5 circles |  |
| `bell_gibbet` | Hanging Bell Gibbet (04) | Graveyard | set piece | 3 circles |  |
| `funeral_wagon` | Fallen Funeral Wagon (04) | Graveyard | set piece | 2 circles |  |
| `ossuary_wall` | Ossuary Niche Wall (05) | Graveyard | set piece | 3 circles |  |
| `winged_memorial` | Winged Memorial (05) | Graveyard | set piece | 1 circle |  |
| `snow_boulder` | Snowbound Boulder (03) | Frozen | prop | walk-through |  |
| `frosted_pine` | Frosted Pine (03) | Frozen | prop | walk-through |  |
| `ice_stalagmites` | Ice Stalagmite Fan (03) | Frozen | prop | walk-through |  |
| `supply_tripod` | Suspended Supply Tripod (05) | Frozen | prop | walk-through |  |
| `wind_chime` | Icy Wind Chime (05) | Frozen | prop | walk-through |  |
| `ice_arch` | Glacial Ice Arch (03) | Frozen | set piece | 2 circles |  |
| `watchtower` | Frozen Watchtower Ruin (04) | Frozen | set piece | 4 circles |  |
| `sled` | Abandoned Sled (04) | Frozen | set piece | 2 circles |  |
| `ribcage` | Giant Ribcage Half Buried Snow (04) | Frozen | set piece | walk-through |  |
| `frozen_pond` | Frozen Pond Rim (04) | Frozen | set piece | walk-through |  |
| `fishing_hut` | Ice Fishing Hut (05) | Frozen | set piece | 2 circles |  |
| `whale_skull` | Whale Skull (05) | Frozen | set piece | walk-through |  |
| `obsidian_outcrop` | Obsidian Outcrop (03) | Ember | prop | walk-through |  |
| `brimstone_vent` | Brimstone Vent (03) | Ember | prop | walk-through | yes |
| `ashen_tree` | Ashen Tree (03) | Ember | prop | walk-through | yes |
| `basalt_columns` | Basalt Organ Columns (03) | Ember | prop | walk-through |  |
| `scorched_banner` | Scorched Banner (05) | Ember | prop | walk-through |  |
| `skull_gateway` | Demon Skull Gateway (04) | Ember | set piece | 2 circles | yes |
| `forge` | Forge Anvil Station (04) | Ember | set piece | 3 circles | yes |
| `cauldron` | Suspended Cauldron (04) | Ember | set piece | 1 circle | yes |
| `siege_barricade` | Charred Siege Barricade (04) | Ember | set piece | 4 circles | yes |
| `minecart` | Ore Minecart (05) | Ember | set piece | 2 circles | yes |
| `furnace` | Cracked Furnace (05) | Ember | set piece | 1 circle | yes |
| `chained_gong` | Chained Gong (05) | Ember | set piece | 3 circles | yes |

```
# In-game shots (needs a display): before/after at a set piece, the start, a
# late-night horde, the hero behind a set piece, and a gallery of every kind.
for r in graveyard frozen ember; do for s in 1_before 1_after 2_start 3_crowd_late \
    4_behind 5_gallery_a 5_gallery_b; do
  xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --fixed-fps 60 \
      -s tools/asset_showcase.gd -- shots $r $s; done; done
```

To add another asset:
1. Copy its GLB into its pack folder.
2. Add an entry to `AssetProps.KINDS` (scale, yaw, set piece or not,
   footprint, shadow, collision circles, mote color).
3. Append its name to the end of `Models.PROPS`.
4. Give it a density in its realm.

The tests check its size against the catalog, its surfaces and glow, its
collision against its bounds, and its placement.

## What makes it different

Three systems feed each other: your **army** comes from the horde, **elements**
combine into reactions, and **legendary powers** bend the rules of both.

### The Soul Army

Kills sometimes leave a **soul** (a pale blue crystal; 6% of kills at first).
Each soul remembers what kind of enemy it came from. Gather `soul_cost` souls
(12 at first) and the kind most of them came from **rises as a spectral minion**
that fights for you. You start with room for 2 (see "SOULS / ARMY" under your
health).

- Minions hunt the enemy nearest to them (within reach of you), cleave
  everything around their target, and fall back to your side when there's
  nothing to fight. Tougher kinds make tougher minions: a spectral Brute hits
  harder and lasts longer than a spectral Runner.
- An **elite's soul** always drops and raises a glowing champion straight away,
  pushing out your newest common minion if the army is full.
- A slain **Ogre Warlord's soul** binds the Warlord itself to you (one at a time).
- Level-up cards: **Soul Legion** (+1 army size, stronger minions) and **Soul
  Harvest** (more souls, fewer needed per minion).
- The army is `scripts/army.gd`; minions use the enemy models with a ghostly
  shader (`spectral` in `enemy.gdshader`).

### Elements and reactions

| Status | Comes from | Effect |
|---|---|---|
| Chill | Frost Aura, bolts with **Frostbite** | half speed (bosses three-quarters) |
| Shock | Chain Lightning, Stormcaller bolts, Stormstride | takes 25% more damage from everything else |
| Burn | bolts with **Kindling** | damage over time; 35% chance to spread to neighbors on death |

| Reaction | When | Effect |
|---|---|---|
| **Shatter** | lightning hits a chilled enemy | an ice burst damages and chills everything around it |
| **Melt** | fire hits a chilled enemy | that hit deals 2.5x |
| **Overload** | fire hits a shocked enemy, or lightning a burning one | an explosion |

Chilled enemies are tinted icy blue, shocked ones flicker violet, burning ones
glow with embers, and elemental bolts take their element's color. All damage
goes through `Elements.hit()` (`scripts/elements.gd`); area reactions are queued
and run once a frame, after the weapons.

### Legendary powers

Every Legendary item rolls a named power for its slot, on top of its affixes:

| Slot | Power |
|---|---|
| Weapon | **Hydra**: bolts split into three when they kill. **Stormcaller's**: bolts shock (+1 lightning jump). |
| Helm | **Endless Winter**: grants Frost Aura (+30% radius), bolts chill 20%. **Eye of the Storm**: grants Chain Lightning, +2 jumps, strikes faster. |
| Chest | **Shroud of the Lich**: +1 minion, minions explode in soulfire when they fall. **Dragonscale**: bolts ignite 25%, +50% burn damage. |
| Boots | **Stormstride**: dashing leaves lightning in your path. **Blinkfire**: 40% shorter dash cooldown, every dash releases an Arcane Nova. |
| Amulet | **Heart of Storms**: every 6th volley releases a free Arcane Nova. **Soul Lantern**: twice the souls, minions need 4 fewer. |
| Ring | **Ring of Embers**: 15% of hits ignite, reactions +50%. **Bloodseal**: crits heal 1 HP, +5% crit. |

Powers are data (`ItemData.POWERS`): stat modifiers apply like affixes, and
flags are checked with `stats.powers` where the effect lives. Picking one up
announces its power.

## Abilities, enemies and progression

**Weapons.** *Magic Bolt* is always on. The level-up cards can add:

- **Frost Aura:** damages everything close to you.
- **Chain Lightning:** strikes the nearest enemy and jumps to the next closest
  ones (4 at first, +1 per rank), losing 15% damage per jump.
- **Spirit Blades:** two blades (+1 per rank) circle you and cut what they pass
  through; each blade hits a given enemy at most every 0.3 s.
- **Arcane Nova:** every 4 s, a blast damages everything around you and throws
  it back.

**Dash** (Space) is a short burst of speed with a 3 s cooldown (the bar under
your health). Nothing can hurt you mid-dash: contact damage, fireballs and boss
slams all pass through.

**Enemies.**

- *Grunts* (ghouls), *Brutes* (horned ogres) and *Runners* (hellhounds), as before.
- **Cultists** (from 2:00) stop at range and throw slow fireballs. At most 80 are
  alive at once, so the late game can't turn into a bullet storm.
- **Elites** are glowing gold versions of any type: 7x HP, 8x XP, a guaranteed
  item and 2 Soul Shards. They come at a steady rate (1.5 a minute at first,
  growing to 5) rather than as a share of spawns, so the huge late-game spawn
  rate doesn't flood the field with them.
- **The Ogre Warlord** arrives every 3 minutes, each one tougher, with a health bar
  at the top of the screen. It can't be knocked back, and every few seconds it
  marks the ground under you with a red circle that fills up and then slams.
  Step out or dash through. It drops three good items, a big XP gem and 15+ Soul
  Shards. The bosses and their slam are in `boss_director.gd`.

**Soul Shards and the Altar.** Shards come from elites and bosses, plus a bonus
at the end of each run (2 per minute survived, 1 per 150 kills). On the death
screen, the **Altar of Souls** spends them on permanent upgrades: more HP,
damage, speed, XP, magic find and regen, and **Insight** (level-up rerolls each
run). They're saved in `user://meta.save` (`meta_progress.gd`; the costs are
there too). To start over, delete that file: on macOS it's in
`~/Library/Application Support/Godot/app_userdata/ARPG/`.

**Feel.** Damage numbers (crits are big and gold; only one in five ordinary hits
shows a number, to keep it readable), screen shake on big hits, real light from
explosions, dash trails, drifting embers, and a sky that changes over the run:
warm dusk, cold moonlight around 4:00, a blood moon from about 9:00, turning
redder while a boss is alive (`visual/atmosphere.gd`). Shake can be turned off
with `shake_enabled` on `CameraRig`.

## The look

Everything you see is built in code: there are no models, textures or icons on
disk. `scripts/visual/models.gd` assembles each model (the hooded hero, the three
enemy types, every item base, bolts, XP crystals and the scenery) out of
primitive shapes with `MeshKit`, which merges them into one vertex-colored mesh.
A part can glow (stored per vertex), and the shaders in `shaders/` do the rest.

- **Enemies:** Grunts are hunched ghouls, Brutes are horned ogres with clubs,
  Runners are burning hellhounds. Each type is still one MultiMesh. The walk
  cycle (swinging legs, bob, sway), the hit flash and the rim light all run in
  `enemy.gdshader`, so the CPU only writes position, facing and a flash value per
  enemy. Soft blob shadows under the horde are a second MultiMesh fed the same
  buffer; real shadow maps for thousands of enemies would cost far more.
- **Hero:** holds the weapon you have equipped (staff, wand or orb, with its gem in
  the item's rarity color), bobs and leans as it walks, thrusts the weapon on
  every volley, and carries a small light.
- **Loot:** each drop shows its own item model floating over a glow ring in its
  rarity color. The inventory renders the same models into icons and shows the
  selected item turning in a preview (see `visual/item_icons.gd`).
- **World:** the ground shader paints grass, dirt and mossy flagstone plazas in
  world space. `WorldDecor` scatters rocks, grass, dead trees, graves, ruined
  pillars, bones, glowing mushrooms and crystals in chunks around the hero;
  each chunk's props come from a seed, so the world stays the same when you walk
  back. Props are decoration only: nothing collides with them.
- **Effects:** kills, bolt hits (bigger and orange on crits), pickups and level-ups
  throw particles from `FxSwarm`, another array-simulated MultiMesh. Glow (bloom),
  fog and a vignette that reddens while you take damage finish the picture.
- **UI:** a shared bronze-on-dark theme (`ui_style.gd`), illustrated level-up cards
  with rank pips, and themed inventory and skill tree screens.

To change the art, edit the colors and shapes in `models.gd` (enemy skins also
follow each swarm's `color` export), the uniforms at the top of each shader, or
the `density` table on the `Decor` node.

## Gear and loot

- **Six slots:** weapon, helm, chest, boots, amulet, ring.
- **Four rarities:** Normal, Magic (1-2 affixes), Rare (3-4), Legendary (5, rolled
  in the top half of each range). Higher rarities are rarer; **magic find** shifts
  the odds.
- **Affixes** come from a data table (`scripts/items/item_data.gd`). Each one lists
  the slots it can roll on, a value range, and a weight. Some only appear on Rare+
  (pierce) or Legendary (extra bolts).
- **Item level** follows your level at half rate. Flat stats (HP, armor, flat
  damage) scale with it fully; percentage stats at about a third of that rate;
  magic find not at all.
- **Drops:** each enemy type has a `loot_chance` and `loot_quality` (brutes drop
  more and better). A token budget (`LootManager.drops_per_minute`, default 3)
  caps the total, so a huge late-game kill rate can't flood the ground.
- **Pickup:** walk over loot. It's worn straight away if the slot is empty,
  otherwise it goes to the 24-slot backpack. A full backpack leaves it on the
  ground. Magic and better drops have a light beam (taller for better rarities);
  Rare and better show their name.
- **Inventory screen (Tab):** worn gear, backpack (▲ marks likely upgrades), the
  selected item compared against what you wear, live stats, equip / unequip /
  discard, and "equip all likely upgrades". The upgrade hint is a rough score
  from `ItemData.STAT_INFO`, not a promise.

## Skill tree

You earn a **skill point every 2 levels** (`Player.skill_point_every_levels`; 0 turns
it off) and spend them in a node graph (press K). It sits alongside the level-up
cards: cards are the quick run-by-run picks, the tree is where you steer a build.

- **Four branches** grow from the central Awakening node: **Offense** (bolts,
  crits), **Aura** (unlocked by the Frostbound node), **Defense** (HP, armor,
  regen) and **Utility** (speed, pickup, XP, luck). 27 nodes plus the center.
- **Three tiers:** small nodes cost 1 point, notables 2, keystones 3. Every
  keystone has a real downside, such as Arcane Barrage (+2 bolts, 30% less bolt
  damage) or Juggernaut (+50% max HP and +30 armor, 10% slower).
- **Rules:** you can buy a node when you can pay for it and it's linked to one you
  own. Right-click (or Backspace) refunds a node unless that would cut other nodes
  off from the center, so you can always peel the tree back from its tips. Reset
  refunds everything and is free.
- Buying everything costs 41 points. The damage-first bot earns about 34 in ten
  minutes (level ~69), so even a strong run has to leave some of the tree unbought,
  and weaker runs get far fewer. The choices matter.
- Nodes are data (`scripts/skills/skill_data.gd`) and add stat modifiers under the
  source `skill:<id>`, so they need no stat code.

### How stats work

`PlayerStats` holds base values plus modifiers tagged by source, and
`recalculate()` rebuilds the effective numbers:

```
effective = (base + sum(ADD)) * (1 + sum(INCREASED)) * product(1 + MORE)
```

Gear adds ADD / INCREASED modifiers under `gear:<slot>`, skill nodes add theirs under
`skill:<id>`, and level-up upgrades add MORE modifiers under `upgrade`. Removing a
source is exact, so equipping, swapping, unequipping and refunding can't drift. The level-up pool is data too
(`scripts/upgrades.gd`).

## How it handles thousands of enemies

Godot nodes, physics bodies and per-node `_process` calls don't scale to
thousands of enemies. So enemies, projectiles and XP gems are **not nodes**:

- Each is a row in flat typed arrays (`PackedVector2Array`, `PackedFloat32Array`, …),
  simulated in one tight loop.
- Each swarm is drawn by **one `MultiMeshInstance3D`**. Every frame the whole
  instance buffer (transform, color and custom data, 20 floats each) is uploaded
  in a single call. Animation happens in the shaders.
- There is no physics body per enemy. Collisions (bolt hits, aura, touching the
  player) use a **spatial hash** rebuilt every frame.
- The horde spreads out using a **density push**: each enemy reads the occupancy
  of its own cell and its four neighbors, a constant cost however packed the
  crowd is. Enemies in a full cell stop advancing, so the horde queues up
  instead of collapsing into one pile.
- Enemies that fall too far behind the player are recycled to the spawn ring, which
  keeps the crowd dense around you without spawning more.

Positions live on the ground plane as `Vector2(x, z)`.

### Frame order (`scripts/main.gd`)

```
player moves
-> each enemy swarm: flush dead, rebuild hash, spread, chase, upload buffer
-> weapons fire, projectiles hit enemies, aura ticks
-> contact damage to the player
-> gems magnetize and get collected, loot is picked up
-> wave director spawns
```

Enemy deaths are only *marked* during the frame (and the XP gem and loot roll
happen immediately); the row is removed at the start of the next swarm step. That
keeps every index stable for all the queries in between. If you add something
that queries enemies, run it after the swarm `step()` and don't hold indices
across frames.

### Measured performance

Script time per frame, measured headless on a 4-core cloud container (so treat it
as a relative number, not a promise about your machine). This is GDScript only and
**excludes GPU rendering**. These were measured on the swarm and game loop before
the gear and loot layer was added; that layer adds a handful of nodes and some
per-kill work, but it has not been re-benchmarked.

| Enemies | Swarm update | Full game loop |
|---|---|---|
| 1,000 | 1.6 ms | |
| 4,000 | 4.6 ms | |
| 8,000 | 7.5 ms | 7.8 ms |
| 16,000 | 13.7 ms | |

The 60 fps budget is 16.7 ms. The cost stays flat as the crowd packs tighter.
The visual overhaul (enemies turning to face you, hit flashes, a wider instance
buffer and blob shadows) added roughly 10-20% to the swarm update in a
before/after run of `bench_swarm.gd` on the same container (8,000 enemies: 4.4 ms
before, 4.9 ms after).

On the GPU side, enemy models are kept coarse: about 300 triangles for a Grunt
or Runner and 520 for a Brute, so a full late-game horde is a couple of million
triangles a frame. That's fine for a dedicated GPU; on a weak integrated one, the
first thing to try is lowering `MeshKit.max_segments` for enemies in
`Models.enemy()`.
Visuals were checked by rendering with a software GL driver, which is far too slow
to say anything about real GPU performance, and Forward+ itself was not exercised
there. Run `tools/bench_swarm.gd` on your own machine and check the in-game FPS
counter (bottom left).

If you outgrow this: parallelize the per-enemy loop with `WorkerThreadPool`, move
the hot loop to C# or a GDExtension, or step far-away enemies less often.

## Balance

`tools/balance_bot.gd` plays whole runs headless with a bot that kites crowds,
collects gems, takes upgrades by a build policy (`greedy`, `tank`, `random`) and
manages gear. `tools/balance.sh` runs many seeds in parallel and prints
per-minute averages. The bot is a consistent yardstick for comparing settings,
**not** a stand-in for a person.

Current defaults in the Hollow Graveyard, 6 seeds each, 10 minutes of game
time, with Cultists, elites, bosses, the Soul Army and elements. The bot now
steps out of telegraphed circles (hazards and slams) the way a person would. The bot spends skill points by policy (damage-first, or random
picks). It never dashes or steps out of a boss slam, so a person has an easier
time than these numbers suggest:

| Policy | Survived | Level at 10 min | Items found |
|---|---|---|---|
| greedy (damage-first build, plus Soul Legion) | 5 of 6 reached 10:00 (one died at the first boss, 4.0 min) | ~70 | ~30 |
| random upgrades and nodes | 5 of 6 reached 10:00 (one died at 7.4 min) | ~70 | ~30 |

**Whole nights** (19 minutes of game time, 4 seeds, the bot dodging telegraphs):

| Realm | Damage-first bot | Random picks |
|---|---|---|
| The Hollow Graveyard | wins 4 of 4 (final boss falls 50-70 s after dawn) | survives 10 min in 3 of 6 |
| The Frozen Wastes | wins 2 of 4 | dies at 4-5 min |
| The Ember Rift | survives 10 min in 2 of 4 | survives 10 min in 1 of 4 |

The later realms are meant to be a step up: by the time you reach them you'll
have Altar upgrades, which the bots don't. (The Frozen and Ember numbers come
from slightly earlier tuning: the Frozen run before the hero's chill from witch
bolts was shortened, and the Ember run at 10 minutes.) The first version of the
hazards aimed half of all ice shards and meteors at where you were heading,
and with no dodging the bot died at 2-5 minutes in both realms.

Before the Soul Army and elements, greedy survived 6 of 6 and random 3 of 6, so
mixed builds got noticeably stronger. The first cut of the army was too fragile
(minions died in seconds at the front and the army rarely passed 2): minions now
have 90 base life and take a third of the horde's contact damage. If runs feel
too easy, lower `hp_squared_seconds` (enemy HP ramps up sooner) on the
WaveDirector or trim `minion_damage` in `PlayerStats.BASE`.

The first version of this update let Cultists build up to about 300 alive (with
a share of 0.12 of all spawns), and the damage-first bot died in 3 of 4 runs.
Without Cultists it survived every run; without bosses or elites it still died.
Capping them at 80 alive with weaker, slower shots brought survival back to
where it was. Elites used to be a share of spawns and dropped up to 400 items
in a run; at a steady rate it's back to 30-40.

Before these enemies, with 4 seeds: greedy 4 of 4 survived (level ~69, enemies
alive ~360 / ~890 / ~540 at minutes 3 / 5 / 10), random 2 of 4 (died at 4.8 and
5.1 min).

Before the skill tree the same bot had ~1,290 enemies alive at minute 10, and
every random-pick run died at 4.0 to 5.3 minutes, so the tree adds real power:
it thins a strong build's late game by about 40% and gives weak builds a safety
net. Taking a point every 3 levels instead brings the random-pick runs back to
dying at 4.4 to 5.2 minutes. A 14-minute damage-first run is back up to about 910
enemies by the end and still rising. An earlier 20-minute run without the tree
reached roughly 4,700 to 5,000 enemies, so if you want a bigger late-game horde,
raise `rate_acceleration` on the WaveDirector.

What shaped the curve, from the bot's own data:

- With no starting regeneration the hero bled out from chip damage around minute 4,
  so the opening is 2 bolts and 1.5 HP/s regen.
- Enemy HP scaling that ramped too early killed every build at minutes 3-5; it now
  stays gentle early (linear term over 600 s) and has a squared term so a maxed
  build is still pushed later.
- Spawn rate accelerates (`rate_acceleration`) so the late game fills up.
- Every upgrade maxes out at level ~52, so later levels quietly heal instead of
  opening a menu with nothing to pick.

Expect to retune. Everything is an export on the `WaveDirector`, the swarms and
`Player` (see Tuning), and the bot can override them without editing files:

```sh
tools/balance.sh -g /path/to/godot -s "1 2 3 4" -p "greedy random" -m 10 \
    director.rate_acceleration=0.0004 Brutes.spawn_share=0.3 base.regen=2
# -f 30 simulates at 30 fps, about twice as fast (43 s vs 91 s for 4 ten-minute
# runs here). I haven't compared its results against 60 fps, so only use it to explore.
```

## Tests

```sh
godot --headless --path . -s tools/tests.gd                      # unit tests
godot --headless --path . -s tools/ui_test.gd                    # drives the real inventory screen
godot --headless --path . -s tools/skill_ui_test.gd              # drives the real skill tree screen
xvfb-run godot --path . --fixed-fps 60 -s tools/aim_test.gd     # mouse aim, T toggle, right stick (needs a display)
godot --headless --path . --fixed-fps 60 -s tools/smoke_test.gd  # bot playthrough, exit 0 = ok
godot --headless --path . -s tools/bench_swarm.gd                # simulation cost, 1k..16k enemies

# Screenshots of play, the level-up cards, inventory and skill tree. Needs a
# display (not --headless); on a server, wrap it in xvfb-run.
godot --path . --fixed-fps 60 -s tools/screenshot.gd -- shots 30          # 30 s of play
godot --path . --fixed-fps 60 -s tools/screenshot.gd -- shots 5 crowd     # start in a big horde
```

- `tests.gd` covers the modifier math, upgrades, item generation across every
  slot / rarity / item level, the rarity distribution (with and without magic
  find), serialization, inventory and stat syncing, loot drops and the drop
  budget, the wave director's spawn schedule, and the skill tree (graph validity,
  allocate and refund rules, exact stat restore, serialization, earning points).
  Exit code 0 means everything passed.
- `tests.gd` also checks every realm (complete data, nodes and models that
  exist, props, lighting, hazards) and realm progress (unlocking in order,
  Endless records, saving).
- `tests.gd` also covers the Soul Army (souls, raising by majority kind, the cap,
  elite champions, refilling from banked souls), elements and reactions (chill,
  shock bonus, Melt, Shatter, Overload, burning), legendary powers (every slot
  has some, names, serialization, mods and flags when worn and removed), the new
  weapons' upgrades, Soul Shards and the Altar
  (buying, costs, max ranks, saving and loading, applying at run start), elites,
  knockback, enemy fireballs and dash invulnerability.
- `ui_test.gd` and `skill_ui_test.gd` open the real screens with the real input
  actions, check the pause, and click through equipping, discarding, allocating,
  refunding (including the refusals), resetting and closing.
- `aim_test.gd` moves the real cursor around the game window and checks that the
  hero faces it, bolts follow it while walking the other way, T switches to
  auto-aim and back, and the right stick takes over while held.
- `smoke_test.gd` runs a dumb bot for a minute (or `-- 600` for ten); one minute
  of game time takes about a second.

After adding scripts, open the project in the editor once (or run
`godot --headless --path . --import`) so Godot generates their `.uid` files, and
commit those too.

## Project layout

```
scenes/
  main.tscn            The game: environment, ground, scenery, camera, swarms, loot, HUD
  player.tscn          The hero (CharacterBody3D), its model, aura and ground ring
scripts/
  main.gd              Game loop, owns update order, level-up flow
  enemy_swarm.gd       A horde of one enemy type (one node per type)
  projectile_swarm.gd  Bolts, pierce, hit memory
  gem_swarm.gd         XP gems and magnet pickup
  fx_swarm.gd          Hit, death, pickup and level-up particles
  spatial_hash.gd      Grid hash: radius queries + density push
  multimesh_util.gd    MultiMesh setup / buffer helpers
  player.gd            Movement, aiming, dash, Magic Bolt, Frost Aura, XP, levels
  abilities/           Chain Lightning, Spirit Blades, Arcane Nova
  enemy_shots.gd       Fireballs from ranged enemies
  boss_director.gd     When bosses come, and their telegraphed slam
  meta_progress.gd     Soul Shards and the Altar's permanent upgrades (saved)
  juice.gd             One place to trigger particles, numbers, flashes, shake
  army.gd              The Soul Army: souls, raising minions, minion AI
  elements.gd          Elemental hits, statuses and reactions
  realm.gd             The realms: look, enemies, bosses, hazards, difficulty
  hazard_director.gd   Each realm's telegraphed hazard
  obstacles.gd         Solid scenery as circles: push-out and sliding for hero and enemies
  title_screen.gd      Hero and realm select (previews each realm behind the menu)
  hero_class.gd        The playable heroes: looks, weapons, stats, powers
  event_director.gd    Shrines, treasure goblins, cursed chests, health orbs
  pause_menu.gd        Esc menu: volumes, shake and damage-number toggles
  audio/sound.gd       Sound effects (pooled, rate-limited) and layered music
  altar_panel.gd       The Altar of Souls, on the title, death and victory screens
  player_stats.gd      Base values + modifiers -> effective stats
  upgrades.gd          The level-up pool (data + apply())
  wave_director.gd     Spawn rate / HP curves and enemy mix over time
  hud.gd               HUD, level-up cards, toasts, game over (built in code)
  inventory_screen.gd  The Tab screen (built in code)
  ui_style.gd          Shared UI theme, panels, bars, labels
  camera_rig.gd        Smooth follow camera
  items/
    item_data.gd       Slots, rarities, bases, affixes, text and scoring
    item.gd            One piece of gear (plain data)
    item_generator.gd  Rolls items
    inventory.gd       Worn gear + backpack, keeps stats in sync
    loot_manager.gd    Kill drops, the drop budget, pickup
    loot_drop.gd       An item on the ground
  skills/
    skill_data.gd      The tree: nodes, links, tiers, modifiers
    skill_tree.gd      Owned nodes and points, allocate / refund rules
    skill_tree_screen.gd  The K screen (built in code)
  visual/
    asset_props.gd     Imported GLB scenery: loading, materials, placement data
    mesh_kit.gd        Builds one mesh out of colored primitive parts
    models.gd          Every model (hero, enemies, items, bolts, gems, props) + materials
    hero_model.gd      The hero's model and its animation
    world_decor.gd     Scenery scattered in chunks around the hero
    item_icons.gd      Item icons and the turning preview, rendered from the models
    ui_icons.gd        Vector icons for the level-up cards
    damage_numbers.gd  Pooled floating damage numbers
    light_flashes.gd   Pooled light bursts for explosions
    atmosphere.gd      Dusk -> moonlight -> blood moon over the run
shaders/
  kit.gdshader         Vertex-colored models with glow and rim light
  kit_landmark.gdshader  kit for big imported set pieces, with a see-through window
  enemy.gdshader       Enemies: walk cycle, hit flash, rim light
  ground.gdshader      Procedural grass, dirt and flagstones in world space
  gem / glow / particle / beam / ground_glow / aura / blob_shadow / vignette
assets/environment/arpg_pack/   Imported Blender scenery (GLBs), see its README
audio/
  sfx/*.wav, music/*.ogg   Generated by tools/audio/make_audio.py
tools/
  audio/make_audio.py  Synthesizes every sound effect and music loop
  tests.gd, ui_test.gd, skill_ui_test.gd, aim_test.gd, smoke_test.gd, bench_swarm.gd
  balance_bot.gd, balance.sh, screenshot.gd, asset_showcase.gd
```

## Tuning

- **Difficulty curve:** exports on the `WaveDirector` node (`base_rate`,
  `rate_growth`, `rate_acceleration`, `hp_growth_seconds`, `hp_squared_seconds`,
  and the elite rate).
- **The night:** `run_length` on `BossDirector` (900 s); the final boss's HP and
  speed on the `FinalBoss` node; its attacks in the "Final boss" exports on
  `BossDirector`. **Realms:** `REALMS` in `realm.gd` (`difficulty` multiplies
  enemy HP, `rate` the spawn rate). **Hazards:** timing and damage in
  `hazard_director.gd`.
- **Bosses:** exports on `BossDirector` (when they come, how much tougher each
  one is, the slam's timing, size and damage) and on the `Bosses` swarm (HP,
  speed, rewards). **Ranged enemies:** the "Ranged" exports on `Cultists`.
- **Permanent upgrades:** `MetaProgress.UPGRADES`.
- **Soul Army:** `minion_*` and `soul_*` in `PlayerStats.BASE`; reach and timing at
  the top of `army.gd`. **Elements:** the constants at the top of `elements.gd`.
  **Legendary powers:** `ItemData.POWERS`.
- **Enemy stats, look and drops:** exports on the `Grunts` / `Brutes` / `Runners`
  nodes in `main.tscn` (HP, speed, contact damage, size, color, capacity, when
  they start spawning and how common they are, loot chance and quality).
- **Crowd feel:** `separation_strength` and `crowd_limit` on each swarm.
- **Leveling and skill points:** the XP curve and `skill_point_every_levels` are on the
  `Player` node.
- **Starting stats:** `PlayerStats.BASE`. **Upgrade strengths:** `Upgrades.DEFS`.
- **Loot:** the tables in `items/item_data.gd`, and `drops_per_minute` on the
  `Loot` node.
- **Camera:** angle, distance and FOV are on the `Camera3D` child of `CameraRig`.
- **Look:** see "The look" above. Lighting, glow and fog are on the
  `WorldEnvironment` and `Sun` nodes in `main.tscn`.

## Extending it

- **New skill node:** add an entry to `SkillData.NODES` (position, links, modifiers) and
  link it from a neighbor. The screen and the stats pick it up; the tests check that
  every node is connected, uses real stats, and can be bought and refunded.
- **New upgrade:** add an entry to `Upgrades.DEFS`. It's data; no code needed unless
  it does something new.
- **New affix or base item:** add a row to `ItemData.AFFIXES` / `BASES`.
- **New stat:** add it to `PlayerStats.BASE` (and a typed field plus a line in
  `recalculate()` if code reads it), then to `ItemData.STAT_INFO` for display.
- **New enemy type:** duplicate the `Brutes` node in `main.tscn` and change its
  exports, including when it starts spawning and its share. The wave director and
  `main.gd` find it automatically. For a new look, add a builder to
  `Models.enemy()` and its name to the `model` export's list.
- **New weapon:** add the state to `PlayerStats`, an `_update_*` method in
  `player.gd` (see `_update_aura` for the query-based pattern or `_update_bolt`
  for the projectile pattern), and upgrades to unlock and improve it.
- **Per-instance data:** every swarm's buffer already has a color and four custom
  floats per instance (`MultiMeshUtil.OFFSET_COLOR` / `OFFSET_CUSTOM`). Enemies use
  custom x for the hit flash and y for the walk phase, so z and w are free (for
  example for a burning or frozen tint read in `enemy.gdshader`).

## Not built yet

Saving a run in progress (items and the skill tree already serialize with
`to_dict()`; Soul Shards, the Altar and realm progress already save with
`FileAccess.store_var`), harder difficulty tiers for conquered realms, biomes with obstacles (the player is already a `CharacterBody3D`; the
scenery is decoration only), and level-of-detail meshes for far-away enemies.
