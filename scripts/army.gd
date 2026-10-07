class_name Army
extends Node3D
## The Soul Army: spectral copies of slain enemies that fight for the hero.
##
## Kills sometimes leave a soul (a pale crystal on the ground, in the Souls
## GemSwarm). Each soul remembers what kind of enemy it came from. Once the
## hero has gathered `soul_cost` of them and the army has room
## (`minion_max`), the kind most of those souls came from rises as a minion.
## An elite's soul raises an elite champion straight away, and a boss's soul
## binds the boss itself; when the army is full, the newest common minion
## makes way for them.
##
## Each minion keeps a piece of what it was (its "role", from its enemy type):
##   brawler     cleaves around its target (most enemies)
##   caster      fights from range with soul bolts (ranged enemies)
##   bulwark     every few seconds slams the ground, hurling the horde back (big enemies)
##   skirmisher  darts in and strikes fast (fast enemies)
##   tyrant      a bound boss: a crushing slam on a long cooldown
##
## Veterans: minions count their kills. Enough of them and a minion earns a
## name and a rank (RANKS), hitting harder and lasting longer with each, with
## its name over its head. After a night the greatest is laid to rest in the
## Crypt (MetaProgress.entomb) and can rise beside the hero in another; if a
## veteran from the Crypt falls, it's gone for good.
##
## Minions are few (a dozen or two), so they're simple arrays and per-type
## MultiMeshes rebuilt every frame. They hunt the enemy nearest to them (within
## reach of the hero), cleave what's around their target, take contact damage
## from the horde, and drift back to the hero when there's nothing to fight.

signal raised(kind: String)
## A minion earned a name or a higher rank.
signal promoted(text: String)
## A named veteran was destroyed (crypt: its Crypt id, or -1).
signal veteran_fell(vet_name: String, crypt: int)

const CAPACITY := 40
const SIGHT := 11.0 # how far a minion looks for prey
const LEASH := 15.0 # targets must be this close to the hero
const ATTACK_INTERVAL := 0.4
const RETARGET := 0.35
const ROLES := {
	"brawler": {"label": "Brawler", "interval": 0.4, "range": 0.6, "speed": 1.0},
	"caster": {"label": "Caster", "interval": 0.9, "range": 7.0, "speed": 0.9},
	"bulwark": {"label": "Bulwark", "interval": 0.5, "range": 0.6, "speed": 0.9},
	"skirmisher": {"label": "Skirmisher", "interval": 0.22, "range": 0.5, "speed": 1.4},
	"tyrant": {"label": "Tyrant", "interval": 0.5, "range": 0.8, "speed": 1.0},
}
## Kills to reach each rank, and how much harder it hits and how much more
## it can take.
const RANKS := [
	{"label": "", "kills": 0, "power": 1.0},
	{"label": "Veteran", "kills": 60, "power": 1.3},
	{"label": "Hero", "kills": 300, "power": 1.7},
	{"label": "Legend", "kills": 1000, "power": 2.3},
]
const NAMES := ["Morwen", "Grimwald", "Hollis", "Sable", "Corvin", "Ashka", "Bram", "Vesper", "Mordecai", "Isolde",
	"Tobiah", "Wren", "Osric", "Nell", "Thane", "Ysolde", "Garrick", "Lenore", "Fenwick", "Ruth",
	"Silas", "Agatha", "Edric", "Maud", "Caspian", "Hester", "Ulric", "Briar", "Lazarus", "Odile"]
const EPITHETS := {
	"brawler": ["the Butcher", "Grave-Fist", "the Unbowed", "Bonebreaker"],
	"caster": ["the Whisperer", "Soul-Singer", "the Pale Voice", "Candlewick"],
	"bulwark": ["the Wall", "Ironhide", "the Unmoving", "Gravestone"],
	"skirmisher": ["Quickbones", "the Shade", "Swift-Rot", "the Flicker"],
	"tyrant": ["the Bound King", "the Chained", "Oathbreaker", "the Crownless"],
}
const VETERAN_COLOR := Color(1.0, 0.82, 0.45)

## Seconds between a bulwark's / tyrant's slams.
const SLAM_INTERVAL := 3.0
const TYRANT_INTERVAL := 4.5

## How the hero's stats scale for each enemy type: tougher types make tougher
## minions. Built in setup() from each EnemySwarm's own stats.
var _types: Array[Dictionary] = []
var _type_of := {} # EnemySwarm -> index in _types

## Souls gathered toward the next minion, and which kinds they came from.
var souls := 0
var _votes := {}

var count := 0
var _type := PackedInt32Array()
var _pos := PackedVector2Array()
var _hp := PackedFloat32Array()
var _max_hp := PackedFloat32Array()
var _elite := PackedByteArray() # rank: 0 common, 1 elite, 2 boss
var _attack := PackedFloat32Array()
var _retarget := PackedFloat32Array()
var _hurt := PackedFloat32Array()
var _facing := PackedVector2Array()
var _phase := PackedFloat32Array()
var _slam := PackedFloat32Array()
## Current target per minion: swarm index and enemy id (-1 = none).
var _target_swarm := PackedInt32Array()
var _target_id := PackedInt32Array()
var _target_index := PackedInt32Array()
## Veterans: kills, rank (index in RANKS), name, Crypt id (-1: raised this
## night), and the name tag over its head (null below Veteran).
var _deeds := PackedInt32Array()
var _rank := PackedByteArray()
var _vname: Array[String] = []
var _crypt := PackedInt32Array()
var _tag: Array = []

var _player: Player
var _swarms: Array[EnemySwarm] = []
var _soulfire: Array[Vector2] = []


func setup(player: Player, swarms: Array[EnemySwarm]) -> void:
	_player = player
	_swarms = swarms
	_type.resize(CAPACITY)
	_target_swarm.resize(CAPACITY)
	_target_id.resize(CAPACITY)
	_target_index.resize(CAPACITY)
	_hp.resize(CAPACITY)
	_max_hp.resize(CAPACITY)
	_attack.resize(CAPACITY)
	_retarget.resize(CAPACITY)
	_hurt.resize(CAPACITY)
	_phase.resize(CAPACITY)
	_slam.resize(CAPACITY)
	_pos.resize(CAPACITY)
	_facing.resize(CAPACITY)
	_elite.resize(CAPACITY)
	_deeds.resize(CAPACITY)
	_rank.resize(CAPACITY)
	_vname.resize(CAPACITY)
	_crypt.resize(CAPACITY)
	_tag.resize(CAPACITY)
	for s in swarms:
		var t := {
			"swarm": s, "name": s.display_name if s.display_name != "" else String(s.name),
			"hp": 10.0 if s.boss else clampf(s.max_hp / 10.0, 1.0, 4.0),
			"damage": 5.0 if s.boss else clampf(s.contact_dps / 5.0, 0.6, 2.5),
			"speed": maxf(s.move_speed * 1.3, 4.5),
			"radius": s.radius,
			"role": role_of(s),
		}
		var mmi := MultiMeshInstance3D.new()
		var mat := Models.material("enemy", {
			"height": s.body_height, "spectral": true,
			"stride_speed": minf(t["speed"] / s.body_height * 4.2, 16.0),
			"quadruped": s.model == "runner", "leg_height": 0.36 if s.model == "runner" else 0.3,
		}, "spectral_" + t["name"])
		MultiMeshUtil.setup(mmi, Models.enemy(s.model, s.color, s.body_height), 8 if s.boss else CAPACITY, mat)
		mmi.layers = 2
		add_child(mmi)
		t["mmi"] = mmi
		_type_of[s] = _types.size()
		_types.append(t)


## What a raised enemy of this type does (see ROLES).
static func role_of(s: EnemySwarm) -> String:
	if s.boss:
		return "tyrant"
	if s.attack_range > 0.0 or s.hold_range > 0.0:
		return "caster"
	if s.charger:
		return "skirmisher"
	if s.max_hp >= 60.0:
		return "bulwark"
	if s.move_speed >= 4.5 and not s.flee:
		return "skirmisher"
	return "brawler"


func role(k: int) -> String:
	return _types[_type[k]]["role"]


func type_index(swarm: EnemySwarm) -> int:
	return _type_of.get(swarm, 0)


## Souls are encoded as gem values: type + 1, +100 for an elite, +200 for a boss.
static func soul_value(type: int, elite: bool, boss: bool) -> int:
	return type + 1 + (200 if boss else (100 if elite else 0))


func collect_soul(value: int) -> void:
	var type := (value % 100) - 1
	if value >= 200:
		_raise(type, true, true)
	elif value >= 100:
		_raise(type, true, false)
	else:
		souls += 1
		_votes[type] = _votes.get(type, 0) + 1
		_try_raise()


func _try_raise() -> void:
	var stats := _player.stats
	if souls < stats.soul_cost or count >= stats.minion_max:
		return
	var best := 0
	for t: int in _votes:
		if _votes[t] > _votes.get(best, -1):
			best = t
	souls = 0
	_votes.clear()
	_raise(best, false, false)


func _raise(type: int, elite: bool, boss: bool) -> bool:
	if type < 0 or type >= _types.size():
		return false
	var stats := _player.stats
	if boss and _count_type(type) > 0:
		boss = false
		elite = true
		type = 0
	if count >= maxi(stats.minion_max, 1) or count >= CAPACITY:
		if not (elite or boss):
			return false
		# Champions push out the newest common minion (sparing veterans).
		var victim := _expendable()
		if victim < 0 or _rank[victim] > 0:
			return false
		_remove(victim, false, false)
	var t: Dictionary = _types[type]
	var k := count
	count += 1
	_type[k] = type
	_pos[k] = _player.pos2 + Vector2.from_angle(randf() * TAU) * 1.5
	# Rank: 0 common, 1 elite champion, 2 bound boss. Only commons make way.
	_elite[k] = 2 if boss else (1 if elite else 0)
	_max_hp[k] = stats.minion_hp * t["hp"] * (2.0 if elite else 1.0)
	_hp[k] = _max_hp[k]
	_attack[k] = 0.0
	_retarget[k] = 0.0
	_hurt[k] = 0.0
	_facing[k] = Vector2(0, -1)
	_phase[k] = randf()
	_target_id[k] = -1
	_deeds[k] = 0
	_rank[k] = 0
	_vname[k] = ""
	_crypt[k] = -1
	_tag[k] = null
	Juice.ring(_pos[k], Color(0.45, 0.8, 1.0), 24, 5.0, 0.45, 0.5)
	Juice.burst(_pos[k], 0.3, Color(0.6, 0.9, 1.0), 18, 1.5, 0.45, 0.9, 6.0)
	Juice.flash(_pos[k], Color(0.45, 0.8, 1.0), 3.0, 6.0, 0.4)
	Sound.play("minion_raise")
	_slam[k] = randf_range(0.5, 1.5)
	raised.emit("%s %s" % [t["name"], "(%s)" % ROLES[t["role"]]["label"]])
	return true


## Minions away from the army (pledged to the Ferryman, or seized by a Debt
## Collector): [{"type", "elite", "hp_frac", "back_in"}]. back_in < 0 means
## "until released".
var away: Array[Dictionary] = []


## Takes one minion out of the army without killing it (a common one if there
## is one). Returns its record, or {} if the army is empty. `back_in`: seconds
## until it returns by itself (-1 = until release_away()).
func send_away(back_in: float) -> Dictionary:
	if count == 0:
		return {}
	var victim := _expendable()
	if victim < 0:
		victim = count - 1
	var record := {"type": _type[victim], "elite": _elite[victim], "hp_frac": _hp[victim] / maxf(_max_hp[victim], 1.0),
			"back_in": back_in, "name": _types[_type[victim]]["name"], "vet": _veteran_record(victim)}
	Juice.burst(_pos[victim], 1.0, Color(0.55, 0.85, 1.0), 16, 3.0, 0.4, 0.6, 3.0)
	_remove(victim, false, false)
	away.append(record)
	return record


## Brings back every minion held until release (a Collector died).
func release_away() -> int:
	var n := 0
	for r in away:
		if r["back_in"] < 0.0:
			r["back_in"] = 0.0
			n += 1
	return n


## Returning minions come back as they were, when there's room.
func _update_away(delta: float) -> void:
	var i := away.size() - 1
	while i >= 0:
		var r := away[i]
		if r["back_in"] >= 0.0:
			r["back_in"] -= delta
			# A common one waits for a free place; champions make their own.
			if r["back_in"] <= 0.0 and count < CAPACITY and (r["elite"] > 0 or count < maxi(_player.stats.minion_max, 1)):
				if _raise(r["type"], r["elite"] == 1, r["elite"] == 2):
					var k := count - 1
					if r.get("vet", {}).get("rank", 0) > 0:
						_make_veteran(k, r["vet"])
					_hp[k] = _max_hp[k] * clampf(r["hp_frac"], 0.2, 1.0)
					away.remove_at(i)
		i -= 1


## Brings every minion to `at` (the hero stepped through a rift).
func gather(at: Vector2) -> void:
	for k in count:
		_pos[k] = at + Vector2.from_angle(TAU * k / maxf(count, 1.0)) * 2.0


## Gives up one minion (a common one if there is one; the Soul Altar).
func sacrifice() -> bool:
	if count == 0:
		return false
	var victim := _expendable()
	if victim < 0:
		victim = count - 1
	if _rank[victim] > 0:
		veteran_fell.emit(_vname[victim], _crypt[victim])
	Juice.burst(_pos[victim], 1.0, Color(0.55, 0.85, 1.0), 20, 3.0, 0.4, 0.8, 5.0)
	_remove(victim, false, false)
	return true


## The minion to give up first: a common one, the least proven, the newest.
## -1 if every minion is a champion.
func _expendable() -> int:
	var best := -1
	for k in range(count - 1, -1, -1):
		if _elite[k] == 0 and (best < 0 or _rank[k] < _rank[best] or (_rank[k] == _rank[best] and _deeds[k] < _deeds[best])):
			best = k
	return best


# --- veterans ---------------------------------------------------------------------

## Credits minion `k` with `kills`, promoting it when it earns a rank.
func credit(k: int, kills: int) -> void:
	_deeds[k] += kills
	while _rank[k] < RANKS.size() - 1 and _deeds[k] >= RANKS[_rank[k] + 1]["kills"]:
		_promote(k)


func _promote(k: int) -> void:
	var before: float = RANKS[_rank[k]]["power"]
	_rank[k] += 1
	var rank: Dictionary = RANKS[_rank[k]]
	_max_hp[k] *= rank["power"] / before
	_hp[k] = _max_hp[k]
	var t: Dictionary = _types[_type[k]]
	if _vname[k] == "":
		_vname[k] = "%s %s" % [NAMES.pick_random(), (EPITHETS[t["role"]] as Array).pick_random()]
		promoted.emit("Your %s has earned a name: %s, Veteran (%d kills)" % [t["name"], _vname[k], _deeds[k]])
	else:
		promoted.emit("%s rises to %s! (%d kills)" % [_vname[k], rank["label"], _deeds[k]])
	_update_tag(k)
	Juice.ring(_pos[k], VETERAN_COLOR, 28, 6.0, 0.5, 0.6)
	Juice.burst(_pos[k], 0.6, VETERAN_COLOR, 24, 3.0, 0.45, 0.8, 6.0)
	Sound.play("shrine_done", 1.3, -6.0)


func _update_tag(k: int) -> void:
	if _rank[k] == 0:
		return
	var tag: Label3D = _tag[k]
	if tag == null:
		tag = Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.fixed_size = true
		tag.pixel_size = 0.0006
		tag.font_size = 30
		tag.outline_size = 9
		tag.outline_modulate = Color(0, 0, 0, 0.85)
		tag.modulate = VETERAN_COLOR
		add_child(tag)
		_tag[k] = tag
		# A gold ring on the ground under it (moved with the tag in _draw()).
		var ring := HazardDirector.make_decal(tag, Vector2.ZERO, Color(VETERAN_COLOR, 0.55), 1.0, 2.0)
		ring.top_level = true
	tag.text = "%s  %s" % ["★".repeat(_rank[k]), _vname[k]]
	(tag.get_child(0) as Node3D).scale = Vector3.ONE * (0.9 + 0.2 * _rank[k])


## Everything that makes minion `k` a veteran, to keep or bring back.
func _veteran_record(k: int) -> Dictionary:
	var t: Dictionary = _types[_type[k]]
	return {"crypt": _crypt[k], "name": _vname[k], "swarm": String(t["swarm"].name), "label": t["name"], "role": t["role"],
			"elite": _elite[k], "deeds": _deeds[k], "rank": _rank[k], "slot": k}


func _make_veteran(k: int, rec: Dictionary) -> void:
	_vname[k] = rec["name"]
	_deeds[k] = rec["deeds"]
	_crypt[k] = rec.get("crypt", -1)
	var rank := clampi(rec["rank"], 0, RANKS.size() - 1)
	_rank[k] = rank
	_max_hp[k] *= RANKS[rank]["power"]
	_hp[k] = _max_hp[k]
	_update_tag(k)


## The living veterans, greatest first.
func veterans() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for k in count:
		if _rank[k] > 0:
			out.append(_veteran_record(k))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["deeds"] > b["deeds"])
	return out


## After a night has been laid to rest: minion `slot` now belongs to the Crypt.
func mark_crypt(slot: int, id: int) -> void:
	if slot >= 0 and slot < count:
		_crypt[slot] = id


## Raises a veteran from the Crypt at the hero's side. False if it couldn't.
func raise_veteran(rec: Dictionary) -> bool:
	var type := 0
	for t in _types.size():
		if String(_types[t]["swarm"].name) == rec.get("swarm", ""):
			type = t
			break
	var boss: bool = _types[type]["swarm"].boss
	if not _raise(type, int(rec.get("elite", 0)) == 1 and not boss, boss):
		return false
	var rec2 := rec.duplicate()
	rec2["crypt"] = rec.get("id", -1)
	_make_veteran(count - 1, rec2)
	Juice.ring(_pos[count - 1], VETERAN_COLOR, 40, 9.0, 0.7, 0.8)
	return true


func _count_type(type: int) -> int:
	var n := 0
	for k in count:
		if _type[k] == type:
			n += 1
	return n


func step(delta: float) -> void:
	Elements.source = "Soul Army"
	if not away.is_empty():
		_update_away(delta)
	var hero := _player.pos2
	var stats := _player.stats
	var k := count - 1
	while k >= 0:
		var t: Dictionary = _types[_type[k]]
		var p := _pos[k]
		# Too far behind (the hero ran off): reappear at the hero's side.
		if p.distance_squared_to(hero) > 30.0 * 30.0:
			p = hero + Vector2.from_angle(randf() * TAU) * 2.0
		_retarget[k] -= delta
		if _retarget[k] <= 0.0 or not _target_alive(k):
			_retarget[k] = RETARGET
			_find_target(k, p, hero)

		var r: Dictionary = ROLES[t["role"]]
		var goal := p
		var reach: float = t["radius"] + r["range"]
		var fighting := false
		if _target_alive(k):
			var swarm := _swarms[_target_swarm[k]]
			var enemy := swarm.pos[_target_index[k]]
			goal = enemy
			reach += swarm.radius
			fighting = p.distance_to(enemy) <= reach
		else:
			# Nothing to fight: fall in around the hero.
			var slot := Vector2.from_angle(TAU * k / maxf(count, 1.0) + 0.5) * (2.2 + 0.4 * (k % 3))
			goal = hero + slot
			reach = 0.4

		var to := goal - p
		var d := to.length()
		if d > reach:
			var speed: float = t["speed"] * r["speed"]
			if not fighting and p.distance_to(hero) > 8.0:
				speed = maxf(speed, stats.move_speed * 1.2)
			p += to / d * minf(speed * delta, d - reach * 0.9)
			_facing[k] = to / d
		elif d > 0.01:
			_facing[k] = to / d
		# Keep minions from stacking on each other.
		for j in count:
			if j != k:
				var away := p - _pos[j]
				var dd := away.length_squared()
				if dd < 0.8 and dd > 0.0001:
					p += away / sqrt(dd) * delta * 2.0
		_pos[k] = p

		_attack[k] -= delta
		_slam[k] -= delta
		var deaths_before := EnemySwarm.deaths
		if fighting and _attack[k] <= 0.0:
			var interval: float = r["interval"]
			_attack[k] = interval
			# Damage per second matches across roles; the rhythm differs.
			var dmg: float = stats.minion_damage * t["damage"] * interval * (2.0 if _elite[k] == 1 else 1.0) * RANKS[_rank[k]]["power"]
			var target := _swarms[_target_swarm[k]].pos[_target_index[k]]
			match t["role"]:
				"caster":
					_soul_bolt(p, target, dmg)
				"skirmisher":
					_cleave(target, dmg, 0.6)
					p += (target - p).normalized() * 0.4 # darting in
					_pos[k] = p
				_:
					_cleave(target, dmg)
		if fighting and _slam[k] <= 0.0 and (t["role"] == "bulwark" or t["role"] == "tyrant"):
			var tyrant: bool = t["role"] == "tyrant"
			_slam[k] = TYRANT_INTERVAL if tyrant else SLAM_INTERVAL
			_ground_slam(p, 4.5 if tyrant else 3.0, stats.minion_damage * t["damage"] * (3.0 if tyrant else 1.5) * RANKS[_rank[k]]["power"], tyrant)
		if EnemySwarm.deaths > deaths_before:
			credit(k, EnemySwarm.deaths - deaths_before)

		_hurt[k] -= delta
		if _hurt[k] <= 0.0:
			_hurt[k] = 0.25
			_hp[k] -= _contact_damage(p, t["radius"]) * 0.25
			if _hp[k] <= 0.0:
				_remove(k, true)
		k -= 1
	_draw()


func _target_alive(k: int) -> bool:
	if _target_id[k] < 0:
		return false
	var swarm := _swarms[_target_swarm[k]]
	var i := _target_index[k]
	if i >= swarm.count or swarm.ids[i] != _target_id[k] or swarm.hp[i] <= 0.0:
		_target_id[k] = -1
		return false
	return true


func _find_target(k: int, p: Vector2, hero: Vector2) -> void:
	_target_id[k] = -1
	var best := SIGHT * SIGHT
	for s in _swarms.size():
		var swarm := _swarms[s]
		var n := swarm.grid.query(p, SIGHT)
		var res := swarm.grid.results
		for j in n:
			var i := res[j]
			if swarm.hp[i] <= 0.0 or swarm.pos[i].distance_squared_to(hero) > LEASH * LEASH:
				continue
			var d2 := p.distance_squared_to(swarm.pos[i])
			if d2 < best:
				best = d2
				_target_swarm[k] = s
				_target_index[k] = i
				_target_id[k] = swarm.ids[i]


## A minion's swing hits everything right around its target.
func _cleave(at: Vector2, dmg: float, radius := 1.0) -> void:
	Elements.hit_area(at, radius, dmg, Elements.NONE, _player.stats.crit_chance, _player.stats.crit_mult)
	Juice.burst(at, 0.9, Color(0.5, 0.85, 1.0), 2, 2.5, 0.3, 0.25, 1.5)


## A caster's soul bolt: it lands on the target (and a little around it).
func _soul_bolt(from: Vector2, at: Vector2, dmg: float) -> void:
	Elements.hit_area(at, 0.7, dmg, Elements.NONE, _player.stats.crit_chance, _player.stats.crit_mult)
	var d := at - from
	for i in 5:
		Juice.burst(from + d * (i / 5.0), 1.0, Color(0.55, 0.85, 1.0), 1, 0.3, 0.22, 0.25, 0.0)
	Juice.burst(at, 0.8, Color(0.6, 0.9, 1.0), 4, 3.0, 0.3, 0.3, 1.5)


## A bulwark's (or tyrant's) slam: damage around it, and the horde hurled back.
func _ground_slam(at: Vector2, radius: float, dmg: float, big: bool) -> void:
	Elements.hit_area(at, radius, dmg, Elements.NONE, _player.stats.crit_chance, _player.stats.crit_mult)
	for swarm in _swarms:
		if not swarm.boss:
			swarm.knockback(at, radius, 5.0 if big else 3.5)
	Juice.ring(at, Color(0.5, 0.85, 1.0), 28 if big else 18, radius * 2.2, 0.45, 0.4)
	if big:
		Juice.shake(0.2)
	Sound.play("slam", 1.6 if not big else 1.1, -10.0 if not big else -5.0)


## Contact damage per second from enemies touching a minion (capped, like the
## hero's), at a third of full strength: the horde is after the hero, not them.
func _contact_damage(p: Vector2, r: float) -> float:
	var total := 0.0
	for swarm in _swarms:
		total += swarm.contact_load(p, r) * 0.35
	return total


## `refill`: let banked souls raise a replacement right away.
func _remove(k: int, died: bool, refill := true) -> void:
	var p := _pos[k]
	Juice.burst(p, 1.0, Color(0.5, 0.85, 1.0), 14, 4.0, 0.4, 0.6, 3.0)
	if died:
		Sound.play("minion_death")
		if _rank[k] > 0:
			veteran_fell.emit(_vname[k], _crypt[k])
	if _tag[k] != null:
		(_tag[k] as Node).queue_free()
		_tag[k] = null
	if died and Elements.has_power("lich_shroud"):
		# Soulfire: the fallen minion bursts, hurting everything around it.
		_queue_soulfire(p)
	var last := count - 1
	if k != last:
		_type[k] = _type[last]
		_pos[k] = _pos[last]
		_hp[k] = _hp[last]
		_max_hp[k] = _max_hp[last]
		_elite[k] = _elite[last]
		_attack[k] = _attack[last]
		_retarget[k] = _retarget[last]
		_hurt[k] = _hurt[last]
		_facing[k] = _facing[last]
		_phase[k] = _phase[last]
		_slam[k] = _slam[last]
		_target_swarm[k] = _target_swarm[last]
		_target_id[k] = _target_id[last]
		_target_index[k] = _target_index[last]
		_deeds[k] = _deeds[last]
		_rank[k] = _rank[last]
		_vname[k] = _vname[last]
		_crypt[k] = _crypt[last]
		_tag[k] = _tag[last]
		_tag[last] = null
	count = last
	if refill:
		_try_raise()


func _queue_soulfire(at: Vector2) -> void:
	_soulfire.append(at)


## Soulfire bursts run after all minions have stepped (they query the hash).
func flush() -> void:
	Elements.source = "Soul Army"
	for at in _soulfire:
		Elements.hit_area(at, 3.0, _player.stats.minion_damage * 4.0)
		Juice.ring(at, Color(0.45, 0.8, 1.0), 24, 8.0, 0.5, 0.4)
		Juice.flash(at, Color(0.45, 0.8, 1.0), 4.0, 8.0, 0.3)
	_soulfire.clear()


func _draw() -> void:
	var per_type := {}
	for k in count:
		var list: Array = per_type.get(_type[k], [])
		list.append(k)
		per_type[_type[k]] = list
	for t in _types.size():
		var mm: MultiMesh = _types[t]["mmi"].multimesh
		var list: Array = per_type.get(t, [])
		var n := mini(list.size(), mm.instance_count)
		mm.visible_instance_count = n
		for j in n:
			var k: int = list[j]
			var f := _facing[k]
			var sc := maxf(1.35 if _elite[k] == 1 else 1.0, 1.0 + 0.1 * _rank[k])
			var basis := Basis(Vector3.UP, atan2(-f.x, -f.y)).scaled(Vector3.ONE * sc)
			mm.set_instance_transform(j, Transform3D(basis, Vector3(_pos[k].x, 0.0, _pos[k].y)))
			mm.set_instance_custom_data(j, Color(0.0, _phase[k], _rank[k] / 3.0, 0.0))
			if _rank[k] > 0:
				var tag: Label3D = _tag[k]
				if tag:
					tag.position = Vector3(_pos[k].x, (_types[t]["swarm"] as EnemySwarm).body_height * sc + 0.7, _pos[k].y)
					var ring: Node3D = tag.get_child(0)
					ring.global_position = Vector3(_pos[k].x, 0.07, _pos[k].y)
			mm.set_instance_color(j, Color(1.2, 1.2, 1.2) if _elite[k] == 1 else Color.WHITE)
