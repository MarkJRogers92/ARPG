extends "res://scripts/main.gd"
## Opt-in actual Main session. Normal player, weapons, camera, HUD and rewards.
## The default scene never loads this subclass or the guardian assets.
var _saved_meta_disabled := false
var _saved_realm := ""
var _saved_title := true
var _saved_daily := false
var _saved_pending: Dictionary
var _saved_run_path := ""
var _respawn_in := 5.0
var guardians: GuardianSwarm

func _enter_tree() -> void:
	_saved_meta_disabled = MetaProgress.disabled
	_saved_realm = Realm.current
	_saved_title = Realm.in_title
	_saved_daily = Realm.daily
	_saved_pending = RunSave.pending
	_saved_run_path = RunSave.path
	MetaProgress.disabled = true
	Realm.current = "graveyard"
	Realm.in_title = false
	Realm.daily = false
	RunSave.pending = {}
	RunSave.path = "user://guardian_encounter.run.save"
	super._enter_tree()

func _ready() -> void:
	super._ready()
	guardians = $Guardians
	guardians.player = _player
	# Inherited reload-to-title callbacks would reopen this opt-in scene.
	for connection: Dictionary in _pause.quit_to_title.get_connections():
		_pause.quit_to_title.disconnect(connection.callable)
	_pause.quit_to_title.connect(_return_to_normal_title)
	for connection: Dictionary in _hud.realms_pressed.get_connections():
		_hud.realms_pressed.disconnect(connection.callable)
	_hud.realms_pressed.connect(_return_to_normal_title)
	spawn_guardian()
	_hud.toast("GUARDIAN ENCOUNTER · WASD move · Space dash · G summons the mid-boss (max 1)", Color(0.65, 0.85, 1.0))

func _process(delta: float) -> void:
	super._process(delta)
	if guardians == null or _game_over or _in_title or _player.dead: return
	if guardians.alive_count() == 0:
		_respawn_in -= minf(delta, 0.05)
		if _respawn_in <= 0.0:
			spawn_guardian()
			_respawn_in = 5.0
	else:
		_respawn_in = 5.0

func spawn_guardian() -> bool:
	if guardians == null or _player.dead or guardians.alive_count() >= 1: return false
	var at := _player.pos2 + Vector2(5.0, -5.0)
	at = Obstacles.resolve_slide(at, guardians.radius, Vector2.ZERO)
	return guardians.spawn(at)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G and not get_tree().paused and not _game_over:
		spawn_guardian()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)

func can_suspend() -> bool:
	return false # This isolated opt-in encounter is never a resumable Classic run.

func _exit_tree() -> void:
	super._exit_tree()
	MetaProgress.disabled = _saved_meta_disabled
	Realm.current = _saved_realm
	Realm.in_title = _saved_title
	Realm.daily = _saved_daily
	RunSave.pending = _saved_pending
	RunSave.path = _saved_run_path

func _return_to_normal_title() -> void:
	_saved_title = true
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")
