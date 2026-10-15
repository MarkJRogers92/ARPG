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
signal reward_revealed(title: String, detail: String, color: Color)

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
	"Haste": {"color": Color(0.4, 1.0, 0.6), "desc": "+35% move speed and bolt fire rate",
		"mods": [{"stat": "move_speed", "op": PlayerStats.Op.MORE, "value": 0.35},
			{"stat": "bolt_rate", "op": PlayerStats.Op.MORE, "value": 0.35}]},
	"Plenty": {"color": Color(1.0, 0.85, 0.3), "desc": "double XP and souls",
		"mods": [{"stat": "xp_gain", "op": PlayerStats.Op.MORE, "value": 1.0},
			{"stat": "soul_chance", "op": PlayerStats.Op.MORE, "value": 1.0}]},
	"Warding": {"color": Color(0.5, 0.75, 1.0), "desc": "+150 armor (about half the damage)",
		"mods": [{"stat": "armor", "op": PlayerStats.Op.ADD, "value": 150.0}]},
}

## The blessing in effect ("" for none) and its seconds left.
var blessing := ""
var blessing_left := 0.0
## Nearby paired-shrine guidance; other interaction prompts retain priority.
var discovery_prompt := ""
var discovery_color := Color.WHITE

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
const SEAL_RADIUS := 5.0
const SEAL_CHARGE := 12.0
const SEAL_WINDOW := 35.0
const SEAL_BONUS := 5
const SEAL_COLOR := Color(0.35, 0.95, 0.8)
var _chest_panel: WagerPanel
var _chest_offer: Dictionary = {}
var chest_hint := ""
var _opportunity_started := false
var _opportunity_roll := {}
var _opportunity_attempt := ""

func configure_opportunity(roll: Dictionary = {}, attempt := "", consumed := false) -> void:
	_opportunity_roll = roll.duplicate(true)
	_opportunity_attempt = attempt
	_opportunity_started = consumed

## One optional, reachable shrine during the authored recovery phase. The
## campaign's roll is committed in town; nothing is granted until it charges.
func start_opportunity() -> bool:
	if _opportunity_started or _player == null: return false
	var at := _clear_spot(7.0, 10.0, shrine_radius + 0.5)
	if at == Vector2.INF: return false
	_opportunity_started = true
	_start_shrine(at, "Warding")
	var event: Dictionary = _events[-1]
	event["opportunity"] = true
	event["label"] = "ELEMENTAL SHRINE"
	announced.emit("RECOVERY DETOUR · charge the Elemental shrine for a Magic amulet; no guardians. " + RewardPools.selection_text("elemental"), Elements.COLORS[Elements.FROST])
	return true


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
	# A small rose rune circle on the ground under it (a child, so it goes with the orb).
	var ring := HazardDirector.make_decal(mi, Vector2.ZERO, Color(1.0, 0.3, 0.35, 0.6), 1.0, 1.7, Models.rune_material(Color(1.0, 0.32, 0.4, 0.6), 8.0))
	ring.position = Vector3(0.0, -0.72, 0.0)
	_orbs.append({"at": at, "node": mi, "age": 0.0})


# --- events --------------------------------------------------------------------

func _start_random() -> void:
	var kinds := ["shrine", "shrine", "goblin", "chest"]
	if _goblins.alive_count() > 0:
		kinds.erase("goblin")
	if _events.any(func(e: Dictionary) -> bool: return e["kind"] == "chest" and e.get("choice", false)):
		kinds.erase("chest")
	var kind: String = kinds.pick_random()
	# Somewhere off screen, clear of solid scenery so it can be reached.
	var at := _clear_spot(15.0, 19.0, shrine_radius + 0.5)
	if at == Vector2.INF:
		_timer = 5.0 # nowhere clear right now: try again shortly
		return
	match kind:
		"shrine":
			if not _start_crossroads(at):
				_start_shrine(at)
		"goblin":
			_goblin_left = goblin_time
			var near := _clear_spot(10.0, 12.0, 1.0)
			_goblins.spawn(near if near != Vector2.INF else at, _director.hp_multiplier())
			announced.emit("A treasure goblin! Catch it before it escapes!", Color(1.0, 0.85, 0.3))
			Sound.play("goblin")
		"chest":
			_start_chest(at, true)


## A random point `min_r`..`max_r` from the hero with `clearance` around it
## free of solid scenery, or Vector2.INF if none turned up.
func _clear_spot(min_r: float, max_r: float, clearance: float) -> Vector2:
	for attempt in 16:
		var at := _player.pos2 + Vector2.from_angle(randf() * TAU) * randf_range(min_r, max_r)
		if not Obstacles.blocked(at, clearance):
			return at
	return Vector2.INF


func _start_shrine(at: Vector2, chosen := "") -> void:
	var name: String = chosen if BLESSINGS.has(chosen) else BLESSINGS.keys().pick_random()
	_events.append(_make_shrine(at, name))
	announced.emit("A Shrine of %s appears nearby" % name, BLESSINGS[name]["color"])


func _make_shrine(at: Vector2, name: String) -> Dictionary:
	var color: Color = BLESSINGS[name]["color"]
	var root := Node3D.new()
	root.position = Vector3(at.x, 0.0, at.y)
	add_child(root)
	var model := MeshInstance3D.new()
	model.mesh = Models.shrine(color)
	root.add_child(model)
	var ring := HazardDirector.make_decal(root, Vector2.ZERO, Color(color, 0.7), 1.0, shrine_radius * 2.0, Models.rune_material(Color(color, 0.75), 12.0))
	var fill := HazardDirector.make_decal(root, Vector2.ZERO, Color(color, 0.3), 0.0, shrine_radius * 2.0)
	fill.scale = Vector3.ONE * 0.02
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 7.0
	light.light_cull_mask = 1
	light.position = Vector3(0, 3.0, 0)
	root.add_child(light)
	return {"kind": "shrine", "at": at, "node": root, "fill": fill, "ring": ring,
			"charge": 0.0, "blessing": name, "color": color, "label": "SHRINE", "age": 0.0}


## At most one paired discovery at a time. Unclear sites fall back to a normal
## shrine; authored campaign opportunities still call _start_shrine directly.
func _start_crossroads(at: Vector2) -> bool:
	if _events.any(func(e: Dictionary) -> bool: return e["kind"] == "crossroads"):
		return false
	var choices_at: Array[Vector2] = []
	for k in 8:
		var offset := Vector2.from_angle(float(k) * PI / 8.0) * (shrine_radius + 1.0)
		if not Obstacles.blocked(at - offset, shrine_radius + 0.5) and not Obstacles.blocked(at + offset, shrine_radius + 0.5):
			choices_at.assign([at - offset, at + offset])
			break
	if choices_at.is_empty(): return false
	var names := BLESSINGS.keys()
	var first: String = names.pick_random()
	names.erase(first)
	var second: String = names.pick_random()
	var parent := Node3D.new()
	add_child(parent)
	var choices: Array[Dictionary] = []
	for i in 2:
		var choice := _make_shrine(choices_at[i], first if i == 0 else second)
		(choice["node"] as Node3D).reparent(parent)
		var label := Label3D.new()
		label.font = UiStyle.EMPHASIS
		label.text = "%s\n%s" % [String(choice["blessing"]).to_upper(), BLESSINGS[choice["blessing"]]["desc"]]
		label.font_size = 32
		label.outline_size = 5
		label.pixel_size = 0.010
		label.position = Vector3(0,2.8,1.8)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = RunUi.TEXT
		label.no_depth_test = false
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(choice["node"] as Node3D).add_child(label)
		choices.append(choice)
	_events.append({"kind":"crossroads", "at":at, "node":parent, "choices":choices,
		"color":Color(0.9,0.8,1.0), "label":"CHOOSE A BLESSING", "age":0.0, "claimed":false})
	announced.emit("Crossroads shrine · %s or %s? Hold one circle; the other fades." % [first,second], Color(0.9,0.8,1.0))
	return true


func _update_crossroads(e: Dictionary, hero: Vector2, delta: float) -> bool:
	if bool(e["claimed"]): return true
	if _player.dead: return false
	for choice: Dictionary in e["choices"]:
		var inside := hero.distance_to(choice["at"]) <= shrine_radius
		var before: float = choice["charge"]
		choice["charge"] = clampf(before + (delta / shrine_charge_time if inside else -delta * 0.3), 0.0, 1.0)
		(choice["fill"] as MeshInstance3D).scale = Vector3.ONE * maxf(choice["charge"], 0.02)
		if inside and int(before * 4.0) != int(choice["charge"] * 4.0):
			Sound.play("shrine_charge", 1.0 + choice["charge"] * 0.5)
		if choice["charge"] >= 1.0:
			e["claimed"] = true # commit before any signal callback can re-enter
			_bless(choice["blessing"])
			Juice.ring(choice["at"], choice["color"], 40, 9.0, 0.6, 0.6)
			Juice.flash(choice["at"], choice["color"], 6.0, 12.0, 0.6)
			return true
	return false


func _refresh_discovery_prompt(hero: Vector2) -> void:
	discovery_prompt = ""
	var nearest := INF
	for e: Dictionary in _events:
		if e["kind"] == "chest" and e.get("choice", false) and not e["opened"]:
			var distance: float = hero.distance_to(e["at"])
			if distance <= 6.0 and distance < nearest:
				nearest = distance
				discovery_prompt = "%s · choose your challenge" % (Controls.tag("interact") + " Inspect chest" if distance <= 3.0 else "Approach cursed chest")
				discovery_color = e["color"]
		if e["kind"] != "crossroads" or bool(e["claimed"]): continue
		for choice: Dictionary in e["choices"]:
			var distance: float = hero.distance_to(choice["at"])
			if distance > shrine_radius + 4.0 or distance >= nearest: continue
			nearest = distance
			var name: String = choice["blessing"]
			var action := "Hold the circle · %d s blessing · choose one" % roundi(blessing_time)
			if distance <= shrine_radius:
				action = "Hold %.1f s · lasts %d s · choose one" % [ceilf((1.0 - float(choice["charge"])) * shrine_charge_time * 10.0) / 10.0,roundi(blessing_time)]
			discovery_prompt = "%s · %s" % [name.to_upper(), action]
			discovery_color = choice["color"]


func _start_chest(at: Vector2, offer_choice := false) -> void:
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
			"color": Color(0.75, 0.3, 1.0), "label": "ARMY CHEST", "theme": "army", "age": 0.0, "choice": offer_choice, "paid": false})
	announced.emit("Cursed chest nearby · inspect to choose your challenge." if offer_choice else "Army chest · defeat its guardians for a Legendary.", Color(0.8, 0.45, 1.0))


func _update_events(delta: float) -> void:
	if _player.dead: return
	chest_hint = ""
	var hero := _player.pos2
	var i := _events.size() - 1
	while i >= 0:
		var e := _events[i]
		e["age"] += delta
		var done := false
		match e["kind"]:
			"shrine":
				done = _update_shrine(e, hero, delta)
			"crossroads":
				done = _update_crossroads(e, hero, delta)
			"chest":
				done = _update_choice_chest(e, hero, delta) if e.get("choice", false) else _update_chest(e, hero)
		# Unused events fade away after a while.
		if not done and e["age"] > 90.0 and not e.get("opened", false):
			done = true
		if done:
			e["node"].queue_free()
			_events.remove_at(i)
		i -= 1
	_refresh_discovery_prompt(hero)
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
		if e.get("opportunity", false):
			var item := Item.from_dict(_opportunity_roll) if not _opportunity_roll.is_empty() else ItemGenerator.generate_with(ItemData.ilvl_for_player_level(_player.stats.level), ItemData.Rarity.MAGIC, "amulet", null, "elemental")
			if _opportunity_attempt != "": item.campaign_id = _opportunity_attempt + ":drop:opportunity"
			_loot.drop(item, e["at"])
			reward_revealed.emit("ELEMENTAL OFFERING", item.name + " · Magic amulet dropped; collect it to claim.", item.color())
		Juice.ring(e["at"], e["color"], 40, 9.0, 0.6, 0.6)
		Juice.flash(e["at"], e["color"], 6.0, 12.0, 0.6)
		return true
	return false


func _update_chest(e: Dictionary, hero: Vector2) -> bool:
	if e.get("paid", false): return true
	if _player.dead: return false
	if not e["opened"]:
		e["retry"] = maxf(e.get("retry", 0.0) - get_process_delta_time(), 0.0)
		if hero.distance_to(e["at"]) <= 1.8 and e["retry"] <= 0.0:
			e["opened"] = true
			Sound.play("chest")
			Sound.play("boss_roar", 1.4, -6.0)
			var n := 5 + Realm.index(Realm.current)
			# Guardians come from the horde's own kinds (not the rival, its
			# thralls, Debt Collectors or phylacteries, which never spawn on their own).
			var types := _swarms.filter(func(s: EnemySwarm) -> bool: return not s.boss and not s.flee and s.spawn_share > 0.0)
			for k in n:
				var swarm: EnemySwarm = types.pick_random()
				var at: Vector2 = e["at"] + Vector2.from_angle(TAU * k / n) * 7.0
				if swarm.spawn(at, _director.hp_multiplier(), true):
					e["guards"].append([swarm, swarm.ids[swarm.count - 1]])
			if e["guards"].is_empty():
				# The horde is at capacity: no guardians could rise. Try again
				# shortly rather than handing out a free Legendary.
				e["opened"] = false
				e["retry"] = 3.0
				return false
			e["label"] = "GUARDIANS"
			announced.emit("The chest's guardians awaken! Slay them all.", Color(0.8, 0.45, 1.0))
		return false
	# Opened: rewards once every guardian is dead.
	for g: Array in e["guards"]:
		var swarm: EnemySwarm = g[0]
		for k in swarm.count:
			if swarm.ids[k] == g[1] and swarm.hp[k] > 0.0:
				return false
	e["paid"] = true # Commit before callbacks; stale/reentrant updates cannot pay twice.
	var item := ItemGenerator.generate_with(ItemData.ilvl_for_player_level(_player.stats.level),
			ItemData.Rarity.LEGENDARY, ItemData.SLOTS.pick_random(), null, str(e.get("theme", "")))
	_loot.drop(item, e["at"])
	shards += 5
	Sound.play("chest")
	Juice.ring(e["at"], e["color"], 40, 8.0, 0.6, 0.6)
	Juice.flash(e["at"], e["color"], 6.0, 10.0, 0.5)
	announced.emit("The curse breaks!  +5 Soul Shards", Color(0.8, 0.45, 1.0))
	reward_revealed.emit("THE CURSE BREAKS", item.name + " · Legendary dropped; collect it to claim. +5 Soul Shards", item.color())
	return true


## Called by Main after other interactions and the full damage/death frame.
## No proximity opening: the player must inspect, then explicitly choose.
func offer_chest(allow_interaction := true) -> bool:
	if not allow_interaction or _player.dead or get_tree().paused: return false
	if not Input.is_action_just_pressed("interact"): return false
	for e: Dictionary in _events:
		if e["kind"] != "chest" or not e.get("choice", false) or e["opened"] or _player.pos2.distance_to(e["at"]) > 3.0: continue
		if _chest_panel == null:
			_chest_panel = WagerPanel.new()
			_chest_panel.heading = "Cursed chest"
			_chest_panel.flavor_text = "Break the curse. Choose how you fight."
			add_child(_chest_panel)
			_chest_panel.chosen.connect(_choose_chest)
		_chest_offer = e
		var n := 5 + Realm.index(Realm.current)
		_chest_panel.show_state({"prize":"An Army-themed Legendary awaits either victory.",
			"detail":"Hunt: %d champions. Sealbound: %d champions (+2)." % [n,n+2],
			"cards":{
				"hunt":{"eyebrow":"THE ORIGINAL CHALLENGE","title":"Hunt","reward":"Legendary  +  5 shards","challenge":"Defeat %d champions.\nFight anywhere. No time limit." % n},
				"seal":{"eyebrow":"OPTIONAL RITUAL","title":"Sealbound","reward":"Legendary  +  up to 10 shards","challenge":"Defeat %d champions (+2).\nHold the 5 m circle for 12 s within 35 s.\nComplete it for +5 bonus shards." % (n+2)}},
			"odds":"Leaving the circle drains charge at half speed. Timeout loses only the +5 bonus.\nThe Legendary and base 5 shards still drop when every champion falls.",
			"result":"Leave freely. Save & Quit ends unfinished chests and rituals.",
			"actions":[["hunt","Choose Hunt",true],["seal","Choose Sealbound",not Obstacles.blocked(e["at"],SEAL_RADIUS+0.5)],["leave","Leave",true]]})
		get_tree().paused = true
		return true
	return false


func _choose_chest(action: String) -> void:
	if _chest_offer.is_empty() or _chest_panel == null or not _chest_panel.is_open(): return
	var e := _chest_offer
	_chest_offer = {} # clear before any external callback or repeat click
	_chest_panel.close()
	get_tree().paused = false
	if action not in ["hunt","seal"] or _player.dead or not _events.has(e) or e["opened"]: return
	if action == "seal" and Obstacles.blocked(e["at"],SEAL_RADIUS+0.5): return
	var n := 5 + Realm.index(Realm.current) + (2 if action == "seal" else 0)
	# Reserve a complete plan first: no partial encounter or free reward at capacity.
	var types := _swarms.filter(func(s: EnemySwarm) -> bool: return not s.boss and not s.flee and s.spawn_share > 0.0)
	var plan: Array = []
	var reserved := {}
	for k in n:
		var candidates := types.filter(func(s: EnemySwarm) -> bool: return s.count + int(reserved.get(s,0)) < s.capacity)
		if candidates.is_empty(): break
		var swarm: EnemySwarm = candidates.pick_random()
		var at := Vector2.INF
		for attempt in 16:
			var p: Vector2 = e["at"] + Vector2.from_angle(TAU * (float(k)/n + float(attempt)/16.0)) * (7.0 + float(attempt % 3))
			if not Obstacles.blocked(p,swarm.radius * swarm.elite_scale + 0.5) and plan.all(func(row: Array) -> bool: return p.distance_to(row[1]) > 2.0): at = p; break
		if at == Vector2.INF: break
		plan.append([swarm,at]); reserved[swarm] = int(reserved.get(swarm,0)) + 1
	if plan.size() != n:
		announced.emit("No room for all champions. The chest stays sealed; try again later.",UiStyle.MUTED)
		return
	e["opened"] = true
	e["seal"] = action == "seal"
	e["left"] = SEAL_WINDOW
	e["charge"] = 0.0
	e["bonus_paid"] = false
	for spawn_plan: Array in plan:
		var swarm: EnemySwarm = spawn_plan[0]
		swarm.spawn(spawn_plan[1],_director.hp_multiplier(),true)
		e["guards"].append([swarm,swarm.ids[swarm.count-1]])
	e["label"] = "SEALBOUND" if e["seal"] else "GUARDIANS"
	if e["seal"]:
		e["seal_ring"] = HazardDirector.make_decal(e["node"],Vector2.ZERO,Color(SEAL_COLOR,0.85),1.0,SEAL_RADIUS*2.0/0.82) # ground_glow outline is at UV radius 0.82
		e["seal_fill"] = HazardDirector.make_decal(e["node"],Vector2.ZERO,Color(SEAL_COLOR,0.16),0.0,SEAL_RADIUS*2.0)
		for key: String in ["seal_ring","seal_fill"]:
			(e[key].material_override as ShaderMaterial).set_shader_parameter("pulse_speed",0.0)
		var label := Label3D.new()
		label.font = UiStyle.EMPHASIS
		label.position = Vector3(0,2.0,0); label.font_size = 26; label.pixel_size = 0.010
		label.outline_size = 4; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = SEAL_COLOR; (e["node"] as Node3D).add_child(label); e["seal_label"] = label
	Sound.play("chest")
	announced.emit("%d champions awakened. %s" % [n,"Charge the seal for +5 shards; base reward survives timeout." if e["seal"] else "Slay them all for the original chest reward."],e["color"])


func _update_choice_chest(e: Dictionary, hero: Vector2, delta: float) -> bool:
	if _player.dead: return false
	if not e["opened"]: return false
	if e.get("finished",false): return true
	if e["seal"] and e["left"] > 0.0 and e["charge"] < SEAL_CHARGE:
		var step := minf(maxf(delta,0.0),float(e["left"]))
		e["charge"] = clampf(e["charge"] + (step if hero.distance_to(e["at"]) <= SEAL_RADIUS else -step*0.5),0.0,SEAL_CHARGE)
		e["left"] = maxf(float(e["left"]) - step,0.0)
		if e["left"] <= 0.0 and e["charge"] < SEAL_CHARGE:
			announced.emit("Seal expired. No bonus; your Legendary +5 shards still await the champions' defeat.",UiStyle.MUTED)
	var base_ready := _update_chest(e,hero)
	if not e["seal"]:
		e["finished"] = base_ready
		return base_ready
	var charged: bool = e["charge"] >= SEAL_CHARGE
	e["label"] = "GUARDIANS + BONUS" if charged else ("GUARDIANS" if e["left"] <= 0.0 else "SEALBOUND")
	var alive := 0
	for g: Array in e["guards"]:
		var swarm: EnemySwarm = g[0]
		for i in swarm.count:
			if swarm.ids[i] == g[1] and swarm.hp[i] > 0.0: alive += 1; break
	var state := "BONUS SECURED" if charged else ("BONUS EXPIRED" if e["left"] <= 0.0 else "SEAL %.1f / 12 s · %d s left" % [float(e["charge"]),ceili(e["left"])])
	chest_hint = "%s  /  %d champion%s%s" % [state,alive,"" if alive==1 else "s","  /  base reward dropped" if e["paid"] else ""]
	(e["seal_label"] as Label3D).text = "Return to charge" if not charged and e["left"] > 0 and hero.distance_to(e["at"]) > SEAL_RADIUS else "SEALBOUND"
	(e["seal_label"] as Label3D).visible = not charged and e["left"] > 0
	(e["seal_fill"] as MeshInstance3D).scale = Vector3.ONE * maxf(float(e["charge"])/SEAL_CHARGE,0.02)
	(e["seal_ring"] as MeshInstance3D).visible = e["left"] > 0 and not charged
	(e["seal_fill"] as MeshInstance3D).visible = e["left"] > 0 and not charged
	if base_ready and (charged or e["left"] <= 0.0):
		e["finished"] = true
		if charged and not e["bonus_paid"]:
			e["bonus_paid"] = true
			shards += SEAL_BONUS
			announced.emit("Sealbound complete! +5 bonus Soul Shards.",SEAL_COLOR)
		chest_hint = ""
		return true
	return false


func _on_goblin_died(at: Vector2, _xp: int) -> void:
	var ilvl := ItemData.ilvl_for_player_level(_player.stats.level)
	for k in 3:
		_loot.drop(ItemGenerator.generate(ilvl, 1.5 + _player.stats.magic_find), at)
	for k in 20:
		var overflow := _gems.drop(at + Vector2.from_angle(randf() * TAU) * randf_range(0.5, 2.5), 6)
		if overflow > 0:
			_player.add_xp(overflow) # the gem pool is full: pay the XP directly
	shards += 3
	drop_orb(at + Vector2(1.0, 0.0))
	Sound.play("goblin", 0.7)
	Juice.burst(at, 0.8, Color(1.0, 0.85, 0.3), 40, 7.0, 0.5, 0.8, 6.0)
	announced.emit("Goblin caught!  +3 Soul Shards", Color(1.0, 0.85, 0.3))


# --- blessings and orbs ------------------------------------------------------------

func _bless(name: String) -> void:
	bless_for(name, blessing_time)


## A blessing that lasts `seconds` (shrines: blessing_time; the Cauldron: 45 s).
func bless_for(name: String, seconds: float) -> void:
	var stats := _player.stats
	stats.remove_source("shrine")
	stats.add_mods("shrine", BLESSINGS[name]["mods"])
	stats.recalculate()
	blessing = name
	blessing_left = seconds
	_player.warding_charge_left = 0.0
	if name == "Warding" and _player.challenge_id == "":
		_player.empower_warding(seconds)
	Sound.play("shrine_done")
	announced.emit("Blessing of %s: %s · %d s%s" % [name, "+150 armor" if name == "Warding" else BLESSINGS[name]["desc"], int(seconds), "\nNext dash: 20 base frost damage / 3 m. Spent on use, even on a miss." if name == "Warding" and _player.challenge_id == "" else ""], BLESSINGS[name]["color"])


func _update_blessing(delta: float) -> void:
	if blessing == "":
		return
	blessing_left -= delta
	if blessing_left <= 0.0:
		_player.warding_charge_left = 0.0
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
