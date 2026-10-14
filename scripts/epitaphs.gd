class_name Epitaphs
extends Node3D
## Your past deaths haunt the realm. When a Classic night ends in death the
## hero's grave is remembered (MetaProgress.epitaphs): where it fell, who,
## how far, and what killed it. For the next three Classic nights in that
## realm a weathered headstone stands there with a pale candle on top. Find it
## (an edge arrow shows within GUIDE_RANGE), press E: a title card tells the
## tale, the fallen hero returns up to REWARD_SOULS souls, and the night gains
## Vengeance, +8% damage per grave claimed. Each grave pays once.
## Never recorded or spawned in Expedition campaign runs or the Daily Night.

signal announced(text: String, color: Color)
## A title card: (title, subtitle, color).
signal tale(title: String, subtitle: String, color: Color)

const MAX_PER_REALM := 4
const NIGHTS := 3
const MAX_DISTANCE := 55.0
const REWARD_SOULS := 30
const VENGEANCE := 0.08
const VENGEANCE_SOURCE := "vengeance"
const GUIDE_RANGE := 30.0
const REACH := 2.6
const RING_RANGE := 14.0
const COLOR := Color(0.62, 0.82, 1.0)

## The prompt for a grave in reach ("" for none), for the HUD.
var prompt := ""
var prompt_color := COLOR
var vengeance_stacks := 0
var claimed := 0

var _player: Player
var _army: Army
var _graves: Array[Dictionary] = [] # {"data", "node", "light", "phase"}
var _ring: MeshInstance3D
var _near := -1
var _t := 0.0


# --- the record (static; persisted in MetaProgress) ---------------------------------

## Epitaphs are for Classic nights only.
static func allowed(campaign: bool, daily: bool) -> bool:
	return not campaign and not daily


## Remembers a death. The grave is pulled to within MAX_DISTANCE of the realm
## origin so it can be found; at most MAX_PER_REALM per realm (oldest dropped).
static func record(realm: String, at: Vector2, hero: String, level: int, seconds: float, killer: String, souls: int) -> Dictionary:
	if at.length() > MAX_DISTANCE:
		at = at.normalized() * MAX_DISTANCE
	var entry := {"realm": realm, "x": at.x, "z": at.y, "hero": hero, "level": maxi(level, 1),
			"time": maxf(seconds, 0.0), "killer": killer, "souls": maxi(souls, 0),
			"nights_left": NIGHTS, "id": "%d-%d" % [Time.get_unix_time_from_system(), randi() % 1000000]}
	MetaProgress.epitaphs.append(entry)
	var mine := MetaProgress.epitaphs.filter(func(e: Dictionary) -> bool: return e["realm"] == realm)
	for k in mine.size() - MAX_PER_REALM:
		MetaProgress.epitaphs.erase(mine[k])
	MetaProgress.save()
	return entry


static func in_realm(realm: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in MetaProgress.epitaphs:
		if e["realm"] == realm:
			out.append(e.duplicate())
	return out


## A new Classic night begins: this realm's graves stand for it, then each
## has one night fewer. Those reaching 0 are removed after being returned.
static func begin_night(realm: String) -> Array[Dictionary]:
	var out := in_realm(realm)
	if out.is_empty():
		return out
	var kept: Array = []
	for e: Dictionary in MetaProgress.epitaphs:
		if e["realm"] == realm:
			e["nights_left"] = int(e["nights_left"]) - 1
			if int(e["nights_left"]) <= 0:
				continue
		kept.append(e)
	MetaProgress.epitaphs = kept
	MetaProgress.save()
	return out


static func remove(id: String) -> bool:
	for e: Dictionary in MetaProgress.epitaphs:
		if e["id"] == id:
			MetaProgress.epitaphs.erase(e)
			MetaProgress.save()
			return true
	return false


static func clock(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


## ["HERE FELL A BATTLEMAGE", "Level 34 · 11:42 · slain by Plague Bloater"].
static func tale_text(e: Dictionary) -> Array:
	var hero_name := String(HeroClass.data(String(e["hero"])).get("name", String(e["hero"]).capitalize()))
	var killer := String(e["killer"])
	return ["HERE FELL A %s" % hero_name.to_upper(),
			"Level %d · %s%s" % [int(e["level"]), clock(float(e["time"])), (" · slain by " + killer) if killer != "" else ""]]


## Reads one saved entry back, or {} if it is malformed.
static func clean(v: Variant) -> Dictionary:
	if not v is Dictionary: return {}
	var d: Dictionary = v
	for key in ["realm", "hero", "killer", "id"]:
		if not d.get(key, null) is String: return {}
	for key in ["x", "z", "level", "time", "souls", "nights_left"]:
		var n: Variant = d.get(key, null)
		if not (n is int or n is float) or not is_finite(n): return {}
	if int(d["nights_left"]) <= 0: return {}
	return {"realm": d["realm"], "x": float(d["x"]), "z": float(d["z"]), "hero": d["hero"],
			"level": int(d["level"]), "time": float(d["time"]), "killer": d["killer"],
			"souls": maxi(int(d["souls"]), 0), "nights_left": mini(int(d["nights_left"]), NIGHTS), "id": d["id"]}


# --- the graves in the world --------------------------------------------------------

func setup(player: Player, army: Army) -> void:
	_player = player
	_army = army
	_ring = HazardDirector.make_decal(self, Vector2.ZERO, Color(COLOR, 0.5), 0.85, 1.0)
	_ring.visible = false


## Stands a headstone for each entry (no collision: it is scenery you walk through).
func spawn(entries: Array) -> void:
	for e: Dictionary in entries:
		var root := Node3D.new()
		root.position = Vector3(float(e["x"]), 0.0, float(e["z"]))
		root.rotation.y = float(hash(String(e["id"])) % 628) * 0.01
		var mi := MeshInstance3D.new()
		mi.mesh = headstone_mesh()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		var light := OmniLight3D.new()
		light.light_color = COLOR
		light.light_energy = 0.9
		light.omni_range = 5.0
		light.position = Vector3(0, 1.5, 0)
		root.add_child(light)
		add_child(root)
		_graves.append({"data": e, "node": root, "light": light, "phase": randf() * TAU})


func grave_count() -> int:
	return _graves.size()


## A weathered headstone with a faint pale-blue candle flame on top.
static func headstone_mesh() -> ArrayMesh:
	var stone := Color(0.46, 0.47, 0.5)
	var dark := stone.darkened(0.28)
	var kit := MeshKit.new()
	kit.max_segments = 8
	kit.box(Vector3(1.3, 0.16, 0.7), MeshKit.at(Vector3(0, 0.08, 0), Vector3(0, 4, 0)), dark)
	kit.box(Vector3(0.9, 1.0, 0.24), MeshKit.at(Vector3(0, 0.62, 0), Vector3(2, 0, 1.5)), stone)
	kit.cylinder(0.45, 0.45, 0.24, MeshKit.at(Vector3(0, 1.12, 0), Vector3(90, 0, 0)), stone, 0.0, 8)
	kit.box(Vector3(0.05, 0.5, 0.26), MeshKit.at(Vector3(0.12, 0.7, 0), Vector3(0, 0, 18)), dark)
	kit.box(Vector3(0.4, 0.05, 0.26), MeshKit.at(Vector3(-0.1, 0.9, 0), Vector3(0, 0, -8)), dark)
	kit.box(Vector3(0.5, 0.1, 0.27), MeshKit.at(Vector3(-0.2, 0.2, 0), Vector3(0, 0, 4)), Color(0.22, 0.34, 0.2))
	kit.cylinder(0.05, 0.06, 0.2, MeshKit.at(Vector3(0, 1.66, 0)), Color(0.85, 0.85, 0.8), 0.2, 6)
	kit.sphere(0.08, MeshKit.at(Vector3(0, 1.85, 0), Vector3.ZERO, Vector3(0.8, 1.5, 0.8)), COLOR, 2.5, 6, 4)
	return kit.commit(Models.kit_material())


func tick(delta: float, allow_interaction := true) -> void:
	if _player == null:
		return
	_t += delta
	var hero := _player.pos2
	_near = -1
	var best := RING_RANGE * RING_RANGE
	for i in _graves.size():
		var g: Dictionary = _graves[i]
		var light := g["light"] as OmniLight3D
		if is_instance_valid(light):
			light.light_energy = 0.8 + 0.35 * sin(_t * 2.4 + float(g["phase"]))
		var d := hero.distance_squared_to(_grave_at(i))
		if d < best:
			best = d
			_near = i
	prompt = ""
	_ring.visible = _near >= 0
	if _near < 0:
		return
	var at := _grave_at(_near)
	_ring.position = Vector3(at.x, 0.03, at.y)
	_ring.scale = Vector3.ONE * 3.4 * (1.0 + 0.03 * sin(_t * 4.0))
	if hero.distance_to(at) <= REACH:
		var e: Dictionary = _graves[_near]["data"]
		var gain := mini(int(e["souls"]), REWARD_SOULS)
		prompt = "%s  Pay respects  ·  +%d souls, Vengeance +%d%% damage" % [Controls.tag("interact"), gain, roundi(VENGEANCE * 100.0)]
		if allow_interaction and Input.is_action_just_pressed("interact"):
			claim(_near)


func _grave_at(i: int) -> Vector2:
	var node := _graves[i]["node"] as Node3D
	return Vector2(node.position.x, node.position.z)


## Edge-arrow markers for the HUD, once a grave is within GUIDE_RANGE.
func markers() -> Array:
	var out := []
	if _player == null:
		return out
	for i in _graves.size():
		var at := _grave_at(i)
		if _player.pos2.distance_to(at) <= GUIDE_RANGE:
			out.append({"at": at, "color": COLOR, "label": "EPITAPH"})
	return out


## Pays one grave: souls through the normal soul path, then Vengeance. Once.
func claim(index: int) -> bool:
	if index < 0 or index >= _graves.size():
		return false
	var g: Dictionary = _graves[index]
	var e: Dictionary = g["data"]
	var gain := mini(int(e["souls"]), REWARD_SOULS)
	var at := _grave_at(index)
	for k in gain:
		_army.collect_soul(Army.soul_value(0, false, false))
	vengeance_stacks += 1
	claimed += 1
	var stats := _player.stats
	stats.remove_source(VENGEANCE_SOURCE)
	stats.add_mods(VENGEANCE_SOURCE, [{"stat": "damage", "op": PlayerStats.Op.INCREASED, "value": VENGEANCE * vengeance_stacks}])
	stats.recalculate()
	remove(String(e["id"]))
	var text := tale_text(e)
	tale.emit(text[0], text[1], COLOR)
	announced.emit("Vengeance. +%d%% damage for the night%s" % [roundi(VENGEANCE * 100.0 * vengeance_stacks), ("  ·  +%d souls" % gain) if gain > 0 else ""], COLOR)
	Sound.play("shrine_done")
	Juice.burst(at, 1.2, COLOR, 30, 4.0, 0.5, 0.9, 6.0)
	(g["node"] as Node3D).queue_free()
	_graves.remove_at(index)
	_near = -1
	prompt = ""
	_ring.visible = false
	return true
