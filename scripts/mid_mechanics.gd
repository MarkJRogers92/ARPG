class_name MidMechanics
extends Node3D
## Each realm's mid-boss has one move of its own, on top of the shared ground
## slam (BossDirector), so the three fights don't play the same:
##
##   Ogre Warlord     every 11 s he stamps and a shockwave rolls out from him.
##                    It hurts whoever it reaches; dash through it.
##   Troll Chieftain  every 18 s he grows a rime armor for 7 s (takes 65% less
##                    damage). Chill him (Frost Aura, Frostbite bolts...) to crack
##                    it; then he's brittle for a few seconds and takes more.
##   Magma Lord       leaves pools of lava where he walks (and, from the third
##                    one on, drops some near you). They burn you and the horde.
##
## Later bosses come harder: shorter gaps, more damage (`power()`).

const QUAKE_INTERVAL := 11.0
const QUAKE_WINDUP := 1.0
const QUAKE_SPEED := 7.5
const QUAKE_REACH := 17.0
const QUAKE_BAND := 1.1
const QUAKE_DAMAGE := 18.0

const RIME_INTERVAL := 18.0
const RIME_TIME := 7.0
## Chill is ignored for this long after the armor forms.
const RIME_GRACE := 1.2
const RIME_TAKEN := 0.35
const CRACK_TIME := 4.0
const CRACK_TAKEN := 1.5

const POOL_INTERVAL := 3.4
const POOL_WINDUP := 0.9
const POOL_LIFE := 9.0
const POOL_RADIUS := 2.0
const POOL_MAX := 12
const POOL_DPS := 8.0
const POOL_TICK := 0.5

## What the HUD shows under the boss bar ("" for nothing).
var hint := ""

var _swarm: EnemySwarm
var _player: Player
var _director: WaveDirector
var _bosses: BossDirector
var _kind := ""
## Boss id -> its own timers.
var _state := {}
## Shockwaves: {"at", "t", "r", "hit", "ring", "mark"}
var _waves: Array[Dictionary] = []
## Lava: {"at", "t", "tick", "ring", "fill"}
var _pools: Array[Dictionary] = []


func setup(swarm: EnemySwarm, player: Player, director: WaveDirector, bosses: BossDirector) -> void:
	_swarm = swarm
	_player = player
	_director = director
	_bosses = bosses
	_kind = {"graveyard": "warlord", "frozen": "chieftain", "ember": "magma"}.get(Realm.current, "warlord")


func kind() -> String:
	return _kind


## How hard the current boss hits: 1 for the first, +35% for each after.
func power() -> float:
	return 1.0 + 0.35 * maxf(_bosses.spawned - 1, 0)


## main.gd calls this every frame.
func tick(delta: float) -> void:
	if _swarm == null:
		return
	# One damage multiplier covers the whole swarm: armor on any boss wins over
	# brittleness on another.
	var armored := 1.0
	var brittle := 1.0
	var text := ""
	for i in _swarm.count:
		if _swarm.hp[i] <= 0.0:
			continue
		var id := _swarm.ids[i]
		if not _state.has(id):
			_state[id] = {"timer": 5.0, "armor": 0.0, "crack": 0.0}
		var s: Dictionary = _state[id]
		match _kind:
			"warlord":
				_warlord(i, s, delta)
			"chieftain":
				var r := _chieftain(i, s, delta)
				armored = minf(armored, r["taken"])
				brittle = maxf(brittle, r["taken"])
				if r["hint"] != "":
					text = r["hint"]
			"magma":
				_magma(i, s, delta)
	_swarm.damage_taken = armored if armored < 1.0 else brittle
	hint = text
	_update_waves(delta)
	_update_pools(delta)


# --- the Ogre Warlord: a shockwave ---------------------------------------------------------

func _warlord(i: int, s: Dictionary, delta: float) -> void:
	s["timer"] -= delta
	var at := _swarm.pos[i]
	if s["timer"] > 0.0 or _player.pos2.distance_to(at) > QUAKE_REACH + 4.0:
		return
	s["timer"] = maxf(QUAKE_INTERVAL - (_bosses.spawned - 1), 6.0)
	# The wind-up shows where the wave will reach and a bright mark at his feet.
	var ring := HazardDirector.make_decal(self, at, Color(1.0, 0.45, 0.2, 0.55), 1.0, QUAKE_REACH * 2.0 / 0.82)
	var mark := HazardDirector.make_decal(self, at, Color(1.0, 0.3, 0.15, 0.5), 0.0, 5.0)
	_waves.append({"at": at, "t": -QUAKE_WINDUP, "r": 0.0, "hit": false, "ring": ring, "mark": mark})
	Sound.play("telegraph", 0.8)
	Sound.play("boss_roar", 0.9, -4.0)


func _update_waves(delta: float) -> void:
	var k := _waves.size() - 1
	while k >= 0:
		var w := _waves[k]
		w["t"] += delta
		var ring: MeshInstance3D = w["ring"]
		var mark: MeshInstance3D = w["mark"]
		if w["t"] < 0.0:
			# Winding up: the mark swells, the outline waits at full reach.
			mark.scale = Vector3.ONE * clampf(1.0 + (w["t"] + QUAKE_WINDUP) / QUAKE_WINDUP, 0.2, 2.0)
			ring.scale = Vector3.ONE
		else:
			if w["r"] == 0.0:
				Sound.play("slam")
				Juice.shake(0.5)
				Juice.flash(w["at"], Color(1.0, 0.45, 0.2), 5.0, 9.0, 0.35)
				mark.queue_free()
				ring.queue_free()
				ring = HazardDirector.make_decal(self, w["at"], Color(1.0, 0.5, 0.2, 0.95), 1.0, 2.0)
				w["ring"] = ring
				w["mark"] = null
			w["r"] = QUAKE_SPEED * w["t"] + 0.5
			ring.scale = Vector3.ONE * (w["r"] / 0.82)
			var d: float = _player.pos2.distance_to(w["at"])
			if not w["hit"] and absf(d - w["r"]) <= QUAKE_BAND * 0.5 + Player.RADIUS:
				w["hit"] = true
				if not _player.is_dashing():
					_player.take_damage(QUAKE_DAMAGE * power() + 6.0 * _director.hp_scale)
					Sound.play("hurt")
					Juice.shake(0.3)
			if w["r"] >= QUAKE_REACH:
				ring.queue_free()
				_waves.remove_at(k)
		k -= 1


# --- the Troll Chieftain: rime armor -----------------------------------------------------------

## Returns {"taken": damage multiplier, "hint": text}.
func _chieftain(i: int, s: Dictionary, delta: float) -> Dictionary:
	var at := _swarm.pos[i]
	if s["crack"] > 0.0:
		s["crack"] -= delta
		if s["crack"] <= 0.0:
			s["timer"] = maxf(RIME_INTERVAL - 2.0 * (_bosses.spawned - 1), 9.0)
		return {"taken": CRACK_TAKEN, "hint": "ARMOR CRACKED!  Brittle: +50% damage"}
	if s["armor"] > 0.0:
		s["armor"] -= delta
		var age: float = RIME_TIME - s["armor"]
		if age > RIME_GRACE and _swarm.chill[i] > 0.0:
			s["armor"] = 0.0
			s["crack"] = CRACK_TIME
			Sound.play("shatter", 0.8)
			Juice.ring(at, Color(0.7, 0.92, 1.0), 40, 10.0, 0.6, 0.6)
			Juice.burst(at, 2.0, Color(0.8, 0.95, 1.0), 30, 6.0, 0.5, 0.6, 5.0)
			Juice.flash(at, Color(0.7, 0.92, 1.0), 5.0, 10.0, 0.4)
			return {"taken": CRACK_TAKEN, "hint": "ARMOR CRACKED!  Brittle: +50% damage"}
		if s["armor"] <= 0.0:
			s["timer"] = maxf(RIME_INTERVAL - 2.0 * (_bosses.spawned - 1), 9.0)
		elif Engine.get_process_frames() % 30 == 0:
			Juice.ring(at, Color(0.7, 0.92, 1.0, 0.5), 14, 3.0, 0.4, 0.4)
		return {"taken": RIME_TAKEN, "hint": "Rime armor!  Chill him to crack it"}
	s["timer"] -= delta
	if s["timer"] <= 0.0:
		s["armor"] = RIME_TIME
		Sound.play("ice_impact", 0.7)
		Juice.ring(at, Color(0.7, 0.92, 1.0), 36, 8.0, 0.6, 0.6)
		Juice.flash(at, Color(0.7, 0.92, 1.0), 4.0, 9.0, 0.4)
		return {"taken": RIME_TAKEN, "hint": "Rime armor!  Chill him to crack it"}
	return {"taken": 1.0, "hint": ""}


# --- the Magma Lord: lava ------------------------------------------------------------------

func _magma(i: int, s: Dictionary, delta: float) -> void:
	s["timer"] -= delta
	var at := _swarm.pos[i]
	if s["timer"] > 0.0 or _player.pos2.distance_to(at) > 28.0:
		return
	s["timer"] = maxf(POOL_INTERVAL - 0.25 * (_bosses.spawned - 1), 1.6)
	_add_pool(at)
	if _bosses.spawned >= 3:
		_add_pool(_player.pos2 + Vector2.from_angle(randf() * TAU) * randf_range(3.0, 5.0))


func _add_pool(at: Vector2) -> void:
	if _pools.size() >= POOL_MAX or Obstacles.blocked(at, 0.5):
		return
	var ring := HazardDirector.make_decal(self, at, Color(1.0, 0.35, 0.1, 0.8), 1.0, POOL_RADIUS * 2.0)
	var fill := HazardDirector.make_decal(self, at, Color(1.0, 0.4, 0.1, 0.3), 0.0, POOL_RADIUS * 2.0)
	fill.scale = Vector3.ONE * 0.05
	_pools.append({"at": at, "t": 0.0, "tick": 0.0, "ring": ring, "fill": fill})
	Sound.play("telegraph", 1.3, -6.0)


func _update_pools(delta: float) -> void:
	var k := _pools.size() - 1
	while k >= 0:
		var p := _pools[k]
		var before: float = p["t"]
		p["t"] += delta
		var fill: MeshInstance3D = p["fill"]
		if p["t"] < POOL_WINDUP:
			fill.scale = Vector3.ONE * clampf(p["t"] / POOL_WINDUP, 0.05, 1.0)
		else:
			if before < POOL_WINDUP:
				# It erupts: the disc turns bright and starts to burn.
				fill.scale = Vector3.ONE
				(fill.material_override as ShaderMaterial).set_shader_parameter("color", Color(1.0, 0.45, 0.1, 0.7))
				Sound.play("meteor", 1.4, -8.0)
				Juice.burst(p["at"], 0.3, Color(1.0, 0.5, 0.15), 12, 4.0, 0.4, 0.5, 4.0)
			p["tick"] += delta
			if p["tick"] >= POOL_TICK:
				p["tick"] -= POOL_TICK
				Elements.source = "Hazards"
				Elements.hit_area(p["at"], POOL_RADIUS, 4.0 * _director.hp_multiplier(), Elements.FIRE)
				if _player.pos2.distance_to(p["at"]) <= POOL_RADIUS + Player.RADIUS and not _player.is_dashing():
					_player.take_damage((POOL_DPS * power() + 3.0 * _director.hp_scale) * POOL_TICK)
					_player.afflict(Elements.FIRE)
		if p["t"] >= POOL_LIFE:
			(p["ring"] as MeshInstance3D).queue_free()
			fill.queue_free()
			_pools.remove_at(k)
		k -= 1


## Waves and pools in flight (for tests).
func waves() -> int:
	return _waves.size()


func pools() -> int:
	return _pools.size()
