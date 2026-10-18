extends SceneTree
## Frame-driven live Main integration and preview exit/save-isolation checks.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	var original_meta_path := MetaProgress.save_path
	MetaProgress.save_path = "user://equipment_preview_meta_%d.save" % Time.get_ticks_usec()
	var meta_file := FileAccess.open(MetaProgress.save_path, FileAccess.WRITE)
	meta_file.store_var({"version": MetaProgress.SAVE_VERSION, "shards": 123})
	meta_file.close()
	var meta_hash := FileAccess.get_sha256(MetaProgress.save_path)
	MetaProgress.disabled = false
	Realm.current = "frozen"
	Realm.daily = true
	Realm.in_title = true
	RunSave.pending = {"preview_test_sentinel": 7}
	var original_path := RunSave.path
	var old_path := "user://equipment_preview_test_%d.save" % Time.get_ticks_usec()
	RunSave.path = old_path
	# A title-readable suspended-run header must exist before preview entry.
	var suspended := {"version": RunSave.VERSION, "realm": "frozen", "elapsed": 42.0, "hero_class": "battlemage"}
	var file := FileAccess.open(old_path, FileAccess.WRITE)
	file.store_var(suspended)
	file.close()
	var suspended_hash := FileAccess.get_sha256(old_path)
	var main: Node = load("res://scenes/pilot/equipment_preview.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	check(not main._in_title and not main.can_suspend(), "preview starts live and cannot overwrite a suspended night")
	check(MetaProgress.disabled and RunSave.path != old_path, "preview isolates account progress and save path")
	var lantern := main.get_node_or_null("PrototypeLantern") as Node3D
	check(lantern != null, "preview includes prepared lantern prop")
	var player: Player = main.get_node("Player")
	var sword: Item = player.inventory.equipped.get("weapon")
	check(sword != null and sword.base_name == "Rune Greatsword", "preview equips sword through actual inventory")
	check((player.inventory.equipped.get("amulet") as Item).base_name == "Amber Amulet", "preview equips amulet through actual inventory")
	check(sword.implicit == ItemData.BASES["weapon"][1]["implicit"], "prototype uses unchanged Staff stats")
	var mesh := Models.item("weapon", "Rune Greatsword", Color.WHITE)
	Input.action_press("move_right")
	for frame in 300:
		player.stats.hp = player.stats.max_hp
		if main._hud._upgrade_root.visible: main._hud._choose(0)
		if frame == 40: player.inventory.unequip("weapon")
		if frame == 70: player.inventory.equip(sword)
		await process_frame
		if frame > 70:
			check(player._visual._weapon.mesh == mesh, "sword survives animated re-equipment")
	Input.action_release("move_right")
	check(main.elapsed > 3.0, "actual Main combat loop advanced")
	main._pause.quit_to_title.emit()
	await process_frame
	await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn", "exit opens ordinary title instead of relaunching preview")
	check(Realm.in_title and Realm.current == "frozen" and Realm.daily, "exit restores realm flags")
	check(not MetaProgress.disabled and RunSave.path == old_path, "exit restores original progress/save guards")
	check(MetaProgress.shards == 123 and FileAccess.get_sha256(MetaProgress.save_path) == meta_hash, "title reloads unchanged account progression")
	check(RunSave.pending.is_empty(), "ordinary title clears transient pending data as usual")
	check(FileAccess.get_sha256(old_path) == suspended_hash, "existing suspended-run file remains byte-identical")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
	RunSave.path = original_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgress.save_path))
	MetaProgress.save_path = original_meta_path
	MetaProgress.disabled = true
	current_scene.queue_free()
	await process_frame
	await process_frame
	print("EQUIPMENT_PREVIEW: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
