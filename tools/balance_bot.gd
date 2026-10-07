extends SceneTree
## A bot that plays whole runs headless, for balancing. It kites away from
## crowds, picks up gems, takes upgrades by a build policy and manages gear.
## It's a consistent yardstick, not a stand-in for a human: use it to compare
## settings against each other, not to predict how long a person survives.
##
##   godot --headless --path . --fixed-fps 60 -s tools/balance_bot.gd -- <seed> <policy> <minutes> [overrides...]
##
##   policy     greedy | tank | random
##   overrides  realm=<id> plays that realm (see Realm.REALMS; default graveyard)
##              class=<id> plays that hero class (see HeroClass; default battlemage)
##              ascension=<n> plays at that Ascension (see RunModifiers)
##              node.property=value, applied after the scene loads, e.g.
##                director.rate_growth=0.1  Grunts.max_hp=12  Brutes.loot_chance=0.2
##              base.<stat>=value changes a starting stat (see PlayerStats.BASE),
##              e.g. base.bolt_count=2
##
## Prints a "T ..." timeline line every minute and a final "RESULT ..." line.
## tools/balance.sh runs many seeds in parallel and summarizes them.

## Upgrade priority per policy (first offered one in the list wins).
const PRIORITY := {
	"greedy": ["bolt_count", "bolt_damage", "bolt_rate", "aura", "bolt_pierce", "regen", "max_hp", "legion", "magnet", "move_speed"],
	"tank": ["max_hp", "regen", "move_speed", "bolt_damage", "bolt_rate", "aura", "bolt_count", "bolt_pierce", "magnet"],
}
## Skill tree order per policy: the first node in the list that can be bought
## is bought. (Nodes only become buyable once linked to something owned.)
const SKILL_PRIORITY := {
	"greedy": ["o1", "o2", "o3", "o4", "o7", "o6", "d1", "d2", "d4", "d3", "d7", "d6",
			"u1", "u2", "u3", "u4", "u6", "a1", "a2", "a4", "a3", "a5", "o5", "d5", "u5", "a6", "u7"],
	"tank": ["d1", "d2", "d3", "d4", "d6", "d7", "d5", "u1", "u2", "o1", "o2", "o4", "o3", "o7", "o6",
			"u3", "u4", "u5", "u6", "a1", "a2", "a4", "a3", "a5", "o5", "a6", "u7"],
}
const SENSE_RADIUS := 7.0
const KEEP_ITEMS := 10

var _seed := 1
var _policy := "greedy"
var _max_seconds := 20.0 * 60.0
var _overrides: Array[String] = []

var _main: Node
var _player: Player
var _hud: Hud
var _gems: GemSwarm
var _swarms: Array = []
var _frame := 0
var _orbit := 1.0
var _orbit_flip_at := 0.0
var _next_gear_check := 1.0
var _next_report := 60.0
var _peak_enemies := 0
var _items_found := 0
var _rarities := [0, 0, 0, 0]
var _done := false
var _actions := ["move_left", "move_right", "move_up", "move_down"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_seed = int(args[0])
	if args.size() > 1:
		_policy = args[1]
	if args.size() > 2:
		_max_seconds = float(args[2]) * 60.0
	for a in args.slice(3):
		_overrides.append(a)
	seed(_seed)
	# Starting stats have to change before the player is created.
	for o in _overrides:
		if o.begins_with("base."):
			_apply_base_override(o)
		elif o.begins_with("realm="):
			Realm.current = o.substr(6)
		elif o.begins_with("class="):
			MetaProgress.forced_class = o.substr(6)
		elif o.begins_with("omen="):
			RunModifiers.forced_omen = o.substr(5)
		elif o.begins_with("ascension="):
			RunModifiers.forced_ascension = int(o.substr(10))
	MetaProgress.disabled = true # saved upgrades mustn't change results
	Realm.in_title = false # straight into a run
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_setup()
		if _done:
			return true
	if _done:
		return true
	if _frame < 2:
		return false

	_steer()
	_pick_upgrade()
	# Timers use game time, so the bot behaves the same at any --fixed-fps.
	var now: float = _main.elapsed
	if now >= _next_gear_check:
		_next_gear_check = now + 1.0
		_manage_gear()
		_spend_skill_points()
		_peak_enemies = maxi(_peak_enemies, _main._enemy_count())
	if now >= _next_report:
		_next_report += 60.0
		_report("T")

	if _main._game_over or _main.won or now >= _max_seconds:
		_report("RESULT")
		_done = true
	return _done


func _setup() -> void:
	_player = _main.get_node("Player")
	_hud = _main.get_node("Hud")
	_gems = _main.get_node("Gems")
	_swarms = get_nodes_in_group(EnemySwarm.GROUP)
	_main.get_node("Loot").item_picked.connect(func(item: Item, _r: String) -> void:
		_items_found += 1
		_rarities[item.rarity] += 1)
	for o in _overrides:
		if not o.begins_with("base.") and not o.begins_with("realm=") and not o.begins_with("class=") \
				and not o.begins_with("omen=") and not o.begins_with("ascension="):
			_apply_override(o)


## "node.property=value": the node is matched by name (case-insensitive), and
## "director" is short for WaveDirector. A bad override aborts the run rather
## than quietly testing the wrong thing.
func _apply_override(text: String) -> void:
	var parts := text.split("=")
	var target := parts[0].split(".")
	if parts.size() != 2 or target.size() != 2:
		_fail("OVERRIDE FAILED  '%s' is not node.property=value" % text)
		return
	var wanted: String = "wavedirector" if target[0].to_lower() == "director" else target[0].to_lower()
	var node: Node = null
	for child in _main.get_children():
		if String(child.name).to_lower() == wanted:
			node = child
	if node == null:
		_fail("OVERRIDE FAILED  no node named '%s' in the scene" % target[0])
		return
	if not (target[1] in node):
		_fail("OVERRIDE FAILED  %s has no property '%s'" % [node.name, target[1]])
		return
	var before = node.get(target[1])
	node.set(target[1], float(parts[1]))
	print("OVERRIDE %s.%s  %s -> %s" % [node.name, target[1], before, node.get(target[1])])


func _apply_base_override(text: String) -> void:
	var parts := text.substr(5).split("=")
	if parts.size() != 2 or not PlayerStats.BASE.has(parts[0]):
		_fail("OVERRIDE FAILED  '%s' is not base.<stat>=value for a known stat" % text)
		return
	print("OVERRIDE base.%s  %s -> %s" % [parts[0], PlayerStats.BASE[parts[0]], parts[1]])
	PlayerStats.BASE[parts[0]] = float(parts[1])


func _fail(message: String) -> void:
	print(message)
	_done = true


# --- movement --------------------------------------------------------------------

func _steer() -> void:
	var here := _player.pos2
	var away := Vector2.ZERO
	var crowd := 0
	for swarm: EnemySwarm in _swarms:
		var n := swarm.grid.query(here, SENSE_RADIUS)
		var found := swarm.grid.results
		for k in n:
			var d := here - swarm.pos[found[k]]
			var dist := maxf(d.length(), 0.4)
			away += d / (dist * dist)
			crowd += 1

	var heading := Vector2.ZERO
	if crowd > 0:
		heading = away.normalized()
		# Orbit rather than run in a straight line, so the bot doesn't get
		# pushed ahead of the horde forever.
		if _main.elapsed >= _orbit_flip_at:
			_orbit = -_orbit
			_orbit_flip_at = _main.elapsed + randf_range(2.0, 6.0)
		heading = (heading + heading.rotated(PI * 0.5 * _orbit) * 0.7).normalized()
	else:
		heading = _toward_nearest_gem(here)
	# Step out of telegraphed hazards and boss slams, like a person would.
	var danger := _danger_escape(here)
	if danger != Vector2.ZERO:
		heading = danger
	_apply(heading)


## A direction out of any marked circle the bot is standing in (or ZERO).
func _danger_escape(here: Vector2) -> Vector2:
	var marks: Array = []
	for h: Dictionary in _main.get_node("Hazards")._pending:
		marks.append([h["at"], h["radius"]])
	var bosses: BossDirector = _main.get_node("BossDirector")
	for s: Dictionary in bosses._slams:
		marks.append([s["at"], bosses.slam_radius])
	var escape := Vector2.ZERO
	for m: Array in marks:
		var d: Vector2 = here - m[0]
		if d.length() < m[1] + 1.2:
			escape += d.normalized() if d.length() > 0.01 else Vector2.from_angle(randf() * TAU)
	return escape.normalized() if escape != Vector2.ZERO else Vector2.ZERO


func _toward_nearest_gem(here: Vector2) -> Vector2:
	var best := 14.0 * 14.0
	var target := Vector2.ZERO
	for i in _gems.count:
		var d2 := here.distance_squared_to(_gems._pos[i])
		if d2 < best:
			best = d2
			target = _gems._pos[i]
	if target == Vector2.ZERO:
		return Vector2.ZERO
	return (target - here).normalized()


func _apply(heading: Vector2) -> void:
	Input.action_press("move_left", maxf(-heading.x, 0.0))
	Input.action_press("move_right", maxf(heading.x, 0.0))
	Input.action_press("move_up", maxf(-heading.y, 0.0))
	Input.action_press("move_down", maxf(heading.y, 0.0))


# --- choices ---------------------------------------------------------------------

func _pick_upgrade() -> void:
	if not _hud._upgrade_root.visible:
		return
	var offered: Array[String] = _hud._upgrade_ids
	var choice := 0
	if _policy == "random":
		choice = randi() % offered.size()
	elif offered.any(func(id: String) -> bool: return id.begins_with(Evolutions.PREFIX)):
		# An evolution is always worth it.
		choice = offered.find(offered.filter(func(id: String) -> bool: return id.begins_with(Evolutions.PREFIX))[0])
	else:
		var best := 999
		for i in offered.size():
			var rank: int = PRIORITY[_policy].find(offered[i])
			if rank >= 0 and rank < best:
				best = rank
				choice = i
	_hud._choose(choice)


## Spends skill points by the policy's order (random picks any buyable node).
func _spend_skill_points() -> void:
	var tree: SkillTree = _player.skills
	while true:
		var choice := ""
		if _policy == "random":
			var options: Array[String] = []
			for id: String in SkillData.ids():
				if tree.can_allocate(id):
					options.append(id)
			if not options.is_empty():
				choice = options.pick_random()
		else:
			for id: String in SKILL_PRIORITY[_policy]:
				if tree.can_allocate(id):
					choice = id
					break
		if choice == "" or not tree.allocate(choice):
			return


func _manage_gear() -> void:
	var inv: Inventory = _player.inventory
	inv.equip_upgrades()
	while inv.backpack.size() > KEEP_ITEMS:
		var worst: Item = inv.backpack[0]
		for item in inv.backpack:
			if item.score() < worst.score():
				worst = item
		inv.discard(worst)


# --- output ----------------------------------------------------------------------

func _report(tag: String) -> void:
	var s := _player.stats
	var minutes: float = _main.elapsed / 60.0
	var worn := 0.0
	for slot in _player.inventory.equipped:
		worn += _player.inventory.equipped[slot].score()
	var fields := "seed=%d policy=%s t=%.1f enemies=%d peak=%d level=%d hp=%.0f/%.0f kills=%d items=%d (N%d M%d R%d L%d) gear_score=%.2f dmg=%.1f bolts=%d skills=%d army=%d won=%s died=%s" % [
			_seed, _policy, _main.elapsed, _main._enemy_count(), _peak_enemies, s.level, s.hp, s.max_hp,
			_main.kills, _items_found, _rarities[0], _rarities[1], _rarities[2], _rarities[3],
			worn, s.bolt_damage, s.bolt_count, _player.skills.allocated.size() - 1, _main.get_node("Army").count, str(_main.won), str(_main._game_over)]
	var army: Army = _main.get_node("Army")
	var best := 0
	for k in army.count:
		best = maxi(best, army._deeds[k])
	fields += " vets=%d best_minion_kills=%d" % [army.veterans().size(), best]
	var rival: RivalDirector = _main._rival
	fields += " pressure=%.2f" % (_main.get_node("WaveDirector") as WaveDirector).pressure
	fields += " rival=%s stolen=%d" % ["slain" if rival.defeated else ("here" if rival.active() else ("gone" if rival.arrived else "no")), rival.stolen]
	print("%s %s" % [tag, fields])
