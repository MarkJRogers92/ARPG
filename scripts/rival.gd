class_name RivalDirector
extends Node3D
## A rival necromancer, once a night (from 9:00 on the night's clock): another binder of the dead
## who has come for the hero's souls.
##
##   - keeps its distance (EnemySwarm hold_range) and casts soul bolts
##   - blinks away when the hero closes in
##   - steals souls: the ones lying near it, and some of the hero's own banked
##     souls when it's close enough; every few stolen souls (and every few
##     seconds anyway) it raises a red thrall
##   - leaves after LINGER seconds, with what it stole
##
## Kill it in time and its army is yours: up to CLAIM of its thralls (and its
## own shade, as a champion) join the Soul Army, past the army's usual size,
## plus a Legendary and run shards.
##
## A nemesis: a rival that escapes, or is still about when the hero falls,
## comes back next night under the same name, a rank stronger (up to 5):
## tougher, more thralls, quicker blinks, greedier drains, and it remembers.
## Putting a nemesis down pays a Legendary and the shards again per rank.

signal announced(text: String, color: Color)

const ARRIVE_AT := 540.0
const LINGER := 100.0
const BLINK_RANGE := 4.5
const BLINK_COOLDOWN := 4.0
const STEAL_RADIUS := 9.0
const DRAIN_RANGE := 14.0
const DRAIN_INTERVAL := 7.0
const DRAIN_AMOUNT := 3
const RAISE_EVERY := 4 # stolen souls per thrall
const RAISE_INTERVAL := 5.0
const MAX_THRALLS := 24
const CLAIM := 6
const SHARDS := 15
const COLOR := Color(1.0, 0.35, 0.42)
const TAUNTS := [
	"%s returns. \"Your %d souls served me well. I've come for the rest.\"",
	"%s is back. \"You let me go %d times... no, I let YOU live.\"",
	"%s rises again. \"Every soul you lose makes me stronger.\"",
]
const NAMES := ["Vael the Usurper", "Morgana Ashveil", "Calder the Hollow", "Isra of the Black Choir", "Thessaly Graverend", "Oren the Unquiet"]

## What the HUD shows under the timer while the rival is about ("" otherwise).
var hint := ""
var rival_name := ""
## How many souls it has taken this night.
var stolen := 0
var arrived := false
var defeated := false
## The nemesis rank this rival came back at (0: a new rival).
var rank := 0

var _main: Node
var _rival: EnemySwarm
var _thralls: EnemySwarm
var _player: Player
var _army: Army
var _souls: GemSwarm
var _loot: LootManager
var _director: WaveDirector
var _bosses: BossDirector
var _left := 0.0
var _blink := 0.0
var _drain := DRAIN_INTERVAL
var _raise := RAISE_INTERVAL
var _toward_thrall := 0
var _beams: Array[Dictionary] = []
## A red ring on the ground under the rival, so it stands out in the crowd.
var _ring: MeshInstance3D


func setup(main: Node, rival: EnemySwarm, thralls: EnemySwarm, player: Player, army: Army, souls: GemSwarm,
		loot: LootManager, director: WaveDirector, bosses: BossDirector) -> void:
	_main = main
	_rival = rival
	_thralls = thralls
	_player = player
	_army = army
	_souls = souls
	_loot = loot
	_director = director
	_bosses = bosses
	_rival.enemy_died.connect(_on_rival_died)


func active() -> bool:
	return arrived and not defeated and _left > 0.0


func tick(delta: float) -> void:
	if not arrived:
		if _director.elapsed >= ARRIVE_AT and not _bosses.boss_alive() and not _bosses.final_alive() and _bosses.time_to_final() > LINGER + 20.0:
			arrive()
		return
	if not active():
		return
	var i := _index()
	if i < 0:
		return
	_left -= delta
	var blink_cooldown := BLINK_COOLDOWN * maxf(1.0 - 0.12 * rank, 0.4)
	var at := _rival.pos[i]
	if _ring:
		_ring.position = Vector3(at.x, 0.07, at.y)
	# Blink away from the hero.
	_blink -= delta
	if _blink <= 0.0 and at.distance_to(_player.pos2) < BLINK_RANGE:
		_blink = blink_cooldown
		var to := at
		for attempt in 12:
			var p := _player.pos2 + Vector2.from_angle(randf() * TAU) * randf_range(10.0, 13.0)
			if not Obstacles.blocked(p, 1.0):
				to = p
				break
		Juice.burst(at, 1.0, COLOR, 24, 4.0, 0.45, 0.6, 4.0)
		_rival.pos[i] = to
		Juice.burst(to, 1.0, COLOR, 24, 4.0, 0.45, 0.6, 4.0)
		Juice.flash(to, COLOR, 3.0, 6.0, 0.3)
		Sound.play("dash", 0.7)
		at = to
	# Souls on the ground near it are its now.
	var took := _souls.take_near(at, STEAL_RADIUS)
	if took > 0:
		_steal(took, at)
	# And it drains the hero's own, when close.
	_drain -= delta
	if _drain <= 0.0:
		_drain = DRAIN_INTERVAL
		if at.distance_to(_player.pos2) < DRAIN_RANGE and _army.souls > 0:
			var n := mini(DRAIN_AMOUNT + rank, _army.souls)
			_army.souls -= n
			_beam(_player.pos2, at)
			_steal(n, at)
			announced.emit("%s drains %d of your souls!" % [rival_name, n], COLOR)
	_raise -= delta
	if _raise <= 0.0:
		_raise = RAISE_INTERVAL
		_raise_thrall(at)
	_update_beams(delta)
	hint = "%s  ·  %d souls stolen  ·  flees in %d s" % [rival_name.to_upper(), stolen, ceili(_left)]
	if _left <= 0.0:
		_escape(i)


## The rival appears (also used by tests and screenshots).
func arrive() -> void:
	arrived = true
	var nem := MetaProgress.nemesis
	rank = int(nem.get("rank", 0))
	rival_name = nem.get("name", NAMES.pick_random())
	_rival.display_name = rival_name
	var at := EnemySwarm.random_ring_point(_player.pos2, 14.0, 16.0)
	if not _rival.spawn(at, _director.hp_multiplier() * (1.0 + 0.4 * rank)):
		return
	_left = LINGER + 10.0 * rank
	_blink = 1.5
	_ring = HazardDirector.make_decal(self, at, Color(COLOR, 0.7), 1.0, 3.2)
	for k in 3 + rank:
		_raise_thrall(at)
	Juice.ring(at, COLOR, 40, 10.0, 0.6, 0.7)
	Juice.flash(at, COLOR, 6.0, 12.0, 0.6)
	Sound.play("boss_title", 0.9, -3.0)
	var hud := _main.get_node_or_null("Hud") as Hud
	if rank > 0:
		announced.emit(_taunt(nem), COLOR)
		if hud:
			hud.title_card(rival_name, "YOUR NEMESIS RETURNS  ·  RANK %d" % rank, COLOR)
	else:
		announced.emit("%s, a rival necromancer, has come for your souls! Kill them before they escape." % rival_name, COLOR)
		if hud:
			hud.title_card(rival_name, "A RIVAL NECROMANCER", COLOR)


func _taunt(nem: Dictionary) -> String:
	match rank % TAUNTS.size():
		0: return TAUNTS[0] % [rival_name, int(nem.get("stolen", 0))]
		1: return TAUNTS[1] % [rival_name, int(nem.get("escapes", 1))]
		_: return TAUNTS[2] % rival_name


func _index() -> int:
	for i in _rival.count:
		if _rival.hp[i] > 0.0:
			return i
	return -1


func _steal(n: int, at: Vector2) -> void:
	stolen += n
	Juice.burst(at + Vector2(0, -0.5), 0.6, COLOR, 4 * n, 2.0, 0.3, 0.6, 2.0)
	_toward_thrall += n
	while _toward_thrall >= RAISE_EVERY:
		_toward_thrall -= RAISE_EVERY
		_raise_thrall(at)


func _raise_thrall(at: Vector2) -> void:
	if _thralls.alive_count() >= MAX_THRALLS + 4 * rank:
		return
	var p := at + Vector2.from_angle(randf() * TAU) * randf_range(1.5, 3.0)
	if Obstacles.blocked(p, 0.5):
		p = at
	if _thralls.spawn(p, _director.hp_multiplier()):
		Juice.burst(p, 0.3, COLOR, 12, 1.5, 0.4, 0.8, 5.0)
		Juice.ring(p, COLOR, 16, 3.0, 0.3, 0.4)


## A red stream from where souls were taken to the rival, for a moment.
func _beam(from: Vector2, to: Vector2) -> void:
	_beams.append({"from": from, "to": to, "t": 0.6})


func _update_beams(delta: float) -> void:
	var k := _beams.size() - 1
	while k >= 0:
		var b := _beams[k]
		b["t"] -= delta
		var d: Vector2 = b["to"] - b["from"]
		for s in 3:
			Juice.burst(b["from"] + d * randf(), 1.0, COLOR, 1, 0.5, 0.25, 0.3, 0.0)
		if b["t"] <= 0.0:
			_beams.remove_at(k)
		k -= 1


func _escape(i: int) -> void:
	var at := _rival.pos[i]
	Juice.burst(at, 1.0, COLOR, 40, 6.0, 0.5, 0.8, 6.0)
	Juice.ring(at, COLOR, 30, 8.0, 0.5, 0.5)
	_rival.despawn_all()
	_fade_thralls()
	_drop_ring()
	hint = ""
	MetaProgress.nemesis_escaped(rival_name, stolen)
	announced.emit("%s escapes into the night with %d stolen souls. They will return, stronger." % [rival_name, stolen], Color(0.8, 0.7, 0.75))


## The hero fell while the rival was about: it will remember that.
func hero_fell() -> void:
	if active():
		MetaProgress.nemesis_escaped(rival_name, stolen)


func _fade_thralls() -> void:
	for t in _thralls.count:
		if _thralls.hp[t] > 0.0:
			Juice.burst(_thralls.pos[t], 0.8, COLOR, 6, 2.0, 0.3, 0.4, 2.0)
	_thralls.despawn_all()


func _on_rival_died(at: Vector2, _xp: int) -> void:
	if defeated:
		return
	defeated = true
	hint = ""
	_drop_ring()
	# Its army is yours: the nearest thralls turn, and its own shade.
	var alive := []
	for t in _thralls.count:
		if _thralls.hp[t] > 0.0:
			alive.append(t)
	alive.sort_custom(func(a: int, b: int) -> bool: return _thralls.pos[a].distance_squared_to(at) < _thralls.pos[b].distance_squared_to(at))
	var turned := 0
	for t: int in alive.slice(0, CLAIM):
		Juice.burst(_thralls.pos[t], 0.6, Color(0.5, 0.85, 1.0), 10, 2.0, 0.35, 0.6, 3.0)
		turned += 1
	_fade_thralls()
	var claimed := _army.claim(_thralls, maxi(turned, 2))
	var shade := _army.claim(_rival, 1, true)
	for k in 1 + rank:
		_loot.drop(ItemGenerator.generate_with(ItemData.ilvl_for_player_level(_player.stats.level), ItemData.Rarity.LEGENDARY,
				ItemData.SLOTS.pick_random()), at + Vector2.from_angle(TAU * k / (1.0 + rank)) * 1.5)
	var shards := SHARDS * (1 + rank)
	_main.set("_run_shards", int(_main.get("_run_shards")) + shards)
	if rank > 0:
		MetaProgress.nemesis_slain()
	Juice.ring(at, Color(0.5, 0.85, 1.0), 48, 12.0, 0.7, 0.8)
	Juice.flash(at, Color(0.5, 0.85, 1.0), 6.0, 12.0, 0.6)
	Sound.play("shrine_done")
	announced.emit("%s%s is destroyed%s! %d thralls%s join your army. +%d Soul Shards" % [
			"Your nemesis " if rank > 0 else "", rival_name, " for good" if rank > 0 else "", claimed,
			" and their shade" if shade > 0 else "", shards], UiStyle.GOLD)


func _drop_ring() -> void:
	if _ring:
		_ring.queue_free()
		_ring = null


## Edge-arrow markers for the HUD.
func markers() -> Array:
	var out := []
	if active():
		var i := _index()
		if i >= 0:
			out.append({"at": _rival.pos[i], "color": COLOR, "label": rival_name.to_upper()})
	return out
