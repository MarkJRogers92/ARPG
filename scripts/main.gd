extends Node3D
## Game loop. Owns the update order for everything simulated as arrays:
##
##   player moves -> swarms step (flush dead, rebuild hash, move)
##   -> weapons fire / projectiles hit -> contact damage -> gems -> spawns
##
## Enemy deaths are only marked during the frame and removed at the start of
## the next swarm step, so hash indices stay valid for every query above.
##
## A run is one night in a realm (see Realm): survive until dawn, then kill
## the realm's final boss to win. The scene opens on the title screen.

const GROUND_SNAP := 4.0

var elapsed := 0.0
var kills := 0

var _swarms: Array[EnemySwarm] = []
var _choosing_upgrade := false
var _game_over := false
## Soul Shards found this run (elites and bosses); the run bonus comes on top.
var _run_shards := 0
## Shards for winning the night: banked in full (in-night shards only in part).
var _win_shards := 0
var _rerolls := 0
var _mote_timer := 0.0
var _mote_style := "embers"
## The night is won (the final boss is dead).
var won := false
var _endless := false
var _endless_start := 0.0
## Seconds left of the dawn sweep that turns the horde to ash after a win.
var _dawn_sweep := 0.0
## Where the sunrise front starts (the final boss's last stand) and its ring.
var _dawn_at := Vector2.ZERO
var _dawn_front: MeshInstance3D
var _dawn_glow: DawnGlow
var _wisps: Wisps
## The hero's death plays out for this long (real seconds) before the end screen.
const DEATH_TIME := 2.6
var _dying := 0.0
var _death_shards := 0
var _first_light_told := false
## This Daily Night is already in the history (won, then went on past dawn).
var _daily_logged := false
## First Light: the last stretch of the night, when the sun starts to rise.
const FIRST_LIGHT := 150.0
const DAWN_SWEEP := 4.0
const DAWN_REACH := 55.0
var _in_title := false

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
@onready var _hazards: HazardDirector = $Hazards
@onready var _final: EnemySwarm = $FinalBoss
@onready var _title: TitleScreen = $TitleScreen
@onready var _sound: Sound = $Sound
@onready var _events: EventDirector = $Events
@onready var _goblins: EnemySwarm = $Goblins
@onready var _grunts: EnemySwarm = $Grunts
var _warned := {}
var _pause: PauseMenu
var _landmarks: Landmarks
var _spec_chosen := false
var _final_mech: FinalMechanics
var _mid_mech: MidMechanics
var _specialists: Specialists
## Health and pressure through the night, for the end screen (DeathRecap).
var _timeline: Array[Vector3] = []
var _sample_in := 0.0
var _rift: RiftDirector
## Frenzy: kills pile it up, it drains away; each tier speeds you up.
## This night's Pacts and Omen (see RunModifiers), and kills by enemy name.
var pacts: Array = []
var omen := ""
var ascension := 0
var _kills_by := {}
var frenzy := 0.0
var frenzy_tier := 0
const FRENZY_TIERS := [20.0, 45.0, 80.0]
var _ferryman: Ferryman
var _rival: RivalDirector
var _wager_panel: WagerPanel
## XP gems picked up in quick succession chime higher and higher.
var _gem_streak := 0
var _gem_streak_time := 0.0
var _hurt_sound := 0.0


func _enter_tree() -> void:
	# Before the swarms' _ready(), so they build the realm's models.
	Realm.apply_gameplay(self)
	# And so they draw their warnings the way the settings say.
	MetaProgress.load_save()
	Juice.calm = MetaProgress.setting("calm")
	Juice.bold_telegraphs = MetaProgress.setting("bold_telegraphs")


func _ready() -> void:
	# Every EnemySwarm node in the scene is an enemy type: no registration needed.
	Juice.fx = _fx
	Juice.numbers = $DamageNumbers
	Juice.flashes = $LightFlashes
	Juice.camera = $CameraRig
	apply_settings()
	Juice.time_effects = true
	MetaProgress.load_save()
	MetaProgress.apply(_player.stats)
	HeroClass.apply(_player, MetaProgress.current_class())
	Relics.apply(_player, MetaProgress.current_relic(), MetaProgress.current_start_weapon())
	_rerolls = MetaProgress.rerolls() + Relics.extra_rerolls(MetaProgress.current_relic())
	var realm := Realm.data()
	if realm["soul_bonus"] > 0.0:
		_player.stats.add_mod("realm", "soul_chance", PlayerStats.Op.INCREASED, realm["soul_bonus"])
		_player.stats.recalculate()
	Realm.apply_look(self)
	_mote_style = realm["motes"]

	_swarms.assign(get_tree().get_nodes_in_group(EnemySwarm.GROUP))
	_player.setup(_swarms, _projectiles)
	_director.setup(_swarms)
	Elements.player = _player
	Elements.swarms = _swarms
	_army.setup(_player, _swarms)
	_army.stance_changed.connect(func(stance: String) -> void:
		var st: Dictionary = Army.STANCES[stance]
		_hud.toast("%s: %s" % [st["label"], st["desc"]], st["color"]))
	_army.promoted.connect(func(text: String) -> void: _hud.toast(text, Army.VETERAN_COLOR))
	_army.veteran_fell.connect(func(vet_name: String, crypt: int) -> void:
		if won and not _endless:
			return
		_hud.toast("%s has fallen%s." % [vet_name, ", gone from the Crypt forever" if crypt >= 0 else ""], Color(0.75, 0.75, 0.85))
		if crypt >= 0:
			MetaProgress.crypt_fell(crypt))
	_army.raised.connect(func(kind: String) -> void:
		_hud.toast("A spectral %s rises to serve you" % kind, Color(0.55, 0.85, 1.0)))
	for swarm in _swarms:
		swarm.shots = _shots
		swarm.enemy_died.connect(_on_enemy_died.bind(swarm))
		swarm.elite_died.connect(_on_elite_died.bind(swarm))
		if swarm.boss and swarm != _final:
			_bosses.setup(swarm, _director, _player)
	_bosses.setup_final(_final, _shots, $Grunts)
	_hazards.setup(_director, _player, $Grunts)
	_events.setup(_director, _player, _loot, _gems, _goblins, _swarms)
	_events.announced.connect(func(text: String, color: Color) -> void: _hud.toast(text, color))
	for swarm in _swarms:
		if swarm.charger:
			swarm.charged_hero.connect(_on_charged.bind(swarm))
		if swarm.raise_interval > 0.0:
			swarm.raise_called.connect(_on_raise_called.bind(swarm))
	_landmarks = Landmarks.new()
	add_child(_landmarks)
	_landmarks.setup(_decor, _player, _director, _loot, _army, _events, _swarms, _spend_shards)
	_landmarks.announced.connect(func(text: String, color: Color) -> void: _hud.toast(text, color))
	_wager_panel = WagerPanel.new()
	add_child(_wager_panel)
	_dawn_glow = DawnGlow.new()
	add_child(_dawn_glow)
	_wisps = Wisps.new()
	add_child(_wisps)
	_ferryman = Ferryman.new()
	add_child(_ferryman)
	var collectors := get_node_or_null("Collectors") as EnemySwarm
	_ferryman.setup(_player, _army, _loot, _director, collectors, _wager_panel)
	_ferryman.announced.connect(func(text: String, color: Color) -> void: _hud.toast(text, color))
	if collectors:
		collectors.seized_hero.connect(_ferryman.seize)
	_bosses.boss_spawned.connect(func(boss_name: String) -> void: _ferryman.start_bet(boss_name))
	_rival = RivalDirector.new()
	add_child(_rival)
	_rival.setup(self, $Rival, $Thralls, _player, _army, _souls, _loot, _director, _bosses)
	_rival.announced.connect(func(text: String, color: Color) -> void: _hud.toast(text, color))
	_rift = RiftDirector.new()
	add_child(_rift)
	_rift.setup(self, _player, _loot, _army, _events, _decor, ($WorldEnvironment as WorldEnvironment).environment, _swarms,
			_spend_shards, func(n: int) -> void: _rerolls += n)
	_rift.announced.connect(func(text: String, color: Color) -> void: _hud.toast(text, color))
	_landmarks.rift = _rift
	_final_mech = FinalMechanics.new()
	add_child(_final_mech)
	_final_mech.setup(_final, get_node("Phylacteries") as EnemySwarm, _player, _director)
	_mid_mech = MidMechanics.new()
	add_child(_mid_mech)
	_mid_mech.setup($Bosses, _player, _director, _bosses)
	_specialists = Specialists.new()
	add_child(_specialists)
	_specialists.setup(_swarms, _player, _director)
	_specialists.announced.connect(func(text: String, color: Color) -> void: _hud.toast(text, color))
	_bosses.final_spawned.connect(func(boss_name: String) -> void:
		_hud.title_card(boss_name, "Dawn is near. The master of this realm rises.", Color(1.0, 0.35, 0.3))
		Sound.play("boss_title")
		_hud.toast("Dawn is near... %s rises!" % boss_name, Color(1.0, 0.35, 0.3)))
	_bosses.boss_spawned.connect(func(boss_name: String) -> void:
		_hud.title_card(boss_name, "A champion of the night approaches", Color(1.0, 0.55, 0.35))
		Sound.play("boss_title", 1.1, -3.0)
		_hud.toast("%s approaches!" % boss_name, Color(1.0, 0.4, 0.3)))
	_projectiles.hit.connect(func(at: Vector2, crit: bool, damage: float) -> void:
		Sound.play("bolt_hit")
		if crit:
			_fx.burst(at, 1.0, _projectiles.crit_color, 5, 5.0, 0.4, 0.3, 2.0)
		else:
			_fx.burst(at, 1.0, _projectiles.color, 2, 3.0, 0.3, 0.25, 1.5))
	_shots.hit_player.connect(func(at: Vector2) -> void:
		Sound.play("hurt")
		_fx.burst(at, 1.2, _shots.color, 8, 4.0, 0.4, 0.35, 2.0)
		Juice.shake(0.15))
	_player.dashed.connect(func() -> void:
		_fx.burst(_player.pos2, 0.6, Color(0.5, 0.8, 1.0), 12, 4.0, 0.45, 0.4, 1.0))
	_hud.reroll_requested.connect(_on_reroll)
	_player.leveled_up.connect(func() -> void:
		Sound.play("levelup")
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
		_hud.toast("+%d skill point%s  %s" % [n, "" if n == 1 else "s", Controls.tag("skill_tree")], Color(1.0, 0.85, 0.3)))
	_player.mouse_aim_toggled.connect(func(on: bool) -> void:
		_hud.toast("Aim: mouse" if on else "Aim: automatic (nearest enemy)", Color(1.0, 0.85, 0.5)))
	_hud.restart_pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	_hud.realms_pressed.connect(func() -> void:
		Realm.in_title = true
		get_tree().paused = false
		get_tree().reload_current_scene())
	_hud.endless_pressed.connect(_start_endless)
	_pause = PauseMenu.new()
	add_child(_pause)
	_pause.resumed.connect(func() -> void: get_tree().paused = false)
	_pause.settings_changed.connect(apply_settings)
	_pause.quit_to_title.connect(func() -> void:
		Realm.in_title = true
		get_tree().paused = false
		get_tree().reload_current_scene())
	_title.previewed.connect(func(id: String) -> void:
		_sound.play_realm(id)
		Realm.apply_look(self, id)
		_mote_style = Realm.data(id)["motes"])
	_title.chosen.connect(func(id: String) -> void:
		Realm.current = id
		Realm.in_title = false
		get_tree().reload_current_scene())
	_sound.play_realm(Realm.current)
	_in_title = Realm.in_title
	if not _in_title:
		_begin_night()
	if _in_title:
		_hud.hide()
		_title.open()
	else:
		_title.close()


## Screen shake and damage numbers on or off, and the volumes (see PauseMenu).
func apply_settings() -> void:
	($CameraRig as CameraRig).shake_enabled = MetaProgress.setting("shake")
	Juice.numbers = $DamageNumbers if MetaProgress.setting("numbers") else null
	Juice.calm = MetaProgress.setting("calm")
	Juice.bold_telegraphs = MetaProgress.setting("bold_telegraphs")
	_player.aim_assist = float(MetaProgress.setting("aim_assist"))
	for swarm in _swarms:
		swarm.refresh_warnings()
	if _final_mech:
		_final_mech.refresh_warnings()
	Controls.apply()
	Sound.apply_volumes()


func _exit_tree() -> void:
	Obstacles.clear()
	Juice.reset()
	Elements.reset()


func _process(delta: float) -> void:
	Juice.tick()
	if _game_over:
		if _dying > 0.0:
			_death_frame(delta)
		return
	# A long hitch (window drag, breakpoint) shouldn't teleport the whole horde.
	delta = minf(delta, 0.05)
	if _in_title:
		# Only the scenery lives behind the title screen.
		_spawn_motes(delta, _player.pos2)
		_decor.emit(delta, _player.pos2, _motes)
		_motes.step(delta)
		_decor.follow(_player.pos2)
		_atmosphere.tick(delta, 0.0, false)
		return
	if _rift.in_market():
		_market_frame(delta)
		return
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
	_mid_mech.tick(delta)
	_specialists.tick(delta)
	if _bosses.final_arrived:
		_final_mech.tick(delta)
	if not won or _endless:
		_hazards.tick(delta)
		_events.tick(delta)
		_landmarks.tick(delta)
		_ferryman.tick(delta)
		_rift.tick(delta)
		_rival.tick(delta)
	_run_shards += _events.shards + _landmarks.shards + _ferryman.shards
	_events.shards = 0
	_landmarks.shards = 0
	_ferryman.shards = 0
	var prompt := _rift.prompt if _rift.prompt != "" else (_ferryman.prompt if _ferryman.prompt != "" else _landmarks.prompt)
	var prompt_color := RiftDirector.MARKET_COLOR if _rift.prompt != "" else (Ferryman.COLOR if _ferryman.prompt != "" else _landmarks.prompt_color)
	_hud.set_prompt(prompt if not won or _endless else "", prompt_color)
	var hint := _ferryman.bet_text
	if hint == "" and _rift.glitch_left > 0.0:
		hint = "GLITCH  ·  double XP and souls  ·  back to normal in %d s" % ceili(_rift.glitch_left)
	if hint == "":
		hint = _rival.hint if _rival.hint != "" else (_final_mech.hint if _final_mech.hint != "" else _mid_mech.hint)
	_hud.set_bet(hint)
	_update_frenzy(delta)
	_sample_in -= delta
	if _sample_in <= 0.0:
		_sample_in = DeathRecap.SAMPLE_EVERY
		DeathRecap.add_sample(_timeline, elapsed, _player.stats.hp / _player.stats.max_hp, _director.pressure)
	if _dawn_sweep > 0.0:
		_sweep_horde(delta)

	var contact_dps := 0.0
	for swarm in _swarms:
		var load := swarm.contact_load(origin, Player.RADIUS)
		if load > 0.0:
			contact_dps += load
			_player.take_damage(load * delta, swarm.display_name if swarm.display_name != "" else String(swarm.name))
	_hurt_sound -= delta
	if contact_dps > 0.0:
		if _hurt_sound <= 0.0:
			_hurt_sound = 0.6
			Sound.play("hurt", 1.0, -4.0)
	_hud.set_hurt(contact_dps > 0.0, delta)

	var xp := _gems.step(delta, origin, _player.stats.pickup_radius)
	_gem_streak_time -= delta
	if _gem_streak_time <= 0.0:
		_gem_streak = 0
	if xp > 0:
		_player.add_xp(xp)
		_gem_streak = mini(_gem_streak + 1, 24)
		_gem_streak_time = 0.6
		Sound.play("gem", 1.0 + _gem_streak * 0.03)

	_souls.step(delta, origin, _player.stats.pickup_radius)
	for value in _souls.collected:
		_army.collect_soul(value)
		Sound.play("soul")
	_loot.step(delta, origin, _player.stats.pickup_radius, _player.inventory)

	if not won or _endless:
		_director.tick(delta, origin)
		_director.update_pressure(delta, _player.stats.hp / maxf(_player.stats.max_hp, 1.0), _enemy_count())
	else:
		_director.elapsed += delta
	_player.xp_scale = xp_scale_at(_director.elapsed)
	_fx.step(delta)
	_wisps.step(delta, origin)
	_spawn_motes(delta, origin)
	_decor.emit(delta, origin, _motes)
	_motes.step(delta)
	_decor.follow(origin)
	_update_first_light(delta)
	_atmosphere.tick(delta, elapsed, _bosses.boss_alive() or _bosses.final_alive())

	# The ground plane trails the player in whole grid cells; the grid itself
	# is drawn in world space, so it looks static.
	_ground.global_position = Vector3(
			snappedf(_player.global_position.x, GROUND_SNAP), 0.0,
			snappedf(_player.global_position.z, GROUND_SNAP))

	_hud.refresh(_player.stats, elapsed, kills, _enemy_count(), _player.skills.points)
	_hud.refresh_extras(_run_shards, _player.dash_cooldown_fraction(),
			_bosses.current_boss_name(), _bosses.boss_health())
	_update_clock()
	# Music: the drums swell with the size of the horde and the hour.
	_sound.set_intensity(maxf(_enemy_count() / 700.0, elapsed / 1200.0) if not won else 0.0)
	_sound.set_boss(_bosses.boss_alive() or _bosses.final_alive())
	_hud.set_blessing(_events.blessing, _events.blessing_left,
			EventDirector.BLESSINGS[_events.blessing]["color"] if _events.blessing != "" else Color.WHITE)
	_hud.set_markers(_markers(), $CameraRig/Camera3D)
	_hud.refresh_army(_army.souls, _player.stats.soul_cost, _army.count, _player.stats.minion_max, Army.STANCES[_army.stance]["label"])


## A frame in the Night Market: the realm (horde, clock, spawns, events)
## holds still; the hero, the army, loot and the market run.
func _market_frame(delta: float) -> void:
	_player.tick(delta)
	_army.step(delta)
	_rift.market_tick(delta)
	if not _rift.in_market():
		return
	var origin := _player.pos2
	_loot.step(delta, origin, _player.stats.pickup_radius, _player.inventory)
	_fx.step(delta)
	_wisps.step(delta, origin)
	_motes.step(delta)
	_decor.follow(origin)
	_ground.global_position = Vector3(snappedf(_player.global_position.x, GROUND_SNAP), 0.0,
			snappedf(_player.global_position.z, GROUND_SNAP))
	_hud.refresh(_player.stats, elapsed, kills, 0, _player.skills.points)
	_hud.refresh_extras(_run_shards, _player.dash_cooldown_fraction(), "", -1.0)
	_hud.set_prompt(_rift.prompt, RiftDirector.MARKET_COLOR)
	_hud.set_markers(_rift.markers(), $CameraRig/Camera3D)
	_hud.refresh_army(_army.souls, _player.stats.soul_cost, _army.count, _player.stats.minion_max, Army.STANCES[_army.stance]["label"])


## Pacts and this night's Omen (and the Daily Night's fixed seed).
func _begin_night() -> void:
	pacts = MetaProgress.pacts.duplicate() if MetaProgress.any_won() and not Realm.daily else []
	if Realm.daily:
		var pick := Realm.daily_pick([Realm.current])
		seed(pick["seed"])
		omen = RunModifiers.roll_omen(pick["omen"])
	elif MetaProgress.disabled:
		omen = RunModifiers.forced_omen
	else:
		omen = RunModifiers.roll_omen()
	if RunModifiers.forced_ascension >= 0:
		ascension = RunModifiers.forced_ascension
	else:
		ascension = MetaProgress.ascension if MetaProgress.any_won() and not Realm.daily and not MetaProgress.disabled else 0
	RunModifiers.apply(self, pacts, omen, ascension)
	if ascension > 0:
		_hud.toast("Ascension %d: %s" % [ascension, " ".join(RunModifiers.ASCENSION.slice(0, ascension))], Color(1.0, 0.45, 0.4))
	var vet := MetaProgress.chosen_veteran()
	if not vet.is_empty() and _army.raise_veteran(vet):
		_hud.toast("%s rises from the Crypt to fight beside you." % vet["name"], Army.VETERAN_COLOR)
	if omen == "":
		return
	var o: Dictionary = RunModifiers.OMENS[omen]
	_hud.set_omen("%s%s%s" % ["DAILY NIGHT  ·  " if Realm.daily else "", ("ASCENSION %d  ·  " % ascension) if ascension > 0 else "", o["name"]], o["desc"], o["color"],
			RunModifiers.heat(pacts))
	_hud.toast("Omen: %s. %s" % [o["name"], o["desc"]], o["color"])


## Shards for the end screen, the Bestiary and the Daily record.
func _settle_run(seconds: float) -> int:
	var shards := roundi((_run_shards * MetaProgress.BANKED_RUN_SHARDS + _win_shards + MetaProgress.run_bonus(seconds, kills)) * RunModifiers.shard_mult(pacts, omen, ascension))
	MetaProgress.add_shards(shards)
	for kind: String in MetaProgress.record_kills(_kills_by):
		_hud.toast("Bestiary: a new star for %s (+1%% damage, for good)" % kind, UiStyle.GOLD)
	var code := ""
	if Realm.daily:
		if MetaProgress.record_daily(Realm.today(), kills):
			_hud.toast("A new best for today's Daily Night!", UiStyle.GOLD)
		# The shareable code, on the end screen and in the Daily history.
		var hero := MetaProgress.current_class()
		code = DailyCode.encode(Realm.today(), kills, roundi(elapsed), won, hero)
		MetaProgress.add_daily_run({"date": Realm.today(), "kills": kills, "seconds": roundi(elapsed), "won": won,
				"class": hero, "code": code}, _daily_logged)
		_daily_logged = true
	_hud.set_report(Elements.damage_by, kills, RunModifiers.heat(pacts), omen, code)
	_rest_veterans()
	return shards


## The night is over: veterans from the Crypt go back to rest with their new
## deeds, and the greatest new one joins them.
func _rest_veterans() -> void:
	var newcomer := false
	for v: Dictionary in _army.veterans():
		if v["crypt"] >= 0:
			MetaProgress.entomb(v)
		elif not newcomer:
			newcomer = true
			var id := MetaProgress.entomb(v)
			if id >= 0:
				_army.mark_crypt(v["slot"], id)
				_hud.toast("%s is laid to rest in the Crypt. Choose who rises next on the title screen." % v["name"], Army.VETERAN_COLOR)


## Frenzy decays by half every ~1.4 s; tiers add attack and move speed.
func _update_frenzy(delta: float) -> void:
	frenzy = maxf(frenzy - frenzy * delta * 0.5, 0.0)
	var tier := 0
	for threshold: float in FRENZY_TIERS:
		if frenzy >= threshold:
			tier += 1
	if tier != frenzy_tier:
		if tier > frenzy_tier:
			Sound.play("ignite", 1.4 + 0.15 * tier, 4.0)
		frenzy_tier = tier
		_player.stats.remove_source("frenzy")
		if tier > 0:
			_player.stats.add_mods("frenzy", [
				{"stat": "bolt_rate", "op": PlayerStats.Op.INCREASED, "value": 0.12 * tier},
				{"stat": "move_speed", "op": PlayerStats.Op.INCREASED, "value": 0.05 * tier}])
		_player.stats.recalculate()
		_hud.set_frenzy(tier)


## The end screen's look back: what hurt, what killed, and the night's curve.
func _show_recap(died: bool) -> void:
	DeathRecap.add_sample(_timeline, elapsed, _player.stats.hp / _player.stats.max_hp, _director.pressure)
	_hud.set_recap(DeathRecap.summary(_player.damage_taken_by, _player.last_cause, died), _timeline)


## A Lancer's charge ran into the hero.
func _on_charged(dmg: float, lancer: EnemySwarm) -> void:
	if _player.is_dashing():
		return
	_player.take_damage(dmg, "%s charge" % lancer.display_name)
	Sound.play("hurt")
	Sound.play("slam", 1.5, -8.0)
	Juice.shake(0.3)
	_fx.burst(_player.pos2, 1.0, Color(1.0, 0.3, 0.2), 14, 5.0, 0.45, 0.4, 2.0)


## A Gravedigger calls up the dead: fresh grunts claw out of the ground around
## it, and it swallows the uncollected souls nearby.
func _on_raise_called(at: Vector2, digger: EnemySwarm) -> void:
	if won and not _endless:
		return
	if not _warned.has(digger):
		_warned[digger] = true
		_hud.toast("A %s raises the dead! Kill it first." % digger.display_name, Color(0.7, 0.9, 0.6))
	var eaten := _souls.take_near(at, 7.0)
	for k in 3:
		var p := at + Vector2.from_angle(randf() * TAU) * randf_range(1.2, 2.4)
		if not Obstacles.blocked(p, 0.5):
			_grunts.spawn(p, _director.hp_multiplier())
	Sound.play("grave", 1.2, -4.0)
	_fx.burst(at, 0.3, Color(0.55, 0.9, 1.0) if eaten > 0 else Color(0.45, 0.6, 0.35), 18, 3.0, 0.4, 0.7, 4.0)
	_fx.ring(at, Color(0.45, 0.6, 0.35), 20, 5.0, 0.4, 0.5)


## Run shards for Landmarks: spend_shards(0) is how many there are; otherwise
## takes `n` and returns true, or false if there aren't enough.
func _spend_shards(n: int) -> Variant:
	if n == 0:
		return _run_shards
	if _run_shards < n:
		return false
	_run_shards -= n
	return true


## Edge arrows: the night's events, and any boss.
func _markers() -> Array:
	var out := _events.markers() + _landmarks.markers() + _ferryman.markers() + _rift.markers() + _rival.markers()
	for swarm in _swarms:
		if not swarm.boss:
			continue
		for i in swarm.count:
			if swarm.hp[i] > 0.0:
				out.append({"at": swarm.pos[i], "color": Color(1.0, 0.35, 0.3),
						"label": swarm.display_name.to_upper() if swarm.display_name != "" else "BOSS"})
	return out


## The objective at the top of the screen.
func _update_clock() -> void:
	if _endless:
		_hud.set_clock("ENDLESS  +" + _clock(elapsed - _endless_start), UiStyle.GOLD)
	elif won:
		_hud.set_clock("DAWN", UiStyle.GOLD)
	elif _bosses.final_alive():
		_hud.set_clock("SLAY " + _bosses.final_name.to_upper(), Color(1.0, 0.4, 0.3))
	else:
		var left := _bosses.time_to_final()
		_hud.set_clock("DAWN IN " + _clock(left), Color(1.0, 0.45, 0.35) if left < 60.0 else Color(0.95, 0.93, 0.88))


@warning_ignore("integer_division")
static func _clock(seconds: float) -> String:
	var total := floori(seconds)
	return "%d:%02d" % [total / 60, total % 60]


func _unhandled_input(event: InputEvent) -> void:
	# While a screen is open it handles its own close key (the tree is paused).
	if _choosing_upgrade or _game_over or _in_title:
		return
	if event.is_action_pressed("ui_cancel") and not get_tree().paused:
		Sound.play("ui_click")
		_open_screen(_pause)
	elif event.is_action_pressed("inventory"):
		_open_screen(_inventory_screen)
	elif event.is_action_pressed("skill_tree"):
		_open_screen(_skill_screen)
	elif event.is_action_pressed("army_stance"):
		_army.cycle_stance()
		get_viewport().set_input_as_handled()


func _open_screen(screen: Node) -> void:
	get_tree().paused = true
	screen.open()
	get_viewport().set_input_as_handled()


func _enemy_count() -> int:
	var total := 0
	for swarm in _swarms:
		total += swarm.alive_count()
	return total


## Ambient particles in the realm's style: drifting embers in the Graveyard,
## falling snow in the Frozen Wastes, rising sparks and ash in the Ember Rift.
func _spawn_motes(delta: float, origin: Vector2) -> void:
	_mote_timer -= delta
	while _mote_timer <= 0.0:
		var at := origin + Vector2.from_angle(randf() * TAU) * randf_range(1.0, 20.0)
		match _mote_style:
			"snow":
				_mote_timer += 0.02
				_motes.gravity = 0.45
				_motes.burst(at + Vector2(-3.0, -2.0), randf_range(5.0, 9.0), Color(0.85, 0.92, 1.0, 0.9), 1, 1.6, 0.11, 5.5, 0.0)
			"ash":
				_mote_timer += 0.05
				_motes.gravity = -0.6
				var ember := randf() < 0.7
				_motes.burst(at, randf_range(0.0, 1.5), Color(1.0, 0.4, 0.1) if ember else Color(0.35, 0.3, 0.3, 0.6),
						1, 0.6, 0.12 if ember else 0.18, 4.0, 0.6)
			_:
				_mote_timer += 0.12
				_motes.gravity = -0.25
				var color := Color(1.0, 0.55, 0.25) if randf() < 0.6 else Color(0.5, 0.8, 1.0)
				_motes.burst(at, randf_range(0.2, 2.5), color, 1, 0.5, 0.13, 4.5, 0.4)


func _on_elite_died(at: Vector2, swarm: EnemySwarm) -> void:
	if won and not _endless:
		return
	_run_shards += 2
	Sound.play("elite_kill")
	Juice.hitstop(0.04)
	if randf() < 0.5:
		_events.drop_orb(at + Vector2(-0.6, 0.0))
	_souls.drop(at + Vector2(0.6, 0.0), Army.soul_value(_army.type_index(swarm), true, false))
	_loot.drop(ItemGenerator.generate(ItemData.ilvl_for_player_level(_player.stats.level),
			1.0 + swarm.loot_quality + _player.stats.magic_find), at)
	_fx.burst(at, 1.0, Color(1.0, 0.8, 0.35), 20, 6.0, 0.55, 0.6, 5.0)
	Juice.flash(at, Color(1.0, 0.75, 0.35), 4.0, 8.0, 0.3)


func _on_enemy_died(at: Vector2, xp: int, swarm: EnemySwarm) -> void:
	if won and not _endless:
		# Burned away by the sunrise: no rewards.
		_fx.burst(at, 1.0, Color(1.0, 0.8, 0.5), 3, 2.0, 0.4, 0.8, 3.0)
		return
	kills += 1
	_wisps.from_kill(at)
	var kind := swarm.display_name if swarm.display_name != "" else String(swarm.name)
	_kills_by[kind] = _kills_by.get(kind, 0) + 1
	Sound.play("kill_%d" % (kills % 3))
	_player.bell.on_kill(at)
	frenzy += 1.0
	if swarm == _final:
		_on_final_died(at)
	if swarm.boss:
		_on_boss_died(at, swarm)
		_souls.drop(at + Vector2(0.0, 1.0), Army.soul_value(_army.type_index(swarm), false, true))
	elif randf() < _player.stats.soul_chance * (2.0 if _rift.glitching() else 1.0):
		_souls.drop(at + Vector2(0.0, 0.4), Army.soul_value(_army.type_index(swarm), false, false))
	var big := swarm.body_height > 2.0
	_fx.burst(at, swarm.body_height * 0.5, swarm.color.lightened(0.25), 12 if big else 5,
			5.0 if big else 3.5, 0.55 if big else 0.4, 0.55, 3.0)
	var overflow := _gems.drop(at, xp * (2 if _rift.glitching() else 1))
	if overflow > 0:
		_player.add_xp(overflow)
	if randf() < 0.002 and not swarm.boss:
		_events.drop_orb(at)
	_loot.roll_kill_drop(at, swarm.loot_chance, swarm.loot_quality,
			ItemData.ilvl_for_player_level(_player.stats.level), _player.stats.magic_find)


## The final boss is dead: the night is won. The sun comes up, the horde
## burns away over a few seconds, then the victory screen.
func _on_final_died(at: Vector2) -> void:
	if won:
		return
	won = true
	Juice.slow_motion(0.3, 1.6)
	# The night is settled: the dawn sweep can't also kill the hero.
	_player.invulnerable = true
	_player.burning = 0.0
	MetaProgress.record_win(Realm.current)
	if MetaProgress.record_ascension_win(ascension):
		_hud.toast("Ascension %d unlocked! Choose it under Pact of Night on the title screen." % MetaProgress.ascension_unlocked, Color(1.0, 0.45, 0.4))
	_win_shards += roundi(40.0 * Realm.data()["difficulty"])
	_atmosphere.dawn(true)
	_dawn_glow.dawn(true)
	Sound.play("sunrise")
	_dawn_sweep = DAWN_SWEEP
	_dawn_at = at
	_dawn_front = HazardDirector.make_decal(self, at, Color(1.0, 0.8, 0.45, 0.85), 1.0, 2.0)
	_shots.clear()
	Juice.shake(1.0)
	Juice.flash(at, Color(1.0, 0.85, 0.5), 10.0, 30.0, 1.5)
	_fx.ring(at, Color(1.0, 0.85, 0.5), 80, 20.0, 1.0, 1.0)
	_hud.toast("%s is destroyed. Dawn breaks!" % _bosses.final_name, UiStyle.GOLD)


## How far along the night is (0 at dusk, 1 at dawn), and First Light (0..1:
## nothing until the last FIRST_LIGHT seconds, then the sun begins to rise).
func night_progress() -> float:
	if won or _bosses.final_arrived:
		return 1.0
	return clampf(_director.elapsed / maxf(_bosses.run_length, 1.0), 0.0, 1.0)


## XP from kills at game time `t`: full for the first XP_FADE_FROM seconds,
## then worth less and less (half by 7:00, about a sixth by dawn), so a
## build stops levelling every few seconds once kills come by the hundred.
const XP_FADE_FROM := 300.0
const XP_FADE_SECONDS := 120.0


static func xp_scale_at(t: float) -> float:
	return 1.0 / (1.0 + maxf(t - XP_FADE_FROM, 0.0) / XP_FADE_SECONDS)


func first_light() -> float:
	if _endless:
		return 0.0
	if won or _bosses.final_arrived:
		return 1.0
	return clampf(1.0 - _bosses.time_to_final() / FIRST_LIGHT, 0.0, 1.0)


func _update_first_light(delta: float) -> void:
	var light := first_light()
	_atmosphere.first_light = light
	_dawn_glow.tick(delta, light)
	_hud.set_night(night_progress(), light, not _endless)
	if light > 0.0 and not _first_light_told and not won:
		_first_light_told = true
		_hud.toast("First light. Dawn is coming, and with it, their master...", Color(1.0, 0.75, 0.5))


## The sunrise: a wall of light spreads from where the final boss fell, and
## the horde turns to ash as it passes.
func _sweep_horde(delta: float) -> void:
	_dawn_sweep -= delta
	var reach := DAWN_REACH * smoothstep(0.0, 1.0, 1.0 - _dawn_sweep / DAWN_SWEEP) + 1.0
	if _dawn_front:
		_dawn_front.scale = Vector3.ONE * reach
	for swarm in _swarms:
		for i in swarm.count:
			if swarm.hp[i] > 0.0 and swarm.pos[i].distance_squared_to(_dawn_at) < reach * reach:
				swarm.damage(i, 1.0e12)
	if _dawn_sweep <= 0.0:
		_dawn_sweep = 0.0
		if _dawn_front:
			_dawn_front.queue_free()
			_dawn_front = null
		# Whatever the light didn't reach goes too.
		for swarm in _swarms:
			for i in swarm.count:
				if swarm.hp[i] > 0.0:
					swarm.damage(i, 1.0e12)
		var shards := _settle_run(elapsed)
		get_tree().paused = true
		_sound.stop_music(0.5)
		Sound.play("victory")
		_show_recap(false)
		_hud.show_victory(Realm.data()["name"], elapsed, kills, _player.stats.level, shards)


## After a win: keep playing past dawn for a record, with the night (and the
## mid-bosses) coming back.
func _start_endless() -> void:
	_endless = true
	_endless_start = elapsed
	_player.invulnerable = false
	_run_shards = 0
	_win_shards = 0
	kills = 0
	_bosses.endless = true
	_bosses._next_at = elapsed + 60.0
	_atmosphere.dawn(false)
	_dawn_glow.dawn(false)
	_sound._realm = ""
	_sound.play_realm(Realm.current)
	_hud.hide_end()
	get_tree().paused = false
	_hud.toast("The night returns...", Color(1.0, 0.4, 0.3))


func _on_boss_died(at: Vector2, swarm: EnemySwarm) -> void:
	if swarm != _final:
		_ferryman.boss_slain(at)
	var shards := 15 + 5 * (_bosses.spawned - 1)
	_run_shards += shards
	var ilvl := ItemData.ilvl_for_player_level(_player.stats.level)
	for k in 3:
		_loot.drop(ItemGenerator.generate(ilvl, 2.0 + _player.stats.magic_find), at)
	_fx.ring(at, Color(1.0, 0.6, 0.3), 60, 14.0, 0.8, 0.8)
	_fx.burst(at, 2.0, swarm.color.lightened(0.3), 60, 9.0, 0.7, 1.0, 8.0)
	Juice.flash(at, Color(1.0, 0.6, 0.3), 8.0, 16.0, 0.8)
	Juice.shake(0.8)
	_hud.toast("%s slain!  +%d Soul Shards" % [swarm.display_name, shards], Color(1.0, 0.75, 0.35))


func _on_item_picked(item: Item, result: String) -> void:
	Sound.play("pickup")
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
	if not _spec_chosen and _player.stats.level >= Specializations.LEVEL:
		# Level 10: choose a path (once a night) before any more cards.
		_choosing_upgrade = true
		get_tree().paused = true
		_hud.show_upgrades(Specializations.cards(MetaProgress.current_class()), 0, "CHOOSE YOUR PATH",
				"One path for the rest of the night   ·   1 / 2 / 3 or click")
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
	if id.begins_with("spec:"):
		_spec_chosen = true
		var path := Specializations.find(MetaProgress.current_class(), id.substr(5))
		Specializations.apply(_player.stats, MetaProgress.current_class(), id.substr(5))
		_hud.toast("Your path: %s" % path.get("name", ""), path.get("color", UiStyle.GOLD))
		Sound.play("shrine_done")
	elif id.begins_with(Evolutions.PREFIX):
		var evo: Dictionary = Evolutions.DEFS.get(id.substr(Evolutions.PREFIX.length()), {})
		Upgrades.apply(id, _player.stats)
		_hud.title_card(evo.get("name", ""), "EVOLUTION", evo.get("color", UiStyle.GOLD))
		Sound.play("boss_title", 1.4, -4.0)
		Juice.ring(_player.pos2, evo.get("color", UiStyle.GOLD), 48, 12.0, 0.7, 0.8)
		Juice.flash(_player.pos2, evo.get("color", UiStyle.GOLD), 6.0, 12.0, 0.6)
	else:
		Upgrades.apply(id, _player.stats)
	_choosing_upgrade = false
	get_tree().paused = false
	_try_level_up() # more than one level can be banked


func _on_player_died() -> void:
	if _game_over or (won and not _endless):
		return
	_game_over = true
	_sound.stop_music(0.8)
	Sound.play("defeat")
	if _endless:
		MetaProgress.record_endless(Realm.current, elapsed - _endless_start)
	_rival.hero_fell()
	# The night is settled now (the Crypt gets its veteran before the army falls).
	_death_shards = _settle_run(elapsed - _endless_start)
	# The fall: time slows, the army bursts apart, the hero's souls scatter.
	_dying = DEATH_TIME
	Juice.slow_motion(0.3, 1.2)
	Juice.shake(0.6)
	Juice.flash(_player.pos2, Color(1.0, 0.25, 0.2), 6.0, 10.0, 0.8)
	_fx.ring(_player.pos2, Color(1.0, 0.3, 0.25), 40, 9.0, 0.6, 0.8)
	_wisps.scatter(_player.pos2, 160)
	_army.collapse()
	var visual := _player.get_node("Visual") as Node3D
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(visual, "rotation:x", -1.35, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(visual, "position:y", -0.25, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## While the hero's death plays out: only the effects keep moving.
func _death_frame(delta: float) -> void:
	delta = minf(delta, 0.05)
	_dying -= delta / maxf(Engine.time_scale, 0.05)
	_fx.step(delta)
	_wisps.step(delta, _player.pos2)
	_motes.step(delta)
	_hud.set_hurt(true, delta)
	if _dying <= 0.0:
		_dying = 0.0
		_show_recap(true)
		_hud.show_game_over(elapsed, kills, _player.stats.level, _death_shards)
