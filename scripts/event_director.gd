class_name EventDirector
extends Node3D
## Things worth chasing between waves. Every so often one appears out of
## sight, announced with a toast and pointed to by an arrow at the screen edge
## (see markers()):
##
##   Shrine         stand in its circle until it charges: a 30 s blessing
##                  (Fury, Haste, Plenty or Warding)
##   Treasure goblin  a fleeing thief: catch it before it escapes for loot,
##                  gems and Soul Shards
##   Cursed chest   opening it summons a ring of elites; kill them all and the
##                  chest gives a Legendary
##
## And health orbs: elites (and goblins) sometimes drop one; walk over it to
## heal a quarter of your health.

signal announced(text: String, color: Color)

## Seconds until the first event, then between events.
@export var first_at := 45.0
@export var interval_min := 38.0
@export var interval_max := 55.0
@export var shrine_radius := 3.0
@export var shrine_charge_time := 3.5
@export var blessing_time := 30.0
@export var goblin_time := 22.0

const BLESSINGS := {
	"Fury": {"color": Color(1.0, 0.35, 0.25), "desc": "+60% damage",
		"mods": [{"stat": "damage", "op": PlayerStats.Op.MORE, "value": 0.6}]},
	"Haste": {"color": Color(0.4, 1.0, 0.6), "desc": "+35% move and attack speed",
		"mods": [{"stat": "move_speed", "op": PlayerStats.Op.MORE, "value": 0.35},
			{"stat": "bolt_rate", "op": PlayerStats.Op.MORE, "value": 0.35}]},
	"Plenty": {"color": Color(1.0, 0.85, 0.3), "desc": "double XP and souls",
		"mods": [{"stat": "xp_gain", "op": PlayerStats.Op.MORE, "value": 1.0},
			{"stat": "soul_chance", "op": PlayerStats.Op.MORE, "value": 1.0}]},
	"Warding": {"color": Color(0.5, 0.75, 1.0), "desc": "take 60% less damage",
		"mods": [{"stat": "armor", "op": PlayerStats.Op.ADD, "value": 150.0}]},
}

## The blessing in effect ("" for none) and its seconds left.
var blessing := ""
var blessing_left := 0.0

var _director: WaveDirector
var _player: Player
var _loot: LootManager
var _gems: GemSwarm
var _goblins: EnemySwarm
var _swarms: Array[EnemySwarm] = []
var _timer := 0.0
## The active events: {"kind", "at", "node", ...}.
var _events: Array[Dictionary] = []
var _orbs: Array[Dictionary] = []
var _goblin_left := 0.0
## Run shards earned from events, picked up by main.gd.
var shards := 0


func setup(director: WaveDirector, player: Player, loot: LootManager, gems: GemSwarm,
		goblins: EnemySwarm, swarms: Array[EnemySwarm]) -> void:
	_director = director
	_player = player
	_loot = loot
	_gems = gems
	_goblins = goblins
	_swarms = swarms
	_timer = first_at
	_goblins.enemy_died.connect(_on_goblin_died)


func tick(delta: float) -> void:
	if _director == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(interval_min, interval_max)
		_start_random()
	_update_blessing(delta)
	_update_events(delta)
	_update_orbs(delta)


## Off-screen events for the HUD's edge arrows: [{"at": Vector2, "color", "label"}].
func markers() -> Array:
	var out := []
	for e in _events:
		out.append({"at": e["at"], "color": e["color"], "label": e["label"]})
	for i in _goblins.count:
		if _goblins.hp[i] > 0.0:
			out.append({"at": _goblins.pos[i], "color": Color(1.0, 0.85, 0.3), "label": "GOBLIN"})
	return out


## A health orb where an enemy fell.
func drop_orb(at: Vector2) -> void:
	if _orbs.size() >= 12:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = Models.health_orb()
	mi.position = Vector3(at.x, 0.8, at.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_orbs.append({"at": at, "node": mi, "age": 0.0})


# --- events --------------------------------------------------------------------

func _start_random() -> void:
	var kinds := ["shrine", "shrine", "goblin", "chest"]
	if _goblins.alive_count() > 0:
		kinds.erase("goblin")
	var kind: String = kinds.pick_random()
	# Somewhere off screen, clear of solid scenery so it can be reached.
	var at := _player.pos2 + Vector2.from_angle(randf() * TAU) * randf_range(15.0, 19.0)
	for attempt in 12:
		if not Obstacles.blocked(at, shrine_radius + 0.5):
			break
		at = _player.pos2 + Vector2.from_angle(randf() * TAU) * randf_range(15.0, 19.0)
	match kind:
		"shrine":
			_start_shrine(at)
		"goblin":
			_goblin_left = goblin_time
			_goblins.spawn(_player.pos2 + Vector2.from_angle(randf() * TAU) * 11.0, _director.hp_multiplier())
			announced.emit("A treasure goblin! Catch it before it escapes!", Color(1.0, 0.85, 0.3))
			Sound.play("goblin")
		"chest":
			_start_chest(at)


func _start_shrine(at: Vector2) -> void:
	var name: String = BLESSINGS.keys().pick_random()
	var color: Color = BLESSINGS[name]["color"]
	var root := Node3D.new()
	root.position = Vector3(at.x, 0.0, at.y)
	add_child(root)
	var model := MeshInstance3D.new()
	model.mesh = Models.shrine(color)
	root.add_child(model)
	var ring := HazardDirector.make_decal(root, Vector2.ZERO, Color(color, 0.7), 1.0, shrine_radius * 2.0)
	var fill := HazardDirector.make_decal(root, Vector2.ZERO, Color(color, 0.3), 0.0, shrine_radius * 2.0)
	fill.scale = Vector3.ONE * 0.02
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.light_cull_mask = 1
	light.position = Vector3(0, 3.0, 0)
	root.add_child(light)
	_events.append({"kind": "shrine", "at": at, "node": root, "fill": fill, "ring": ring,
			"charge": 0.0, "blessing": name, "color": color, "label": "SHRINE", "age": 0.0})
	announced.emit("A Shrine of %s appears nearby" % name, color)


func _start_chest(at: Vector2) -> void:
	var root := Node3D.new()
	root.position = Vector3(at.x, 0.0, at.y)
	add_child(root)
	var model := MeshInstance3D.new()
	model.mesh = AssetProps.mesh("treasure_chest")
	if model.mesh == null:
		model.mesh = Models.chest()
	root.add_child(model)
	HazardDirector.make_decal(root, Vector2.ZERO, Color(0.75, 0.3, 1.0, 0.5), 0.6, 3.0)
	_events.append({"kind": "chest", "at": at, "node": root, "opened": false, "guards": [],
			"color": Color(0.75, 0.3, 1.0), "label": "CURSED CHEST", "age": 0.0})
	announced.emit("A cursed chest... dare you open it?", Color(0.8, 0.45, 1.0))


func _update_events(delta: float) -> void:
	var hero := _player.pos2
	var i := _events.size() - 1
	while i >= 0:
		var e := _events[i]
		e["age"] += delta
		var done := false
		match e["kind"]:
			"shrine":
				done = _update_shrine(e, hero, delta)
			"chest":
				done = _update_chest(e, hero)
		# Unused events fade away after a while.
		if not done and e["age"] > 90.0 and not e.get("opened", false):
			done = true
		if done:
			e["node"].queue_free()
			_events.remove_at(i)
		i -= 1
	if _goblins.alive_count() > 0:
		_goblin_left -= delta
		if _goblin_left <= 0.0:
			for k in _goblins.count:
				if _goblins.hp[k] > 0.0:
					Juice.burst(_goblins.pos[k], 0.8, Color(1.0, 0.85, 0.3), 20, 4.0, 0.4, 0.6, 4.0)
			_goblins.despawn_all()
			announced.emit("The goblin escaped with its loot!", Color(0.8, 0.7, 0.5))


func _update_shrine(e: Dictionary, hero: Vector2, delta: float) -> bool:
	var inside := hero.distance_to(e["at"]) <= shrine_radius
	var before: float = e["charge"]
	e["charge"] = clampf(before + (delta / shrine_charge_time if inside else -delta * 0.3), 0.0, 1.0)
	(e["fill"] as MeshInstance3D).scale = Vector3.ONE * maxf(e["charge"], 0.02)
	if inside and int(before * 4.0) != int(e["charge"] * 4.0):
		Sound.play("shrine_charge", 1.0 + e["charge"] * 0.5)
	if e["charge"] >= 1.0:
		_bless(e["blessing"])
		Juice.ring(e["at"], e["color"], 40, 9.0, 0.6, 0.6)
		Juice.flash(e["at"], e["color"], 6.0, 12.0, 0.6)
		return true
	return false


func _update_chest(e: Dictionary, hero: Vector2) -> bool:
	if not e["opened"]:
		if hero.distance_to(e["at"]) <= 1.8:
			e["opened"] = true
			Sound.play("chest")
			Sound.play("boss_roar", 1.4, -6.0)
			var n := 5 + Realm.index(Realm.current)
			var types := _swarms.filter(func(s: EnemySwarm) -> bool: return not s.boss and not s.flee)
			for k in n:
				var swarm: EnemySwarm = types.pick_random()
				var at: Vector2 = e["at"] + Vector2.from_angle(TAU * k / n) * 7.0
				if swarm.spawn(at, _director.hp_multiplier(), true):
					e["guards"].append([swarm, swarm.ids[swarm.count - 1]])
			e["label"] = "GUARDIANS"
			announced.emit("The chest's guardians awaken! Slay them all.", Color(0.8, 0.45, 1.0))
		return false
	# Opened: rewards once every guardian is dead.
	for g: Array in e["guards"]:
		var swarm: EnemySwarm = g[0]
		for k in swarm.count:
			if swarm.ids[k] == g[1] and swarm.hp[k] > 0.0:
				return false
	var item := ItemGenerator.generate_with(ItemData.ilvl_for_player_level(_player.stats.level),
			ItemData.Rarity.LEGENDARY, ItemData.SLOTS.pick_random())
	_loot.drop(item, e["at"])
	shards += 5
	Sound.play("chest")
	Juice.ring(e["at"], e["color"], 40, 8.0, 0.6, 0.6)
	Juice.flash(e["at"], e["color"], 6.0, 10.0, 0.5)
	announced.emit("The curse breaks!  +5 Soul Shards", Color(0.8, 0.45, 1.0))
	return true


func _on_goblin_died(at: Vector2, _xp: int) -> void:
	var ilvl := ItemData.ilvl_for_player_level(_player.stats.level)
	for k in 3:
		_loot.drop(ItemGenerator.generate(ilvl, 1.5 + _player.stats.magic_find), at)
	for k in 20:
		_gems.drop(at + Vector2.from_angle(randf() * TAU) * randf_range(0.5, 2.5), 6)
	shards += 3
	drop_orb(at + Vector2(1.0, 0.0))
	Sound.play("goblin", 0.7)
	Juice.burst(at, 0.8, Color(1.0, 0.85, 0.3), 40, 7.0, 0.5, 0.8, 6.0)
	announced.emit("Goblin caught!  +3 Soul Shards", Color(1.0, 0.85, 0.3))


# --- blessings and orbs ------------------------------------------------------------

func _bless(name: String) -> void:
	var stats := _player.stats
	stats.remove_source("shrine")
	stats.add_mods("shrine", BLESSINGS[name]["mods"])
	stats.recalculate()
	blessing = name
	blessing_left = blessing_time
	Sound.play("shrine_done")
	announced.emit("Blessing of %s: %s for %d s" % [name, BLESSINGS[name]["desc"], int(blessing_time)], BLESSINGS[name]["color"])


func _update_blessing(delta: float) -> void:
	if blessing == "":
		return
	blessing_left -= delta
	if blessing_left <= 0.0:
		_player.stats.remove_source("shrine")
		_player.stats.recalculate()
		blessing = ""


func _update_orbs(delta: float) -> void:
	var hero := _player.pos2
	var reach := maxf(1.2, _player.stats.pickup_radius * 0.5)
	var i := _orbs.size() - 1
	while i >= 0:
		var o := _orbs[i]
		o["age"] += delta
		var mi: MeshInstance3D = o["node"]
		mi.position.y = 0.8 + sin(o["age"] * 3.0) * 0.12
		mi.rotation.y += delta * 2.0
		if hero.distance_to(o["at"]) <= reach:
			_player.heal(_player.stats.max_hp * 0.25)
			Sound.play("heal")
			Juice.burst(hero, 1.2, Color(1.0, 0.35, 0.4), 16, 3.0, 0.4, 0.6, 4.0)
			mi.queue_free()
			_orbs.remove_at(i)
		elif o["age"] > 60.0:
			mi.queue_free()
			_orbs.remove_at(i)
		i -= 1
