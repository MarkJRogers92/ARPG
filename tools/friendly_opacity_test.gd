extends SceneTree
## "Friendly spell opacity" contract: a saved preference (independent of Calm
## effects and Bold warnings) that fades ONLY the hero's own spell visuals (the
## Frost Aura ring and the hero's bolts), while hostile shots, danger warnings,
## hero/ally markers and every gameplay stat stay exactly as they were.
##
##   godot --headless --path . -s tools/friendly_opacity_test.gd
##
## Run under a disposable user-data directory, as with the other suites; the
## profile writes below only ever touch a disposable save path.
const VISUALS = preload("res://scripts/visual/combat_visuals.gd")

var checks := 0
var failures := 0
var _was_disabled := true
var _was_path := "user://meta.save"


func _initialize() -> void:
	_was_disabled = MetaProgress.disabled
	_was_path = MetaProgress.save_path
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_test_sanitize()
	_test_settings()
	_test_registry()
	await _test_live_materials()
	_test_isolation()
	_teardown()
	print("FRIENDLY OPACITY: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


# --- bounded value -----------------------------------------------------------------

func _test_sanitize() -> void:
	check(is_equal_approx(Juice.FRIENDLY_OPACITY_MIN, 0.15), "opacity floor is 0.15")
	check(is_equal_approx(Juice.FRIENDLY_OPACITY_MAX, 1.0), "opacity ceiling is 1.0 (untouched look)")
	check(is_equal_approx(Juice.sanitize_friendly_opacity(0.4), 0.4), "an in-range value is kept")
	check(is_equal_approx(Juice.sanitize_friendly_opacity(5.0), 1.0), "above the ceiling clamps to 1.0")
	check(is_equal_approx(Juice.sanitize_friendly_opacity(-2.0), 0.15), "below the floor clamps to 0.15")
	check(is_equal_approx(Juice.sanitize_friendly_opacity(0.0), 0.15), "zero clamps to the floor, never invisible")
	check(is_equal_approx(Juice.sanitize_friendly_opacity(NAN), 1.0), "NaN falls back to 1.0")
	check(is_equal_approx(Juice.sanitize_friendly_opacity(INF), 1.0), "infinity falls back to 1.0")
	check(is_equal_approx(Juice.sanitize_friendly_opacity("0.3"), 1.0), "a non-number falls back to 1.0")
	check(is_equal_approx(Juice.sanitize_friendly_opacity(null), 1.0), "a missing value falls back to 1.0")


# --- saved preference --------------------------------------------------------------

func _test_settings() -> void:
	MetaProgress.disabled = false
	MetaProgress.save_path = "user://friendly_opacity_qa.save"
	_wipe()
	MetaProgress.load_save()
	check(MetaProgress.SETTINGS.has("friendly_opacity"), "the setting is registered")
	check(MetaProgress.SETTINGS.has("calm") and MetaProgress.SETTINGS.has("bold_telegraphs"),
			"Calm effects and Bold warnings stay independent settings")
	check(is_equal_approx(float(MetaProgress.setting("friendly_opacity")), 1.0), "a fresh save defaults to 1.0")

	MetaProgress.set_setting("friendly_opacity", 0.4)
	check(is_equal_approx(float(MetaProgress.setting("friendly_opacity")), 0.4), "a valid value is stored")
	MetaProgress.set_setting("friendly_opacity", 9.0)
	check(is_equal_approx(float(MetaProgress.setting("friendly_opacity")), 1.0), "an out-of-range value clamps on save")
	MetaProgress.set_setting("friendly_opacity", -0.5)
	check(is_equal_approx(float(MetaProgress.setting("friendly_opacity")), 0.15), "a negative value clamps to the floor")
	MetaProgress.set_setting("friendly_opacity", NAN)
	check(is_equal_approx(float(MetaProgress.setting("friendly_opacity")), 1.0), "NaN is rejected on save")
	MetaProgress.set_setting("friendly_opacity", 0.35)

	# Survives a real write-and-reload.
	MetaProgress.settings["friendly_opacity"] = 0.9
	MetaProgress.load_save()
	check(is_equal_approx(float(MetaProgress.setting("friendly_opacity")), 0.35), "the value survives a save/reload")

	# A corrupt or hand-edited save value is clamped on load.
	var data = CampaignSave.read_variant(MetaProgress.save_path)
	data["settings"]["friendly_opacity"] = 42.0
	var file := FileAccess.open(MetaProgress.save_path, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()
	MetaProgress.load_save()
	check(is_equal_approx(float(MetaProgress.setting("friendly_opacity")), 1.0), "a corrupt saved opacity clamps on load")

	_wipe()
	MetaProgress.save_path = _was_path
	MetaProgress.disabled = _was_disabled
	MetaProgress.load_save()


# --- material registry -------------------------------------------------------------

func _test_registry() -> void:
	Juice.clear_friendly_materials()
	Juice.set_friendly_opacity(1.0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/aura.gdshader")
	Juice.register_friendly_material(mat)
	check(Juice._friendly_materials.size() == 1, "a friendly material is tracked once")
	Juice.register_friendly_material(mat)
	check(Juice._friendly_materials.size() == 1, "registering the same material twice is deduped")
	Juice.register_friendly_material(null)
	check(Juice._friendly_materials.size() == 1, "a null material is ignored")

	Juice.set_friendly_opacity(0.4)
	check(is_equal_approx(float(mat.get_shader_parameter("friendly_opacity")), 0.4),
			"a registered friendly material follows a live change")
	check(is_equal_approx(Juice.friendly_opacity, 0.4), "the applied value is remembered")

	# The registry is bounded and prunes freed resources (no stale material).
	var weak: WeakRef = weakref(mat)
	mat = null
	Juice.apply_friendly_opacity()
	check(weak.get_ref() == null and Juice._friendly_materials.is_empty(), "a freed friendly material is pruned")

	# Registering many distinct materials stays one entry each (no runaway growth).
	for i in 8:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/friendly_glow.gdshader")
		Juice.register_friendly_material(m)
	check(Juice._friendly_materials.size() == 8, "one slot per distinct friendly material")
	Juice.clear_friendly_materials()
	check(Juice._friendly_materials.is_empty(), "clear() forgets every friendly material")


# --- the real hero visuals ---------------------------------------------------------

func _test_live_materials() -> void:
	Juice.clear_friendly_materials()
	Juice.set_friendly_opacity(1.0)
	var host := Node3D.new()
	root.add_child(host)

	var player := load("res://scenes/player.tscn").instantiate() as Player
	host.add_child(player)
	var aura_mat := player._aura_visual.material_override as ShaderMaterial
	check(aura_mat != null and aura_mat.shader.resource_path.ends_with("aura.gdshader"),
			"the Frost Aura keeps its own friendly-only shader")
	check(is_equal_approx(float(aura_mat.get_shader_parameter("friendly_opacity")), 1.0),
			"the aura starts untouched at 1.0")
	Juice.set_friendly_opacity(0.4)
	check(is_equal_approx(float(aura_mat.get_shader_parameter("friendly_opacity")), 0.4),
			"a live change fades the real aura material")

	var proj := ProjectileSwarm.new()
	proj.capacity = 8
	host.add_child(proj)
	var bolt_mat := proj.material_override as ShaderMaterial
	check(bolt_mat != null and bolt_mat.shader.resource_path.ends_with("friendly_glow.gdshader"),
			"hero bolts use a dedicated friendly-only shader")
	check(is_equal_approx(float(bolt_mat.get_shader_parameter("friendly_opacity")), 0.4),
			"a new bolt material picks up the current setting")
	check((proj.multimesh.mesh.surface_get_material(0) as ShaderMaterial).shader.resource_path.ends_with("glow.gdshader"),
			"the shared glow behind the bolts is not rewritten")
	Juice.set_friendly_opacity(0.15)
	check(is_equal_approx(float(bolt_mat.get_shader_parameter("friendly_opacity")), 0.15),
			"a live change fades the real bolt material")

	# Gameplay is untouched: attack stats and flight do not read the opacity.
	player.stats.recalculate()
	var dmg := player.stats.bolt_damage
	var hp_before := player.stats.hp
	proj.spawn(Vector2.ZERO, Vector2.RIGHT, 12.0, dmg, 0, 1.0)
	check(proj.count == 1 and is_equal_approx(proj._damage[0], dmg), "a bolt keeps its damage while faded")
	check(is_equal_approx(proj._vel[0].length(), 12.0), "a bolt keeps its speed while faded")
	Juice.set_friendly_opacity(0.15)
	check(is_equal_approx(proj._damage[0], dmg), "further fades leave attack stats alone")
	check(is_equal_approx(player.stats.hp, hp_before), "opacity never touches the hero's hit points")

	host.queue_free()
	await process_frame
	await process_frame
	Juice.clear_friendly_materials()


# --- hostile, warning and marker isolation -----------------------------------------

func _test_isolation() -> void:
	Juice.bold_telegraphs = false
	Juice.set_friendly_opacity(0.15)

	# The shared hostile/hazard glow (falling ice orbs) must not fade.
	var hazard := Models.material("glow")
	check(hazard.get_shader_parameter("friendly_opacity") == null,
			"the shared hostile hazard glow carries no friendly uniform")

	# Danger warnings keep their exact hue and opacity.
	var warn_color := Color(1.0, 0.35, 0.12, 0.85)
	var warn := VISUALS.warning_material(warn_color)
	check(warn.get_shader_parameter("color") == warn_color, "danger warnings keep their hue and opacity")
	check(warn.get_shader_parameter("friendly_opacity") == null, "danger warnings have no friendly uniform")

	# Hero and ally markers must stay at full strength.
	var marker := VISUALS.ally_marker_material()
	check(marker.get_shader_parameter("friendly_opacity") == null, "ally markers never fade")

	# Hostile shots keep their dedicated solid threat shader.
	var shots := EnemyShots.new()
	shots.capacity = 2
	root.add_child(shots)
	var shot_mat := shots.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	check(shot_mat.shader.resource_path.ends_with("hostile_shot.gdshader"), "hostile shots keep their threat shader")
	check(shot_mat.get_shader_parameter("friendly_opacity") == null, "hostile shots have no friendly uniform")
	shots.free()

	# The hero locator marker on the real player is a marker, not a spell.
	var host := Node3D.new()
	root.add_child(host)
	var player := load("res://scenes/player.tscn").instantiate() as Player
	host.add_child(player)
	var locator_mat := (player.get_node("Marker") as MeshInstance3D).material_override as ShaderMaterial
	check(locator_mat.get_shader_parameter("friendly_opacity") == null, "the hero locator marker never fades")
	Juice.set_friendly_opacity(0.15)
	check(locator_mat.get_shader_parameter("friendly_opacity") == null, "a live change leaves the hero marker alone")
	host.free()


func _teardown() -> void:
	# Restore the shared aura material to its untouched look before forgetting
	# it (the PackedScene shares sub-resources between instances).
	Juice.set_friendly_opacity(1.0)
	Juice.clear_friendly_materials()
	Juice.friendly_opacity = 1.0
	Juice.reset()
	Elements.reset()
	MetaProgress.disabled = _was_disabled
	MetaProgress.save_path = _was_path
	MetaProgress.load_save()


func _wipe() -> void:
	for suffix in ["", ".bak", ".tmp", ".rollback", ".previous"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MetaProgress.save_path + suffix))
