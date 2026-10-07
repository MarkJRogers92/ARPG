class_name Realm
extends RefCounted
## The realms: each night of the game is set in one. A realm is pure data
## (look, enemies, bosses, hazard, rule) applied to the main scene when it
## loads, so adding one means adding an entry to REALMS: no new scene.
##
## Flow: the game opens on the title screen (`in_title`). Picking a realm sets
## `current` and reloads the scene, which then plays that realm's night.
## Realm.apply_gameplay() runs from main.gd's _enter_tree(), before the enemy
## swarms build their models in _ready(); apply_look() can run any time (the
## title screen previews realms with it).

## Title screen first. Tests and bots set this false to go straight to play.
static var in_title := true
static var current := "graveyard"

const ORDER := ["graveyard", "frozen", "ember"]

const _GRAVEYARD_STAGES := [
	{"t": 0.0, "sun": Color(1.0, 0.9, 0.76), "sun_e": 1.25, "amb": Color(0.42, 0.48, 0.7), "amb_e": 0.75, "fog": Color(0.07, 0.09, 0.13), "fog_d": 0.008},
	{"t": 300.0, "sun": Color(0.62, 0.72, 1.0), "sun_e": 1.0, "amb": Color(0.3, 0.38, 0.68), "amb_e": 0.65, "fog": Color(0.04, 0.06, 0.13), "fog_d": 0.008},
	{"t": 720.0, "sun": Color(1.0, 0.42, 0.32), "sun_e": 1.1, "amb": Color(0.55, 0.28, 0.32), "amb_e": 0.65, "fog": Color(0.16, 0.04, 0.05), "fog_d": 0.01},
]
const _FROZEN_STAGES := [
	{"t": 0.0, "sun": Color(0.88, 0.94, 1.0), "sun_e": 1.15, "amb": Color(0.55, 0.62, 0.8), "amb_e": 0.85, "fog": Color(0.32, 0.38, 0.48), "fog_d": 0.012},
	{"t": 300.0, "sun": Color(0.45, 0.85, 0.85), "sun_e": 0.85, "amb": Color(0.28, 0.45, 0.62), "amb_e": 0.7, "fog": Color(0.1, 0.18, 0.26), "fog_d": 0.01},
	{"t": 720.0, "sun": Color(0.7, 0.78, 0.95), "sun_e": 0.75, "amb": Color(0.5, 0.56, 0.72), "amb_e": 0.75, "fog": Color(0.45, 0.5, 0.6), "fog_d": 0.02},
]
const _EMBER_STAGES := [
	{"t": 0.0, "sun": Color(1.0, 0.55, 0.3), "sun_e": 1.2, "amb": Color(0.5, 0.3, 0.25), "amb_e": 0.65, "fog": Color(0.2, 0.06, 0.03), "fog_d": 0.01},
	{"t": 300.0, "sun": Color(1.0, 0.35, 0.2), "sun_e": 1.1, "amb": Color(0.45, 0.16, 0.12), "amb_e": 0.6, "fog": Color(0.25, 0.05, 0.02), "fog_d": 0.012},
	{"t": 720.0, "sun": Color(0.9, 0.2, 0.15), "sun_e": 0.95, "amb": Color(0.36, 0.08, 0.08), "amb_e": 0.6, "fog": Color(0.12, 0.02, 0.02), "fog_d": 0.014},
]

## ground: uniforms for shaders/ground.gdshader
## props:  WorldDecor densities (kinds not listed don't appear)
## enemies: per EnemySwarm node: name shown in game, model, color, extras
## hazard: see HazardDirector; motes: the ambient particles
## difficulty: enemy HP multiplier; rate: spawn rate multiplier
const REALMS := {
	"graveyard": {
		"name": "The Hollow Graveyard",
		"tagline": "Where the dead do not rest.",
		"rule": "The dead rise easily: +50% souls. Graves burst open around you.",
		"difficulty": 1.0, "rate": 1.0, "soul_bonus": 0.5, "chill_scale": 1.0,
		"accent": Color(0.55, 0.85, 1.0),
		"background": Color(0.03, 0.035, 0.05),
		"ground": {"grass_dark": Color(0.10, 0.13, 0.085), "grass_light": Color(0.17, 0.21, 0.12),
			"dirt": Color(0.21, 0.17, 0.13), "stone": Color(0.24, 0.235, 0.25), "grout": Color(0.09, 0.095, 0.09),
			"snow": 0.0, "lava": 0.0},
		"props": {"grass": 10.0, "rock": 0.9, "bush": 1.0, "mushroom": 0.5, "bones": 0.5,
			"tree": 0.35, "grave": 0.35, "pillar": 0.05, "crystal": 0.07,
			# Imported scenery (AssetProps). Set pieces are the chance a chunk holds one.
			"rune_gravestone": 0.25, "soul_brazier": 0.06, "ruined_pillar": 0.06, "crystal_cluster": 0.06,
			"tome_pedestal": 0.03, "barrel": 0.05, "crate_stack": 0.04, "weapon_rack": 0.03, "offering_bowl": 0.03,
			"sarcophagus": 0.05, "prison_cage": 0.03, "gravedigger_bench": 0.03, "lantern_post": 0.05,
			"mausoleum": 0.04, "soul_altar": 0.03, "broken_archway": 0.04, "ruined_wall": 0.04, "ruin_corner": 0.03,
			"portcullis": 0.02, "guardian_statue": 0.03, "soul_obelisk": 0.03, "stone_well": 0.03, "ritual_door": 0.02,
			"iron_fence": 0.04, "bell_gibbet": 0.02, "funeral_wagon": 0.03, "ossuary_wall": 0.03, "winged_memorial": 0.03},
		"stages": _GRAVEYARD_STAGES,
		"motes": "embers",
		"hazard": "graves",
		"enemies": {
			"Grunts": {"label": "Ghoul", "model": "grunt", "color": Color(0.52, 0.64, 0.42)},
			"Brutes": {"label": "Ogre", "model": "brute", "color": Color(0.5, 0.26, 0.58)},
			"Runners": {"label": "Hellhound", "model": "runner", "color": Color(0.95, 0.42, 0.12)},
			"Cultists": {"label": "Cultist", "model": "cultist", "color": Color(0.32, 0.14, 0.4), "shot": Elements.NONE},
			"Bosses": {"label": "Ogre Warlord", "model": "boss", "color": Color(0.62, 0.2, 0.16)},
			"FinalBoss": {"label": "The Lich King", "model": "lich", "color": Color(0.35, 0.3, 0.5), "shot": Elements.NONE},
		},
	},
	"frozen": {
		"name": "The Frozen Wastes",
		"tagline": "The cold takes everything, slowly.",
		"rule": "Ice shards fall from the sky and witches' bolts chill you. Chill lasts twice as long on enemies too.",
		"difficulty": 1.2, "rate": 1.05, "soul_bonus": 0.0, "chill_scale": 2.0,
		"accent": Color(0.6, 0.88, 1.0),
		"background": Color(0.25, 0.3, 0.38),
		"ground": {"grass_dark": Color(0.55, 0.6, 0.68), "grass_light": Color(0.72, 0.77, 0.85),
			"dirt": Color(0.38, 0.4, 0.46), "stone": Color(0.42, 0.52, 0.62), "grout": Color(0.22, 0.27, 0.34),
			"snow": 0.75, "lava": 0.0},
		"props": {"grass": 2.0, "snowrock": 1.0, "pine": 0.75, "ice": 0.5, "bones": 0.3, "grave": 0.1,
			"snow_boulder": 0.4, "frosted_pine": 0.35, "ice_stalagmites": 0.2, "supply_tripod": 0.05, "wind_chime": 0.05,
			"ice_arch": 0.06, "watchtower": 0.05, "sled": 0.05, "ribcage": 0.05, "frozen_pond": 0.06,
			"fishing_hut": 0.05, "whale_skull": 0.05},
		"stages": _FROZEN_STAGES,
		"motes": "snow",
		"hazard": "ice",
		"enemies": {
			"Grunts": {"label": "Ice Wraith", "model": "wraith", "color": Color(0.55, 0.72, 0.85)},
			"Brutes": {"label": "Frost Troll", "model": "brute", "color": Color(0.7, 0.8, 0.9)},
			"Runners": {"label": "Ice Wolf", "model": "runner", "color": Color(0.75, 0.85, 0.95)},
			"Cultists": {"label": "Frost Witch", "model": "cultist", "color": Color(0.2, 0.3, 0.5), "shot": Elements.FROST},
			"Bosses": {"label": "Troll Chieftain", "model": "boss", "color": Color(0.6, 0.72, 0.85)},
			"FinalBoss": {"label": "The Frost Colossus", "model": "colossus", "color": Color(0.55, 0.68, 0.82), "shot": Elements.FROST},
		},
	},
	"ember": {
		"name": "The Ember Rift",
		"tagline": "The ground itself is burning.",
		"rule": "Meteors rain down and burn everything they hit, you and the horde alike. Fireballs set you alight.",
		"difficulty": 1.25, "rate": 1.05, "soul_bonus": 0.0, "chill_scale": 1.0,
		"accent": Color(1.0, 0.55, 0.2),
		"background": Color(0.08, 0.02, 0.01),
		"ground": {"grass_dark": Color(0.1, 0.08, 0.08), "grass_light": Color(0.17, 0.13, 0.11),
			"dirt": Color(0.24, 0.12, 0.08), "stone": Color(0.13, 0.12, 0.14), "grout": Color(0.35, 0.1, 0.03),
			"snow": 0.0, "lava": 1.0},
		"props": {"obsidian": 1.0, "brimstone": 0.4, "ashtree": 0.3, "bones": 0.4, "rock": 0.4,
			"obsidian_outcrop": 0.45, "brimstone_vent": 0.15, "ashen_tree": 0.25, "basalt_columns": 0.2, "scorched_banner": 0.06,
			"skull_gateway": 0.05, "forge": 0.05, "cauldron": 0.05, "siege_barricade": 0.06, "minecart": 0.05,
			"furnace": 0.06, "chained_gong": 0.04},
		"stages": _EMBER_STAGES,
		"motes": "ash",
		"hazard": "meteors",
		"enemies": {
			"Grunts": {"label": "Imp", "model": "imp", "color": Color(0.8, 0.25, 0.15)},
			"Brutes": {"label": "Magma Brute", "model": "brute", "color": Color(0.25, 0.12, 0.1)},
			"Runners": {"label": "Hellhound", "model": "runner", "color": Color(1.0, 0.35, 0.08)},
			"Cultists": {"label": "Fire Cultist", "model": "cultist", "color": Color(0.45, 0.1, 0.08), "shot": Elements.FIRE},
			"Bosses": {"label": "Magma Lord", "model": "boss", "color": Color(0.3, 0.1, 0.08)},
			"FinalBoss": {"label": "The Ashen Tyrant", "model": "tyrant", "color": Color(0.4, 0.12, 0.1), "shot": Elements.FIRE},
		},
	},
}


static func data(id := "") -> Dictionary:
	return REALMS[current if id == "" else id]


static func index(id: String) -> int:
	return ORDER.find(id)


## Enemy stats, names, models and colors, the bosses, the hazard and the
## difficulty. Call before the swarms' _ready().
static func apply_gameplay(main: Node, id := "") -> void:
	var d := data(id)
	for swarm_name: String in d["enemies"]:
		var swarm := main.get_node_or_null(swarm_name) as EnemySwarm
		if swarm == null:
			continue
		var e: Dictionary = d["enemies"][swarm_name]
		swarm.display_name = e["label"]
		swarm.model = e["model"]
		swarm.color = e["color"]
		if e.has("shot"):
			swarm.shot_element = e["shot"]
	Elements.chill_scale = d["chill_scale"]
	var director := main.get_node("WaveDirector") as WaveDirector
	director.hp_scale = d["difficulty"]
	director.rate_scale = d["rate"]
	var bosses := main.get_node("BossDirector") as BossDirector
	bosses.boss_name = d["enemies"]["Bosses"]["label"]
	bosses.final_name = d["enemies"]["FinalBoss"]["label"]
	bosses.final_shot = d["enemies"]["FinalBoss"].get("shot", Elements.NONE)
	var hazards := main.get_node("Hazards") as HazardDirector
	hazards.kind = d["hazard"]


## The ground, scenery, light, fog and ambient particles.
static func apply_look(main: Node, id := "") -> void:
	var d := data(id)
	var ground_mat := (main.get_node("Ground") as MeshInstance3D).material_override as ShaderMaterial
	for p: String in d["ground"]:
		ground_mat.set_shader_parameter(p, d["ground"][p])
	var decor := main.get_node("Decor") as WorldDecor
	decor.density = d["props"]
	decor.rebuild_now()
	var atmosphere := main.get_node("Atmosphere") as Atmosphere
	atmosphere.stages = d["stages"]
	var env := (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.background_color = d["background"]
	atmosphere.tick(10.0, 0.0, false)
