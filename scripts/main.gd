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
## Soul Shards found this run (elites and bosses); the run bonus comes on top.
var _run_shards := 0
var _rerolls := 0
var _mote_timer := 0.0

@onready var _player: Player = $Player
@onready var _projectiles: ProjectileSwarm = $Projectiles
@onready var _gems: GemSwarm = $Gems
@onready var _loot: LootManager = $Loot
@onready var _director: WaveDirector = $WaveDirector
@onready var _hud: Hud = $Hud
@onready var _inventory_screen: InventoryScreen = $InventoryScreen
@onready var _skill_screen: SkillTreeScreen = $SkillTreeScreen
@onready var _ground: Node3D = $Ground
@onready var _decor: WorldDecor = $Decor
@onready var _fx: FxSwarm = $Fx
@onready var _motes: FxSwarm = $Motes
@onready var _shots: EnemyShots = $EnemyShots
@onready var _bosses: BossDirector = $BossDirector
@onready var _atmosphere: Atmosphere = $Atmosphere
@onready var _souls: GemSwarm = $Souls
@onready var _army: Army = $Army


func _ready() -> void:
	# Every EnemySwarm node in the scene is an enemy type: no registration needed.
	Juice.fx = _fx
	Juice.numbers = $DamageNumbers
	Juice.flashes = $LightFlashes
	Juice.camera = $CameraRig
	MetaProgress.load_save()
	MetaProgress.apply(_player.stats)
	_rerolls = MetaProgress.rerolls()

	_swarms.assign(get_tree().get_nodes_in_group(EnemySwarm.GROUP))
	_player.setup(_swarms, _projectiles)
	_director.setup(_swarms)
	Elements.player = _player
	Elements.swarms = _swarms
	_army.setup(_player, _swarms)
	_army.raised.connect(func(kind: String) -> void:
		var who := _bosses.boss_name if kind == "Bosses" else kind.trim_suffix("s")
		_hud.toast("A spectral %s rises to serve you" % who, Color(0.55, 0.85, 1.0)))
	for swarm in _swarms:
		swarm.shots = _shots
		swarm.enemy_died.connect(_on_enemy_died.bind(swarm))
		swarm.elite_died.connect(_on_elite_died.bind(swarm))
		if swarm.boss:
			_bosses.setup(swarm, _director, _player)
	_bosses.boss_spawned.connect(func(boss_name: String) -> void:
		_hud.toast("%s approaches!" % boss_name, Color(1.0, 0.4, 0.3)))
	_projectiles.hit.connect(func(at: Vector2, crit: bool, damage: float) -> void:
		Juice.number(at, damage, crit)
		if crit:
			_fx.burst(at, 1.0, _projectiles.crit_color, 5, 5.0, 0.4, 0.3, 2.0)
		else:
			_fx.burst(at, 1.0, _projectiles.color, 2, 3.0, 0.3, 0.25, 1.5))
	_shots.hit_player.connect(func(at: Vector2) -> void:
		_fx.burst(at, 1.2, _shots.color, 8, 4.0, 0.4, 0.35, 2.0)
		Juice.shake(0.15))
	_player.dashed.connect(func() -> void:
		_fx.burst(_player.pos2, 0.6, Color(0.5, 0.8, 1.0), 12, 4.0, 0.45, 0.4, 1.0))
	_hud.reroll_requested.connect(_on_reroll)
	_player.leveled_up.connect(func() -> void:
		_fx.ring(_player.pos2, Color(1.0, 0.85, 0.4), 36, 9.0, 0.6, 0.7)
		_fx.burst(_player.pos2, 1.0, Color(1.0, 0.9, 0.6), 24, 3.0, 0.4, 1.0, 8.0))
	_loot.item_picked.connect(_on_item_picked)
	_loot.backpack_full.connect(func() -> void: _hud.toast("Backpack full", Color(1.0, 0.45, 0.4)))
	_player.leveled_up.connect(_try_level_up)
	_player.died.connect(_on_player_died)
	_hud.upgrade_chosen.connect(_on_upgrade_chosen)
	_inventory_screen.setup(_player)
	_inventory_screen.closed.connect(func() -> void: get_tree().paused = false)
	_skill_screen.setup(_player)
	_skill_screen.closed.connect(func() -> void: get_tree().paused = false)
	_player.skill_points_gained.connect(func(n: int) -> void:
		_hud.toast("+%d skill point%s  [K]" % [n, "" if n == 1 else "s"], Color(1.0, 0.85, 0.3)))
	_player.mouse_aim_toggled.connect(func(on: bool) -> void:
		_hud.toast("Aim: mouse" if on else "Aim: automatic (nearest enemy)", Color(1.0, 0.85, 0.5)))
	_hud.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())


func _exit_tree() -> void:
	Juice.reset()
	Elements.reset()


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
	_shots.step(delta, _player)
	_army.step(delta)
	Elements.flush()
	_army.flush()
	_bosses.tick(delta)

	var contact_dps := 0.0
	for swarm in _swarms:
		contact_dps += swarm.contact_load(origin, Player.RADIUS)
	if contact_dps > 0.0:
		_player.take_damage(contact_dps * delta)
	_hud.set_hurt(contact_dps > 0.0, delta)

	var xp := _gems.step(delta, origin, _player.stats.pickup_radius)
	if xp > 0:
		_player.add_xp(xp)

	_souls.step(delta, origin, _player.stats.pickup_radius)
	for value in _souls.collected:
		_army.collect_soul(value)
	_loot.step(delta, origin, _player.stats.pickup_radius, _player.inventory)

	_director.tick(delta, origin)
	_fx.step(delta)
	_spawn_motes(delta, origin)
	_motes.step(delta)
	_decor.follow(origin)
	_atmosphere.tick(delta, elapsed, _bosses.boss_alive())

	# The ground plane trails the player in whole grid cells; the grid itself
	# is drawn in world space, so it looks static.
	_ground.global_position = Vector3(
			snappedf(_player.global_position.x, GROUND_SNAP), 0.0,
			snappedf(_player.global_position.z, GROUND_SNAP))

	_hud.refresh(_player.stats, elapsed, kills, _enemy_count(), _player.skills.points)
	_hud.refresh_extras(_run_shards, _player.dash_cooldown_fraction(),
			_bosses.boss_name, _bosses.boss_health())
	_hud.refresh_army(_army.souls, _player.stats.soul_cost, _army.count, _player.stats.minion_max)


func _unhandled_input(event: InputEvent) -> void:
	# While a screen is open it handles its own close key (the tree is paused).
	if _choosing_upgrade or _game_over:
		return
	if event.is_action_pressed("inventory"):
		_open_screen(_inventory_screen)
	elif event.is_action_pressed("skill_tree"):
		_open_screen(_skill_screen)


func _open_screen(screen: Node) -> void:
	get_tree().paused = true
	screen.open()
	get_viewport().set_input_as_handled()


func _enemy_count() -> int:
	var total := 0
	for swarm in _swarms:
		total += swarm.alive_count()
	return total


## Embers drifting up around the hero, for atmosphere.
func _spawn_motes(delta: float, origin: Vector2) -> void:
	_mote_timer -= delta
	while _mote_timer <= 0.0:
		_mote_timer += 0.12
		var at := origin + Vector2.from_angle(randf() * TAU) * randf_range(2.0, 20.0)
		var color := Color(1.0, 0.55, 0.25) if randf() < 0.6 else Color(0.5, 0.8, 1.0)
		_motes.burst(at, randf_range(0.2, 2.5), color, 1, 0.5, 0.13, 4.5, 0.4)


func _on_elite_died(at: Vector2, swarm: EnemySwarm) -> void:
	_run_shards += 2
	_souls.drop(at + Vector2(0.6, 0.0), Army.soul_value(_army.type_index(swarm), true, false))
	_loot.drop(ItemGenerator.generate(ItemData.ilvl_for_player_level(_player.stats.level),
			1.0 + swarm.loot_quality + _player.stats.magic_find), at)
	_fx.burst(at, 1.0, Color(1.0, 0.8, 0.35), 20, 6.0, 0.55, 0.6, 5.0)
	Juice.flash(at, Color(1.0, 0.75, 0.35), 4.0, 8.0, 0.3)


func _on_enemy_died(at: Vector2, xp: int, swarm: EnemySwarm) -> void:
	kills += 1
	if swarm.boss:
		_on_boss_died(at, swarm)
		_souls.drop(at + Vector2(0.0, 1.0), Army.soul_value(_army.type_index(swarm), false, true))
	elif randf() < _player.stats.soul_chance:
		_souls.drop(at + Vector2(0.0, 0.4), Army.soul_value(_army.type_index(swarm), false, false))
	var big := swarm.body_height > 2.0
	_fx.burst(at, swarm.body_height * 0.5, swarm.color.lightened(0.25), 12 if big else 5,
			5.0 if big else 3.5, 0.55 if big else 0.4, 0.55, 3.0)
	var overflow := _gems.drop(at, xp)
	if overflow > 0:
		_player.add_xp(overflow)
	_loot.roll_kill_drop(at, swarm.loot_chance, swarm.loot_quality,
			ItemData.ilvl_for_player_level(_player.stats.level), _player.stats.magic_find)


func _on_boss_died(at: Vector2, swarm: EnemySwarm) -> void:
	var shards := 15 + 5 * (_bosses.spawned - 1)
	_run_shards += shards
	var ilvl := ItemData.ilvl_for_player_level(_player.stats.level)
	for k in 3:
		_loot.drop(ItemGenerator.generate(ilvl, 2.0 + _player.stats.magic_find), at)
	_fx.ring(at, Color(1.0, 0.6, 0.3), 60, 14.0, 0.8, 0.8)
	_fx.burst(at, 2.0, swarm.color.lightened(0.3), 60, 9.0, 0.7, 1.0, 8.0)
	Juice.flash(at, Color(1.0, 0.6, 0.3), 8.0, 16.0, 0.8)
	Juice.shake(0.8)
	_hud.toast("%s slain!  +%d Soul Shards" % [_bosses.boss_name, shards], Color(1.0, 0.75, 0.35))


func _on_item_picked(item: Item, result: String) -> void:
	_fx.burst(_player.pos2, 1.2, item.color(), 10 + 4 * item.rarity, 2.5, 0.4, 0.6, 5.0)
	var verb := "Equipped" if result == "equipped" else "Found"
	_hud.toast("%s: %s" % [verb, item.name], item.color())
	if item.power != "":
		_hud.toast("★ " + item.power_text(), item.color())
		Juice.flash(_player.pos2, item.color(), 5.0, 10.0, 0.5)
		_fx.ring(_player.pos2, item.color(), 40, 8.0, 0.6, 0.6)


func _try_level_up() -> void:
	if _choosing_upgrade or _game_over:
		return
	while _player.pending_levels > 0:
		_player.pending_levels -= 1
		var choices := Upgrades.roll(_player.stats)
		if Upgrades.is_exhausted(choices):
			# Everything is maxed: a menu with one useless card would just
			# interrupt the run, so the level-up quietly heals instead.
			Upgrades.apply("heal", _player.stats)
			continue
		_choosing_upgrade = true
		get_tree().paused = true
		_hud.show_upgrades(choices, _rerolls)
		return


func _on_reroll() -> void:
	if not _choosing_upgrade or _rerolls <= 0:
		return
	_rerolls -= 1
	_hud.show_upgrades(Upgrades.roll(_player.stats), _rerolls)


func _on_upgrade_chosen(id: String) -> void:
	Upgrades.apply(id, _player.stats)
	_choosing_upgrade = false
	get_tree().paused = false
	_try_level_up() # more than one level can be banked


func _on_player_died() -> void:
	_game_over = true
	var shards := _run_shards + MetaProgress.run_bonus(elapsed, kills)
	MetaProgress.add_shards(shards)
	_hud.show_game_over(elapsed, kills, _player.stats.level, shards)
