class_name Landmarks
extends Node3D
## Set pieces you can use. WorldDecor places the scenery; this finds the
## usable pieces near the hero, rings them in gold, shows a prompt when the
## hero is close and does the thing when the interact key (E / gamepad B) is
## pressed. Each piece works once: its identity is its kind and position, so
## walking away and back (WorldDecor rebuilding the chunks) doesn't reset it.
##
##   Bell (gibbet, wind chime, gong)  ring it: champions rise around it; kill
##                                    them all for treasure and Soul Shards
##   Soul altar     sacrifice a minion: +12% damage for the rest of the night
##   Wishing well / frozen pond   toss in 5 shards for a random boon
##   Forge          8 shards: reforge your weapon, same rarity, better rolls
##   Cauldron       6 souls: brew a 45 s blessing
##   Fishing hut    rest: heal to full
##   Tome           read it: +1 skill point, -8% max HP for the night

signal announced(text: String, color: Color)

const USES := {
	"bell_gibbet": "bell", "wind_chime": "bell", "chained_gong": "bell",
	"soul_altar": "altar", "stone_well": "well", "frozen_pond": "well",
	"forge": "forge", "cauldron": "cauldron", "fishing_hut": "hut", "tome_pedestal": "tome",
	"ritual_door": "rift",
}
const INFO := {
	"bell": {"verb": "Ring the bell", "hint": "champions rise; slay them for treasure", "color": Color(1.0, 0.8, 0.35)},
	"altar": {"verb": "Sacrifice a minion", "hint": "+12% damage for the night", "color": Color(0.55, 0.85, 1.0)},
	"well": {"verb": "Toss in 5 Soul Shards", "hint": "the well grants... something", "color": Color(0.6, 0.9, 1.0)},
	"forge": {"verb": "Reforge your weapon (8 shards)", "hint": "same rarity, fresh and stronger rolls", "color": Color(1.0, 0.55, 0.2)},
	"cauldron": {"verb": "Brew from 6 souls", "hint": "a 45 s blessing", "color": Color(0.6, 1.0, 0.5)},
	"hut": {"verb": "Rest", "hint": "heal to full", "color": Color(0.8, 0.9, 1.0)},
	"tome": {"verb": "Read the forbidden tome", "hint": "+1 skill point, -8% max HP for the night", "color": Color(0.8, 0.5, 1.0)},
	"rift": {"verb": "Open the ritual door", "hint": "it leads to the Night Market", "color": Color(0.75, 0.55, 1.0)},
}
const ALTAR_SOURCE := "altar"
const TOME_SOURCE := "tome"
const RING_RANGE := 14.0

## The prompt for the piece in reach ("" for none), for the HUD.
var prompt := ""
var prompt_color := Color.WHITE
## Run shards earned here (main.gd collects them, like EventDirector's).
var shards := 0
## How many times each use was made this run.
var uses_made := {}

var _decor: WorldDecor
var _player: Player
var _director: WaveDirector
var _loot: LootManager
var _army: Army
var _events: EventDirector
var _swarms: Array[EnemySwarm] = []
## Callables from main: spend_shards(n) -> bool, run_shards() -> int.
var _spend: Callable
var _used := {}
var _near_key := ""
var _near_use := ""
var _near_at := Vector2.ZERO
var _scan := 0.0
## Rung bells: [{"at", "guards": [[swarm, id]], "key"}].
var _bells: Array[Dictionary] = []
var _rings: Array[MeshInstance3D] = []
var _altar_stacks := 0
## Set by main.gd: where the ritual door leads.
var rift: RiftDirector


func setup(decor: WorldDecor, player: Player, director: WaveDirector, loot: LootManager, army: Army,
		events: EventDirector, swarms: Array[EnemySwarm], spend: Callable) -> void:
	_decor = decor
	_player = player
	_director = director
	_loot = loot
	_army = army
	_events = events
	_swarms = swarms
	_spend = spend
	for k in 6:
		var ring := HazardDirector.make_decal(self, Vector2.ZERO, Color(1.0, 0.82, 0.4, 0.55), 0.85, 1.0)
		ring.visible = false
		_rings.append(ring)
	_ensure_input()


static func _ensure_input() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	InputMap.action_add_event("interact", key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_B
	InputMap.action_add_event("interact", pad)


static func key_of(kind: String, at: Vector2) -> String:
	return "%s|%d|%d" % [kind, roundi(at.x * 4.0), roundi(at.y * 4.0)]


func is_used(kind: String, at: Vector2) -> bool:
	return _used.has(key_of(kind, at))


## Usable pieces within `radius` of `at`: [[kind, position, footprint]].
func usable_near(at: Vector2, radius: float) -> Array:
	var out := []
	if _decor == null:
		return out
	for kind: String in USES:
		if not _decor.placed.has(kind):
			continue
		for xf: Transform3D in _decor.placed[kind]:
			var p := Vector2(xf.origin.x, xf.origin.z)
			if p.distance_squared_to(at) <= radius * radius and not _used.has(key_of(kind, p)):
				out.append([kind, p, AssetProps.data(kind)["footprint"] * xf.basis.get_scale().x])
	return out


func tick(delta: float) -> void:
	if _player == null:
		return
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.15
		_rescan()
	_update_bells()
	if _near_key != "" and Input.is_action_just_pressed("interact"):
		use_nearest()


func _rescan() -> void:
	var hero := _player.pos2
	var nearby := usable_near(hero, RING_RANGE)
	nearby.sort_custom(func(a: Array, b: Array) -> bool:
		return a[1].distance_squared_to(hero) < b[1].distance_squared_to(hero))
	for i in _rings.size():
		var ring := _rings[i]
		ring.visible = i < nearby.size()
		if ring.visible:
			var fp: float = nearby[i][2]
			ring.position = Vector3(nearby[i][1].x, 0.03, nearby[i][1].y)
			ring.scale = Vector3.ONE * (fp + 1.2) * 2.0 * (1.0 + 0.03 * sin(Time.get_ticks_msec() * 0.004))
	_near_key = ""
	prompt = ""
	if nearby.is_empty():
		return
	var kind: String = nearby[0][0]
	var at: Vector2 = nearby[0][1]
	if hero.distance_to(at) > nearby[0][2] + 1.8:
		return
	_near_key = key_of(kind, at)
	_near_use = USES[kind]
	_near_at = at
	var info: Dictionary = INFO[_near_use]
	var why := _unavailable(_near_use)
	prompt = "[E]  %s  ·  %s" % [info["verb"], why if why != "" else info["hint"]]
	prompt_color = info["color"] if why == "" else UiStyle.MUTED


## Why a use can't be made right now ("" if it can).
func _unavailable(use: String) -> String:
	match use:
		"altar":
			if _army.count == 0:
				return "you have no minion to give"
		"well":
			if _shards_available() < 5:
				return "you need 5 Soul Shards this run"
		"forge":
			if _shards_available() < 8:
				return "you need 8 Soul Shards this run"
			if _player.inventory.equipped.get("weapon") == null:
				return "you have no weapon to reforge"
		"cauldron":
			if _army.souls < 6:
				return "gather 6 souls first"
		"hut":
			if _player.stats.hp >= _player.stats.max_hp - 0.5:
				return "you're already rested"
		"rift":
			if rift == null or not rift.can_open():
				return "it won't open with a boss so near"
	return ""


func _shards_available() -> int:
	return _spend.call(0) if _spend.is_valid() else 0


## Uses the piece in reach. Returns true if something happened.
func use_nearest() -> bool:
	if _near_key == "" or _unavailable(_near_use) != "":
		Sound.play("ui_hover")
		return false
	var at := _near_at
	var use := _near_use
	var ok := false
	match use:
		"bell": ok = _ring_bell(at)
		"altar": ok = _sacrifice(at)
		"well": ok = _wish(at)
		"forge": ok = _reforge(at)
		"cauldron": ok = _brew(at)
		"hut": ok = _rest(at)
		"tome": ok = _read(at)
		"rift":
			rift.enter_market()
			ok = true
	if ok:
		_used[_near_key] = true
		uses_made[use] = uses_made.get(use, 0) + 1
		_near_key = ""
		prompt = ""
		_scan = 0.0
	return ok


# --- the uses ------------------------------------------------------------------------

func _ring_bell(at: Vector2) -> bool:
	var n := 4 + Realm.index(Realm.current)
	var types := _swarms.filter(func(s: EnemySwarm) -> bool: return not s.boss and not s.flee and s.spawn_share > 0.0)
	var guards := []
	for k in n:
		var swarm: EnemySwarm = types.pick_random()
		var p := at + Vector2.from_angle(TAU * k / n + 0.4) * 7.0
		if Obstacles.blocked(p, 1.0):
			p = at + Vector2.from_angle(TAU * k / n + 0.4) * 9.0
		if swarm.spawn(p, _director.hp_multiplier(), true):
			guards.append([swarm, swarm.ids[swarm.count - 1]])
	if guards.is_empty():
		announced.emit("The bell is silent... (the horde is too thick)", UiStyle.MUTED)
		return false
	_bells.append({"at": at, "guards": guards})
	Sound.play("boss_arrive", 1.3, -4.0)
	Sound.play("slam", 0.7)
	Juice.ring(at, Color(1.0, 0.8, 0.35), 48, 12.0, 0.7, 0.8)
	Juice.shake(0.35)
	announced.emit("The bell tolls! %d champions answer. Slay them all." % guards.size(), Color(1.0, 0.8, 0.35))
	return true


func _update_bells() -> void:
	var i := _bells.size() - 1
	while i >= 0:
		var b := _bells[i]
		var alive := false
		for g: Array in b["guards"]:
			var swarm: EnemySwarm = g[0]
			for k in swarm.count:
				if swarm.ids[k] == g[1] and swarm.hp[k] > 0.0:
					alive = true
					break
			if alive:
				break
		if not alive:
			var ilvl := ItemData.ilvl_for_player_level(_player.stats.level)
			for k in 2:
				_loot.drop(ItemGenerator.generate(ilvl, 2.0 + _player.stats.magic_find), b["at"] + Vector2(k * 1.2 - 0.6, 1.5))
			shards += 6
			Sound.play("chest")
			Juice.ring(b["at"], Color(1.0, 0.8, 0.35), 40, 8.0, 0.6, 0.6)
			announced.emit("The champions fall!  +6 Soul Shards", Color(1.0, 0.8, 0.35))
			_bells.remove_at(i)
		i -= 1


## Markers for the HUD's arrows while a bell's champions live.
func markers() -> Array:
	var out := []
	for b in _bells:
		out.append({"at": b["at"], "color": Color(1.0, 0.8, 0.35), "label": "CHAMPIONS"})
	return out


func _sacrifice(at: Vector2) -> bool:
	if not _army.sacrifice():
		return false
	_altar_stacks += 1
	var stats := _player.stats
	stats.remove_source(ALTAR_SOURCE)
	stats.add_mods(ALTAR_SOURCE, [{"stat": "damage", "op": PlayerStats.Op.INCREASED, "value": 0.12 * _altar_stacks}])
	stats.recalculate()
	Sound.play("shrine_done")
	Juice.burst(at, 1.2, Color(0.55, 0.85, 1.0), 30, 4.0, 0.5, 0.9, 6.0)
	announced.emit("The altar drinks the soul.  +12%% damage (now +%d%%)" % (12 * _altar_stacks), Color(0.55, 0.85, 1.0))
	return true


func _wish(at: Vector2) -> bool:
	if not _spend.call(5):
		return false
	Sound.play("gem", 0.7)
	var roll := randf()
	if roll < 0.3:
		var item := ItemGenerator.generate_with(ItemData.ilvl_for_player_level(_player.stats.level),
				ItemData.Rarity.RARE, ItemData.SLOTS.pick_random())
		_loot.drop(item, at + Vector2(0, 2.0))
		announced.emit("The well gives up a treasure!", Color(1.0, 0.85, 0.3))
	elif roll < 0.55:
		_player.heal(_player.stats.max_hp)
		Sound.play("heal")
		announced.emit("Cool water: fully healed.", Color(0.6, 0.9, 1.0))
	elif roll < 0.75:
		_events._bless(EventDirector.BLESSINGS.keys().pick_random())
	elif roll < 0.9:
		shards += 10
		announced.emit("The well overflows!  +10 Soul Shards", Color(0.78, 0.68, 1.0))
	else:
		announced.emit("The well keeps your shards. Something below laughs.", UiStyle.MUTED)
	Juice.burst(at, 0.6, Color(0.6, 0.9, 1.0), 20, 3.0, 0.4, 0.7, 4.0)
	return true


func _reforge(at: Vector2) -> bool:
	var old: Item = _player.inventory.equipped.get("weapon")
	if old == null or not _spend.call(8):
		return false
	var ilvl := ItemData.ilvl_for_player_level(_player.stats.level) + 3
	var item := ItemGenerator.generate_with(ilvl, old.rarity, "weapon")
	_player.inventory.replace_worn(item)
	Sound.play("slam", 1.4, -6.0)
	Sound.play("legendary" if item.rarity == ItemData.Rarity.LEGENDARY else "loot")
	Juice.burst(at, 1.2, Color(1.0, 0.55, 0.2), 40, 6.0, 0.5, 0.7, 5.0)
	announced.emit("Reforged: %s" % item.name, item.color())
	return true


func _brew(at: Vector2) -> bool:
	if _army.souls < 6:
		return false
	_army.souls -= 6
	_events.bless_for(EventDirector.BLESSINGS.keys().pick_random(), 45.0)
	Juice.burst(at, 1.5, Color(0.6, 1.0, 0.5), 30, 3.0, 0.5, 1.0, 5.0)
	return true


func _rest(at: Vector2) -> bool:
	_player.heal(_player.stats.max_hp)
	Sound.play("heal")
	Juice.burst(_player.pos2, 1.2, Color(1.0, 0.35, 0.4), 20, 3.0, 0.4, 0.6, 4.0)
	announced.emit("A moment's rest by the fire. Fully healed.", Color(0.8, 0.9, 1.0))
	return true


func _read(at: Vector2) -> bool:
	var stats := _player.stats
	var pages: int = uses_made.get("tome", 0) + 1
	stats.remove_source(TOME_SOURCE)
	stats.add_mods(TOME_SOURCE, [{"stat": "max_hp", "op": PlayerStats.Op.MORE, "value": pow(0.92, pages) - 1.0}])
	stats.recalculate()
	stats.hp = minf(stats.hp, stats.max_hp)
	_player.skills.add_points(1)
	Sound.play("levelup", 0.8)
	Juice.burst(at, 1.3, Color(0.8, 0.5, 1.0), 30, 3.0, 0.5, 0.9, 5.0)
	announced.emit("Forbidden knowledge: +1 skill point [K]. The tome takes its price.", Color(0.8, 0.5, 1.0))
	return true
