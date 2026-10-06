extends SceneTree
## A bot that plays whole runs headless, for balancing. It kites away from
## crowds, picks up gems, takes upgrades by a build policy and manages gear.
## It's a consistent yardstick, not a stand-in for a human: use it to compare
## settings against each other, not to predict how long a person survives.
##
##   godot --headless --path . --fixed-fps 60 -s tools/balance_bot.gd -- <seed> <policy> <minutes> [overrides...]
##
##   policy     greedy | tank | random
##   overrides  node.property=value, applied after the scene loads, e.g.
##                director.rate_growth=0.1  Grunts.max_hp=12  Brutes.loot_chance=0.2
##              base.<stat>=value changes a starting stat (see PlayerStats.BASE),
##              e.g. base.bolt_count=2
##
## Prints a "T ..." timeline line every minute and a final "RESULT ..." line.
## tools/balance.sh runs many seeds in parallel and summarizes them.

## Upgrade priority per policy (first offered one in the list wins).
const PRIORITY := {
	"greedy": ["bolt_count", "bolt_damage", "bolt_rate", "aura", "bolt_pierce", "regen", "max_hp", "magnet", "move_speed"],
	"tank": ["max_hp", "regen", "move_speed", "bolt_damage", "bolt_rate", "aura", "bolt_count", "bolt_pierce", "magnet"],
}
const SENSE_RADIUS := 7.0
const KEEP_ITEMS := 10

var _seed := 1
var _policy := "greedy"
var _max_frames := 20 * 60 * 60
var _overrides: Array[String] = []

var _main: Node
var _player: Player
var _hud: Hud
var _gems: GemSwarm
var _swarms: Array = []
var _frame := 0
var _orbit := 1.0
var _orbit_flip_at := 0
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
		_max_frames = int(float(args[2]) * 60.0 * 60.0)
	for a in args.slice(3):
		_overrides.append(a)
	seed(_seed)
	# Starting stats have to change before the player is created.
	for o in _overrides:
		if o.begins_with("base."):
			_apply_base_override(o)
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
	if _frame % 60 == 0:
		_manage_gear()
		_peak_enemies = maxi(_peak_enemies, _main._enemy_count())
	if _frame % (60 * 60) == 0:
		_report("T")

	if _main._game_over or _frame >= _max_frames:
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
		if not o.begins_with("base."):
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
		if _frame >= _orbit_flip_at:
			_orbit = -_orbit
			_orbit_flip_at = _frame + randi_range(120, 360)
		heading = (heading + heading.rotated(PI * 0.5 * _orbit) * 0.7).normalized()
	else:
		heading = _toward_nearest_gem(here)
	_apply(heading)


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
	else:
		var best := 999
		for i in offered.size():
			var rank: int = PRIORITY[_policy].find(offered[i])
			if rank >= 0 and rank < best:
				best = rank
				choice = i
	_hud._choose(choice)


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
	var fields := "seed=%d policy=%s t=%.1f enemies=%d peak=%d level=%d hp=%.0f/%.0f kills=%d items=%d (N%d M%d R%d L%d) gear_score=%.2f dmg=%.1f bolts=%d died=%s" % [
			_seed, _policy, _main.elapsed, _main._enemy_count(), _peak_enemies, s.level, s.hp, s.max_hp,
			_main.kills, _items_found, _rarities[0], _rarities[1], _rarities[2], _rarities[3],
			worn, s.bolt_damage, s.bolt_count, str(_main._game_over)]
	print("%s %s" % [tag, fields])
