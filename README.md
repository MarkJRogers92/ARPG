# Soulbound

A 3D survivors-like (Vampire Survivors / Soulstone Survivors style) with an ARPG
gear layer, built in **Godot 4.6** and designed from the start for **thousands of
enemies on screen**.

Pick a realm and survive its night: move, auto-attack, kill the horde, raise the
dead into your own army, level up, loot and equip gear. At dawn the realm's final
boss comes for you; kill it and you've won the night. (The title, "Soulbound",
is the `GAME_TITLE` constant in `scripts/title_screen.gd`.)

## Run it

**On a Mac, without Godot:** paste this into Terminal. It installs the latest
build into Applications and opens it; run it again any time to update.

```bash
curl -fL -o /tmp/Soulbound.zip https://github.com/MarkJRogers92/ARPG/releases/download/mac-latest/Soulbound.zip && rm -rf /Applications/Soulbound.app && ditto -xk /tmp/Soulbound.zip /Applications && open /Applications/Soulbound.app
```

After that it's an ordinary app (Launchpad, Spotlight, the Dock).

**On Windows, without Godot:** download
[Soulbound-windows.zip](https://github.com/MarkJRogers92/ARPG/releases/download/windows-latest/Soulbound-windows.zip),
extract it anywhere and run `Soulbound.exe`. The exe isn't code-signed, so
SmartScreen may warn: choose **More info**, then **Run anyway**. Download it
again to update.

**On Linux (x86_64), without Godot:** this installs or updates into `~/Soulbound`
and starts the game:

```bash
curl -fL -o /tmp/Soulbound-linux.zip https://github.com/MarkJRogers92/ARPG/releases/download/linux-latest/Soulbound-linux.zip && unzip -o /tmp/Soulbound-linux.zip -d ~/Soulbound && ~/Soulbound/Soulbound.x86_64
```

The builds come from `.github/workflows/build.yml`: every push to the
repository's default branch (`claude/focused-fermat-m7jhtk`; `main` is listed
too), or a manual run, runs the tests once, exports all three presets in
`export_presets.cfg` (Mac: a universal build, ad-hoc signed; Windows and Linux:
x86_64, a single executable with the game data embedded) and replaces the
`mac-latest`, `windows-latest` and `linux-latest` releases. Each release follows
the pattern `https://github.com/MarkJRogers92/ARPG/releases/download/<tag>/<asset>`.
A web build (Compatibility renderer) is possible but needs a performance check
first: thousands of MultiMesh enemies in a browser. Saves are shared with the
editor (`config/custom_user_dir_name` keeps the old folder name). The icon is
drawn by `tools/make_icon.py`.

**From the editor:**

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
| Q / gamepad LB | Switch the army's stance: Hunt, Guard, Swarm |
| Esc | Pause: settings (below), Controls (rebind keys), back to the title |

The keys above are the defaults. **Controls** in the pause menu rebinds the
first key of every action (moving, dash, use, stance, inventory, skill tree,
reroll, aim mode); taking a key another action uses swaps the two, and the
arrow keys and gamepad stay. Hints on screen ("[E]  Open") follow the
bindings (`scripts/controls.gd`; saved with the settings).

The pause menu also has the comfort and accessibility settings:

- **Calm effects** (photosensitivity): no hit-stop or slow motion, light
  flashes at 30%, and the rift glitch at a fifth of its strength.
- **Bold warnings**: every ground warning (hazards, boss slams, mid-boss moves,
  meteors, bloater fuses, Lancer and Colossus lines) drawn brighter and near
  opaque (`HazardDirector.make_warning`, `Juice.warning_color`).
- **Aim assist** (0-100%): when aiming with the mouse or stick, bolts and
  scythes bend toward an enemy within up to 30° of the aim.

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

**The coming dawn.** A thin arc under the clock shows the moon crossing the
night. For the last 2½ minutes (**First Light**) the moon turns into the sun,
the sun sinks toward the horizon so shadows stretch out long, the light warms
to rose-gold, and a glow with slow light rays builds from the corner the sun
shines from (`scripts/visual/dawn_glow.gd`, `shaders/dawn_glow.gdshader`).
When the final boss falls, a wall of sunlight spreads out from where it died
and turns the horde to ash as it passes (no rewards for those), the sun
climbs, and the sunrise chord plays.

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

**Soul trails.** Kills send pale wisps rising from the bodies to stream into
the hero, each leaving a short fading trail (`scripts/visual/wisps.gd`; capped
at 260 at once, so a huge fight stays cheap).

**Save and quit.** The pause menu's *Save and quit* keeps the night in one
slot (`user://run.save`, `scripts/run_save.gd`), and the title screen offers
*Resume the night* in place of its tagline. It keeps the hero (level, XP,
health, position, every lasting stat change: upgrades, evolutions, the path,
landmark gifts), gear, skills, the clock and pressure, the boss schedule,
the army's kinds and ranks, souls, rerolls, kills, shards and the night's
omen, pacts and Ascension. The horde isn't saved: a crowd fit for the hour
gathers instead, and a mid-boss in the field returns shortly. Shrines,
goblins, chests, rifts, the Ferryman's loans and bets, the rival, frenzy and
blessings start fresh. A saved night resumes once; starting a new one
abandons it; and the night can't be saved once its master is up.

**Why you died.** The end screen names the killing blow and what hurt most
over the night ("SLAIN BY: Plague Bloater blast / HURT MOST BY: Ghoul 45% ·
Meteors 20%..."), with a small chart of health and pressure through the
night. Every source of damage passes its cause to `Player.take_damage`
(contact by enemy name, shots by who fired them, slams, hazards, mid-boss
moves, blasts, burning); `scripts/death_recap.gd` has the summary and chart.

**Death.** When the hero falls, time slows, the army bursts apart minion by
minion, the hero's souls scatter up into the dark and the hero crumples; the
end screen comes up after a few seconds. (The night is settled at the moment
of death, so the Crypt still gets its veteran.)

## Heroes

Pick a hero on the title screen. The Battlemage is free; the others are bought
once with Soul Shards and stay unlocked (`scripts/hero_class.gd`):

| Hero | Cost | Plays like |
|---|---|---|
| Battlemage | free | Bolts fire 10% faster and pierce one more enemy |
| Necromancer | 30 ◆ | +2 army size, +50% souls, minions +30% damage and they burst in soulfire when they fall (Lich Shroud); bolts deal 15% less |
| Pyromancer | 40 ◆ | Bolts ignite 35% of the time, +60% burn damage, and fire always spreads from the burning dead (Pyre) |
| Stormcaller | 50 ◆ | Starts with a faster, stronger Chain Lightning; dashes 30% more often and leaves lightning in its wake (Stormstride) |
| Reaper | 60 ◆ | No bolts: fights with two Reaping Scythes from the start, thrown 80% faster and 3 m farther for 25% more damage, which carry the bolt elements (Kindling, Frostbite); +10% move speed. Slower in the first minutes, stronger once the horde is thick |

The Reaper never sees the bolt cards (Sharper Bolts, Quick Cast, Multishot,
Piercing Bolts); it gets Keen Edge, Whirling Throw and Long Reach in their
place (`only` / `bolt` in `Upgrades.DEFS`), and its paths at level 10 are
Harvest Moon, Executioner and Soul Reaper.

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
- **Ascension** (in the Pact of Night screen): winning a realm at level N
  opens level N + 1, up to 10. Each level keeps the rules below it and adds
  one, makes the night's pressure climb 10% faster, and adds 10%
  to the Soul Shards earned:

  | | Adds |
  |---|---|
  | 1 | Enemies have 20% more health |
  | 2 | Elites come 50% more often |
  | 3 | Enemy shots fly 30% faster and hit 25% harder |
  | 4 | The horde arrives 20% faster |
  | 5 | Bosses have 50% more health |
  | 6 | Your minions have 25% less life |
  | 7 | Half health regeneration |
  | 8 | The night adapts twice as fast |
  | 9 | Enemies move 10% faster |
  | 10 | The final boss has double health |

- **Pressure** (`WaveDirector.update_pressure`): from 5:00 on, the night
  pushes back against a hero walking through it. While the hero is above 90%
  health, pressure climbs (3% a second, twice that if fewer enemies are alive
  than the time of night calls for, 85% of `crowd_target()`); below 45%
  health it falls three times as fast. Its cap grows with the night: +2 a
  minute from 5:00 (×15 by 12:00, ×20 at most), 10% faster per Ascension
  level. Enemy health is
  multiplied by pressure and the spawn rate by its square root (at most
  ×1.6).
- **Late leveling:** from 5:00, kills give less and less XP (half by 7:00,
  about a sixth by dawn; `main.gd` `xp_scale_at`), and levels past 30 cost
  more (`Player.xp_late_cubed`), so a strong build is still choosing its last
  upgrades at dawn instead of maxing everything by minute 9.
- **Bestiary** (title screen): kills of each enemy kind across every night.
  100, 1,000 and 5,000 kills earn a star, and every star is +1% damage, for
  good.
- **Daily Night** (title screen): today's realm, omen and seed are the same
  for every run today. Your best kill count is kept. Every finished Daily
  Night leaves a shareable code, such as `SB-20261008-K1234-T812-L-BAT-H0YS`
  (date, kills, seconds survived, won or lost, hero, and a base-36 checksum
  salted with the day's seed, so typos and edited numbers are rejected;
  `scripts/daily_code.gd`). The code is on the end screen with a copy button.
  The Daily Night button opens a panel with today's realm and omen, the last
  30 dailies (each day's best starred, each with its code to copy) and a box
  to check a friend's code: it shows the result and that day's night.
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

**Evolutions** (`scripts/evolutions.gd`): max out a weapon and take its
catalyst card (any rank), and the next level-up offers a golden **EVOLUTION**
card for it. Each happens once a night; a weapon's card names its pair from
two ranks before max.

| Weapon (max) | + Catalyst | Evolves into |
|---|---|---|
| Sharper Bolts | Piercing Bolts | **Soul Lance**: bolts pierce everything, faster, farther, +50% damage |
| Frost Aura | Frostbite | **Absolute Zero**: +50% radius, ×2 damage, pulses 30% faster |
| Chain Lightning | Kindling | **Storm Lord**: +6 jumps, 50% faster, +60% damage |
| Spirit Blades | Swift Boots | **Blade Cyclone**: +3 blades, +80% damage, wider orbit |
| Ferryman's Obol | Magnetism | **Charon's Hoard**: +5 ricochets, +25% luck, 50% more coins |
| Reaping Scythe | Soul Harvest | **Death's Harvest**: +2 scythes, +80% damage, +4 m, +30% souls |
| Funeral Bell | Soul Legion | **Requiem**: tolls 10 kills sooner, ×2 damage, +4 m |
| Arcane Nova | Vitality | **Supernova**: +60% radius, ×2 damage, 30% more often |

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

**Mid-bosses** (`scripts/mid_mechanics.gd`) each have a move of their own on
top of the shared ground slam, and come harder each time (shorter gaps, +35%
damage per boss):

- **The Ogre Warlord:** every 11 s he stamps and a shockwave rolls out 17 m.
  It hits whoever it reaches; dash through it.
- **The Troll Chieftain:** every 18 s he grows a rime armor for 7 s (he takes
  65% less damage). Chill him to crack it; he's then brittle for 4 s and takes
  50% more.
- **The Magma Lord:** leaves pools of lava where he walks (and from the third
  boss on, drops some near you). They erupt after a warning, then burn you
  and the horde for 9 s.

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

## The rival necromancer

Once a night, around 9:00 (not while a boss is up), another necromancer comes
for your souls (`scripts/rival.gd`): a robed figure with a horned crown and a
red ring under it, announced with a title card and tracked by an edge arrow
and a line under the timer.

- It keeps its distance and casts soul bolts, and **blinks away** when you get
  within a few meters.
- It **steals souls**: any lying within 9 m of it, and 3 of your banked souls
  every 7 s while you're within 14 m (a red stream shows the theft).
- It raises **red thralls**: one per 4 stolen souls and one every 5 s anyway
  (up to 24).
- After 100 s it escapes with what it took, and its thralls fade.

Kill it in time and **its army is yours**: up to 6 of its thralls (at least
2) and its own shade, as a champion caster, join the Soul Army, past your
army's usual size. It also drops a Legendary and 15 Soul Shards. No rift
opens while it's about.

**The nemesis.** A rival that escapes, or is still about when you fall,
comes back the next night under the same name, one rank stronger (up to 5),
and taunts you with what it took. Each rank adds 40% health, 10 s before it
flees, an extra thrall at the start and 4 more at most, quicker blinks and a
greedier drain. Putting a nemesis down pays a Legendary and the 15 shards
once more per rank, and clears it; the Bestiary shows your current nemesis
(`MetaProgress.nemesis`).

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

## Rifts

Tears in the night that lead somewhere else for a while (`scripts/rift_director.gd`).
The first opens around 4:00, then one every 3 to 4 minutes, alternating
between the two kinds. None opens while a boss is up or within two minutes of
dawn. A portal lasts a minute, and an arrow points to it.

- **The Night Market** (violet portal, or a graveyard's ritual door). Step in
  and the realm holds still: no spawns, no clock, the horde frozen where it
  stands. Four stalls take this run's Soul Shards, once each:

  | Stall | Price | You get |
  |---|---|---|
  | Bone Merchant | 8 | a Rare item |
  | Soul Broker | 6 | a champion spirit (an elite minion) |
  | Apothecary | 5 | a full heal and a blessing |
  | Fortune Teller | 5 | +2 rerolls |

  Leave by the exit portal, or the market fades after 75 s. You come back
  exactly where you left, with 1.5 s of grace.
- **The Glitch** (green portal). Touch it and for 30 s the world plays like an
  old game: chunky pixels, a small palette, scanlines
  (`shaders/glitch.gdshader`). XP and souls are doubled while it lasts. Survive
  it for two items.

The market is just a far-off spot in the same scene with its own props and
light, so nothing about the run has to be saved and restored.

## The army's roles

**Soul link.** Minions draw on the hero's power: they hit
1 + 0.5 × (hero power − 1) times as hard, where hero power is how much the
weapons in use have grown on average since the start of the night (upgrades,
gear, evolutions; `PlayerStats.hero_power`). So the army keeps pace with the
build instead of fading to nothing late in the night.

A raised minion keeps a piece of what it was (`Army.role_of`):

| Role | From | Fights |
|---|---|---|
| Brawler | most enemies | cleaves around its target |
| Caster | ranged enemies, gravediggers | soul bolts from 7 m |
| Bulwark | big enemies (brutes) | every 3 s a ground slam that hurls the horde back |
| Skirmisher | fast enemies, lancers | darts in with quick strikes |
| Tyrant | bound bosses | a crushing slam on a long cooldown |

Damage per second is the same across roles; the rhythm and reach differ.

**Stances** (Q / gamepad LB cycles them; the HUD shows the current one next
to the army count):

| Stance | Looks for prey | Moves | Takes |
|---|---|---|---|
| Hunt (default) | within 11 m, up to 15 m from you | normal | normal damage |
| Guard | within 6 m, only up to 5.5 m from you; forms up tight | normal | half damage |
| Swarm | within 18 m, up to 28 m from you; elites and bosses first | 25% faster | 25% more damage |

## Veterans and the Crypt

Minions count their kills (every enemy death during a minion's swing or slam
is credited to it). Enough of them and it earns a name, like *Morwen the
Butcher* (the epithet comes from its role), and a rank. A veteran wears its
name and stars over its head, glows gold, stands a little larger, and has a
gold ring under it.

| Rank | Kills | Damage and life |
|---|---|---|
| Veteran | 60 | ×1.3 |
| Hero | 300 | ×1.7 |
| Legend | 1000 | ×2.3 |

Champions joining a full army push out common minions, never veterans.
Pledged or seized veterans come back as themselves.

When a night ends (won or lost), the greatest living veteran is laid to rest
in **the Crypt** (up to 3; a full Crypt keeps the greatest). On the title
screen, **The Crypt** shows them: tick one and it rises at your side when the
next night begins, keeping its name, rank and kills, and goes back to rest
afterwards with whatever it earned. If a veteran from the Crypt falls in
battle, it's gone for good, and listed among **the Fallen**
(`Army` veterans, `MetaProgress.entomb` / `crypt_fell`).

## Specialist enemies

- **Lancers** (Bone Lancer, Rime Lancer, Hellspear) stop and show a red line
  along their path, which grows as the wind-up runs out. Then they charge
  straight down it for 14 damage and recover. Sidestep the line and punish
  the recovery; a Lancer that hits a wall is stunned longer. At most six wind
  up at once.
- **Gravediggers** (Gravedigger, Frozen Sexton, Ash Sexton) hang back about
  8 m from the hero. Every ~6 s they raise three fresh enemies from the
  ground and swallow the uncollected souls nearby. Kill them first.
- **Shieldbearers** (Bone Shieldbearer, Rime Warden, Obsidian Guard), from
  4:00, hide behind tower shields: direct hits (Magic Bolt, Spirit Blades,
  Obol, Reaping Scythe, Chain Lightning; `Elements.DIRECT`) deal only a fifth
  and glint off with a "BLOCKED". Burning, Frost Aura, Arcane Nova, the
  Funeral Bell, reactions, blasts and the army hit them in full.
- **Menders** (Grave Mender, Hoarfrost Shaman, Cinder Priest), from 5:30, hang
  back about 7 m inside a green ring on the ground. Every ~4.5 s they heal
  every non-boss enemy in the ring by 30% of its health. Rare (at most six);
  kill them first.
- **Bloaters** (Plague Bloater, Frost Bloater, Magma Bloater), from 3:00, run
  at the hero. Within 2 m they stop, glow, and a circle fills on the ground;
  1.1 s later they burst for 16 damage (chilling in the Frozen Wastes, burning
  in the Ember Rift), hurting the horde in the circle too, much harder. Kill
  one with its fuse lit and it bursts at once, which can set off its
  neighbors; one that bursts on its own gives nothing.

Each explains itself with a message the first time it does its thing. The
behavior is in `EnemySwarm` (the "Specialists" exports), what the hero sees
and feels in `scripts/specialists.gd`.

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
| **Shatter** | lightning hits a chilled enemy | an ice burst (as strong as the hit) damages and chills everything around it |
| **Melt** | fire hits a chilled enemy | that hit deals 1.8x |
| **Overload** | fire hits a shocked enemy, or lightning a burning one | an explosion (1.3x the hit) |

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

**Soul Shards and the Altar.** Shards picked up during a night (elites,
bosses, events; also spent at wells, forges and the Night Market) are banked
at a quarter when it ends, plus a bonus: 2 per minute survived, a sixth of the
square root of the kills (so 250,000 kills is 84, not 1,700), and the full
reward for winning. Pacts, the Midas omen and Ascension multiply it. On the death
screen, the **Altar of Souls** spends them on permanent upgrades: more HP,
damage, speed, XP, magic find and regen, and **Insight** (level-up rerolls each
run). They're saved in `user://meta.save` (`meta_progress.gd`; the costs are
there too). To start over, delete that file: on macOS it's in
`~/Library/Application Support/Godot/app_userdata/ARPG/`.

**The Reliquary** (title screen, next to the hero's description) is where
shards go beyond the Altar (`scripts/relics.gd`):

- **Relics.** Carry one into each night. Bought once with shards: Glass Skull
  (+35% damage, 30% less health), Lodestone (double pickup radius, +40% magic
  find, a little slower), Bone Dice (+3 rerolls, 10% less XP), Iron Heart (+30
  armor, +40% health, 15% less damage). Earned with Bestiary stars: Soul Censer
  (5 ★, the Soul Lantern's power), Winter's Tear (10 ★, Endless Winter's) and
  Cinder Heart (15 ★, the Ring of Embers').
- **Starting weapon.** Unlock a weapon card for 20 shards and begin every
  night with it taken (rank 1, so it levels and evolves as usual).
- **Lost lore.** Level-up cards that only enter the pool once learned:
  Deadly Aim (crit), Bulwark (armor) and Catalyst (reactions)
  (`unlock` in `Upgrades.DEFS`).

The picks and purchases are saved with the rest (save version 3; older saves
load with an empty Reliquary). Bots and tests carry nothing unless told to
(`relic=` / `weapon=` in `balance_bot.gd`).

**Feel.** Damage numbers (crits are big and gold; only one in five ordinary hits
shows a number, to keep it readable), screen shake on big hits, real light from
explosions, dash trails, drifting embers, and a sky that changes over the run:
warm dusk, cold moonlight around 4:00, a blood moon from about 9:00, turning
redder while a boss is alive (`visual/atmosphere.gd`). Shake can be turned off
with `shake_enabled` on `CameraRig`.

## The look

Almost everything you see is built in code: the hero, every enemy and boss,
items, bolts, XP crystals, icons and most scenery. The exception is 52
imported Blender props (`assets/environment/arpg_pack/`, see Imported
scenery). `scripts/visual/models.gd` assembles each code-built model out of
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

**Whole nights** (19 minutes of game time: the 15-minute night plus 4 minutes
after dawn; the bot dodging telegraphs). Re-run after the specialist enemies,
the Reaper's cards, the Reliquary and the mid-boss moves, with 4 seeds in the
Graveyard and 2 in the other realms (`tools/balance.sh -m 19 -o DIR realm=...`):

| Realm | Damage-first bot | Random picks |
|---|---|---|
| The Hollow Graveyard | survives to 19:00 in 3 of 4 (one died at 10.5 min); level ~71 | survives to 19:00 in 4 of 4; level ~65 |
| The Frozen Wastes | survives to 19:00 in 2 of 2; level ~65 | 1 of 2 (one died at 6.2 min) |
| The Ember Rift | survives to 19:00 in 2 of 2; level ~75 | 0 of 2 (died at 6.5 and 17.4 min) |

**No run killed the final boss** in the 4 minutes after dawn, in any realm.
The same runs on the code from before these features (3 Graveyard seeds) didn't
either, so the change came earlier, with the tuning that tied the army to the
hero's power and moved pressure to 5:00 (an earlier table had the damage-first
bot winning the Graveyard 4 of 4, the boss falling 50-70 s after dawn). The
bot may simply not finish the boss before the horde of a pressured night
buries it; worth a look with `-m 25` and the final boss's HP (`FinalBoss.max_hp`
in `scenes/main.tscn`, and `BossDirector` in `boss_director.gd`).

The later realms are meant to be a step up: by the time you reach them you'll
have Altar upgrades and relics, which the bots don't. The first version of the
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
godot --headless --path . --fixed-fps 60 -s tools/resume_test.gd # saves a night, reloads, resumes it
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
- It also covers the specialist enemies (shields block only direct hits,
  menders heal up to full in their ring, bloaters light up, burst, chain and
  clear their circles), the Reaper (no bolts, its own cards, scythes carrying
  elements), the Reliquary (buying, star relics, carrying, starting weapons,
  lost lore gating the pool, old saves loading), key rebinding (swaps, reset,
  saving), bold warnings, calm effects, aim assist, and the death recap
  (damage by cause, the killing blow, who fired a shot).
- `resume_test.gd` builds a night with history (upgrades, a path, gear,
  skills, an army), saves and quits through the real flow, resumes from the
  title screen's signal and checks that everything came back.
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
  abilities/           Chain Lightning, Spirit Blades, Arcane Nova, Obol, Reaping Scythe, Funeral Bell
  enemy_shots.gd       Fireballs from ranged enemies (each remembers who fired it)
  boss_director.gd     When bosses come, and their telegraphed slam
  mid_mechanics.gd     Each realm's mid-boss move: shockwave, rime armor, lava pools
  final_mechanics.gd   Each realm's final boss: phylacteries, fracture lines, meteors
  specialists.gd       Shieldbearers, Menders and Bloaters: blocks, heals, blasts
  meta_progress.gd     Soul Shards, the Altar, the Reliquary, settings (saved)
  relics.gd            The Reliquary: relics, starting weapons, lost lore
  run_save.gd          Save and quit / resume: the one saved night
  death_recap.gd       The end screen's "why you died" summary and chart
  controls.gd          Key rebinding and key names for on-screen hints
  evolutions.gd        Weapon evolutions (a maxed weapon + its catalyst)
  specializations.gd   The three paths per hero at level 10
  run_modifiers.gd     Omens, Pacts of Night and Ascension
  landmarks.gd         Usable set pieces (wells, forges, tomes...)
  ferryman.gd          The Ferryman's wagers, loans, bets and Debt Collectors
  wager_panel.gd       The Ferryman's table
  rival.gd             The rival necromancer and the nemesis
  rift_director.gd     Rifts: the Night Market and the glitch
  juice.gd             One place to trigger particles, numbers, flashes, shake
  army.gd              The Soul Army: souls, raising minions, minion AI
  elements.gd          Elemental hits, statuses and reactions
  realm.gd             The realms: look, enemies, bosses, hazards, difficulty
  hazard_director.gd   Each realm's telegraphed hazard
  obstacles.gd         Solid scenery as circles: push-out and sliding for hero and enemies
  title_screen.gd      Hero and realm select (previews each realm behind the menu)
  hero_class.gd        The playable heroes: looks, weapons, stats, powers
  event_director.gd    Shrines, treasure goblins, cursed chests, health orbs
  pause_menu.gd        Esc menu: settings, Controls, Save and quit
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
    dawn_glow.gd       First Light's glow and rays
    wisps.gd           Soul trails from the dead to the hero
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
  tests.gd, ui_test.gd, skill_ui_test.gd, aim_test.gd, resume_test.gd, smoke_test.gd, bench_swarm.gd
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

Level-of-detail meshes for far-away enemies; a web build (the Compatibility
renderer would allow it, but thousands of MultiMesh enemies need a
performance check in a browser first); gamepad rebinding (Controls rebinds
keys only); and saving a night during its final fight.
