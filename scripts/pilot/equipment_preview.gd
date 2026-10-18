extends "res://scripts/main.gd"
## Opt-in live equipment review using Main, inventory, combat, and camera.
## The sword is a casting-focus visual prototype, not a melee weapon system.
var _saved_meta_disabled := false
var _saved_realm := ""
var _saved_title := true
var _saved_daily := false
var _saved_pending: Dictionary
var _saved_run_path := ""

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
	RunSave.path = "user://equipment_preview.run.save"
	super._enter_tree()

func _ready() -> void:
	super._ready()
	var sword := Item.new()
	sword.slot = "weapon"
	sword.base_name = "Rune Greatsword"
	sword.name = "Rune Greatsword · prototype focus"
	# Exactly the existing level-one Staff implicit, with no new attack logic.
	sword.implicit.assign(ItemData.BASES["weapon"][1]["implicit"].duplicate(true))
	_player.inventory.pickup(sword)
	_player.inventory.equip(sword)
	var amulet := Item.new()
	amulet.slot = "amulet"
	amulet.base_name = "Amber Amulet"
	amulet.name = "Amber Amulet · prototype"
	amulet.implicit.assign(ItemData.BASES["amulet"][1]["implicit"].duplicate(true))
	_player.inventory.pickup(amulet)
	for connection: Dictionary in _pause.quit_to_title.get_connections():
		_pause.quit_to_title.disconnect(connection.callable)
	_pause.quit_to_title.connect(_return_to_normal_title)
	for connection: Dictionary in _hud.realms_pressed.get_connections():
		_hud.realms_pressed.disconnect(connection.callable)
	_hud.realms_pressed.connect(_return_to_normal_title)
	_hud.toast("EQUIPMENT PREVIEW · Rune Greatsword casts normal bolts · Tab opens inventory", Color(0.65, 0.85, 1.0))

func can_suspend() -> bool:
	return false

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
