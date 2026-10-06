extends Node3D
## Game loop. Owns the update order for everything simulated as arrays:
##
##   player moves -> swarms step (flush dead, rebuild hash, move)
##   -> weapons fire / projectiles hit -> contact damage -> gems -> spawns
##
## Enemy deaths are only marked during the frame and removed at the start of
## the next swarm step, so hash indices stay valid for every query above.

const GROUND_SNAP := 4.0

var elapsed := 0.0
var kills := 0

var _swarms: Array[EnemySwarm] = []
var _choosing_upgrade := false
var _game_over := false

@onready var _player: Player = $Player
@onready var _projectiles: ProjectileSwarm = $Projectiles
@onready var _gems: GemSwarm = $Gems
@onready var _loot: LootManager = $Loot
@onready var _director: WaveDirector = $WaveDirector
@onready var _hud: Hud = $Hud
@onready var _inventory_screen: InventoryScreen = $InventoryScreen
@onready var _ground: Node3D = $Ground


func _ready() -> void:
	# Every EnemySwarm node in the scene is an enemy type: no registration needed.
	_swarms.assign(get_tree().get_nodes_in_group(EnemySwarm.GROUP))
	_player.setup(_swarms, _projectiles)
	_director.setup(_swarms)
	for swarm in _swarms:
		swarm.enemy_died.connect(_on_enemy_died.bind(swarm))
	_loot.item_picked.connect(_on_item_picked)
	_loot.backpack_full.connect(func() -> void: _hud.toast("Backpack full", Color(1.0, 0.45, 0.4)))
	_player.leveled_up.connect(_try_level_up)
	_player.died.connect(_on_player_died)
	_hud.upgrade_chosen.connect(_on_upgrade_chosen)
	_inventory_screen.setup(_player)
	_inventory_screen.closed.connect(func() -> void: get_tree().paused = false)
	_hud.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())


func _process(delta: float) -> void:
	if _game_over:
		return
	# A long hitch (window drag, breakpoint) shouldn't teleport the whole horde.
	delta = minf(delta, 0.05)
	elapsed += delta

	_player.tick(delta)
	var origin := _player.pos2
	for swarm in _swarms:
		swarm.step(delta, origin)

	_player.update_weapons(delta)
	_projectiles.step(delta, _swarms)

	var contact_dps := 0.0
	for swarm in _swarms:
		contact_dps += swarm.contact_load(origin, Player.RADIUS)
	if contact_dps > 0.0:
		_player.take_damage(contact_dps * delta)

	var xp := _gems.step(delta, origin, _player.stats.pickup_radius)
	if xp > 0:
		_player.add_xp(xp)

	_loot.step(delta, origin, _player.stats.pickup_radius, _player.inventory)

	_director.tick(delta, origin)

	# The ground plane trails the player in whole grid cells; the grid itself
	# is drawn in world space, so it looks static.
	_ground.global_position = Vector3(
			snappedf(_player.global_position.x, GROUND_SNAP), 0.0,
			snappedf(_player.global_position.z, GROUND_SNAP))

	_hud.refresh(_player.stats, elapsed, kills, _enemy_count())


func _unhandled_input(event: InputEvent) -> void:
	# While the screen is open it handles its own close key (the tree is paused).
	if event.is_action_pressed("inventory") and not _choosing_upgrade and not _game_over:
		get_tree().paused = true
		_inventory_screen.open()
		get_viewport().set_input_as_handled()


func _enemy_count() -> int:
	var total := 0
	for swarm in _swarms:
		total += swarm.alive_count()
	return total


func _on_enemy_died(at: Vector2, xp: int, swarm: EnemySwarm) -> void:
	kills += 1
	var overflow := _gems.drop(at, xp)
	if overflow > 0:
		_player.add_xp(overflow)
	_loot.roll_kill_drop(at, swarm.loot_chance, swarm.loot_quality,
			ItemData.ilvl_for_player_level(_player.stats.level), _player.stats.magic_find)


func _on_item_picked(item: Item, result: String) -> void:
	var verb := "Equipped" if result == "equipped" else "Found"
	_hud.toast("%s: %s" % [verb, item.name], item.color())


func _try_level_up() -> void:
	if _choosing_upgrade or _game_over or _player.pending_levels <= 0:
		return
	_choosing_upgrade = true
	_player.pending_levels -= 1
	get_tree().paused = true
	_hud.show_upgrades(Upgrades.roll(_player.stats))


func _on_upgrade_chosen(id: String) -> void:
	Upgrades.apply(id, _player.stats)
	_choosing_upgrade = false
	get_tree().paused = false
	_try_level_up() # more than one level can be banked


func _on_player_died() -> void:
	_game_over = true
	_hud.show_game_over(elapsed, kills, _player.stats.level)
