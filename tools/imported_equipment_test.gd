extends SceneTree
## Real imported mesh, inventory, socket, and icon framing regression.
var checks := 0
var failures: Array[String] = []
const SWORD := "Rune Greatsword"

func _initialize() -> void:
	MetaProgress.disabled = true
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	var mesh := Models.item("weapon", SWORD, Color.WHITE)
	check(mesh.get_surface_count() > 0, "registered sword has an imported mesh")
	if mesh.get_surface_count() == 0:
		_report()
		return
	var bounds := mesh.get_aabb()
	check(bounds.size.y > 1.45 and bounds.size.y < 1.6, "sword is scaled to about 1.52 metres")
	check(bounds.position.y < 0 and bounds.end.y > 1.0, "grip origin lies within handle with blade upward")
	check(mesh == Models.item("weapon", SWORD, Color.RED), "textured mesh cache is independent of rarity color")
	var triangles := 0
	for surface in mesh.get_surface_count():
		triangles += mesh.surface_get_array_index_len(surface) / 3
		var material := mesh.surface_get_material(surface) as StandardMaterial3D
		check(material != null, "PBR material retained")
		if material:
			check(material.albedo_texture != null, "base color retained")
			check(material.normal_enabled and material.normal_texture != null, "normal map retained")
			check(material.metallic_texture != null and material.roughness_texture != null, "metallic/roughness retained")
	check(triangles == 4951, "all 4,951 source triangles retained")
	for imported in [false, true]:
		ProjectSettings.set_setting("visuals/imported_roster", imported)
		ProjectSettings.set_setting("visuals/aegis_battlemage", imported)
		var hero := HeroModel.new()
		root.add_child(hero)
		hero.set_process(false)
		for id: String in HeroClass.ORDER:
			hero.set_body(HeroClass.data(id)["look"])
			hero.set_weapon(SWORD, Color.WHITE)
			check(hero._weapon.mesh == mesh, "real equipment path selects sword for " + id)
			check(hero._weapon.position.is_zero_approx(), "sword grip is at hand mount for " + id)
			for frame in 60:
				hero.set_motion(Vector2(3, -2), 1.0 / 60.0)
				if frame == 10: hero.cast()
				hero._process(1.0 / 60.0)
				check(hero._weapon.global_position.is_equal_approx(hero._weapon_pivot.global_position), "animated sword grip follows mount")
			hero.set_weapon("Wand", Color.WHITE)
			check(hero._weapon.mesh != mesh, "swapping away restores existing weapon")
			hero.set_weapon(SWORD, Color.WHITE)
			check(hero._weapon.position.is_zero_approx(), "swapping back clears old grip offsets")
		hero.queue_free()
		await process_frame
	var item := Item.new()
	item.slot = "weapon"
	item.base_name = SWORD
	item.name = SWORD
	var inventory := Inventory.new(PlayerStats.new())
	check(inventory.pickup(item) == "equipped", "sword uses ordinary inventory pickup/equip")
	var restored := Inventory.new(PlayerStats.new())
	restored.restore(inventory.to_dict())
	check((restored.equipped["weapon"] as Item).base_name == SWORD, "existing serialization preserves sword identity")
	var model := MeshInstance3D.new()
	model.mesh = mesh
	var icons := ItemIcons.new()
	icons._pose(model, item)
	check((model.transform * bounds.get_center()).length() < 0.12, "grip-centered sword is recentered in inventory icon")
	model.free()
	icons.free()
	var loot := LootDrop.new()
	loot.setup(item, Vector2.ZERO)
	root.add_child(loot)
	check(loot._model.mesh == mesh, "ground loot displays imported sword")
	loot.queue_free()
	await process_frame
	var amulet_mesh := Models.item("amulet", "Amber Amulet", Color.WHITE)
	var amulet_box := amulet_mesh.get_aabb()
	check(amulet_box.size.y > 0.34 and amulet_box.size.y < 0.36, "amulet is scaled to about 0.35 metres")
	check(amulet_box.position.y < -0.28, "amulet hangs below top-ring pivot")
	var amulet_triangles := 0
	for surface in amulet_mesh.get_surface_count():
		amulet_triangles += amulet_mesh.surface_get_array_index_len(surface) / 3
		var material := amulet_mesh.surface_get_material(surface) as StandardMaterial3D
		check(material != null and material.albedo_texture != null and material.normal_texture != null and material.metallic_texture != null, "amulet keeps all PBR textures")
	check(amulet_triangles == 5278, "all 5,278 amulet triangles retained")
	var amulet := Item.new()
	amulet.slot = "amulet"
	amulet.base_name = "Amber Amulet"
	amulet.name = "Amber Amulet"
	check(inventory.pickup(amulet) == "equipped", "amulet uses normal accessory slot")
	var amulet_icon := MeshInstance3D.new()
	amulet_icon.mesh = amulet_mesh
	var amulet_icons := ItemIcons.new()
	amulet_icons._pose(amulet_icon, amulet)
	check((amulet_icon.transform * amulet_box.get_center()).length() < 0.12, "hanging amulet is recentered in inventory icon")
	amulet_icon.free()
	amulet_icons.free()
	var names: Array[String] = []
	for base: Dictionary in ItemData.BASES["weapon"]:
		names.append(base.name)
	check(names == ["Wand", "Staff", "Orb"], "default drop pool remains unchanged")
	Elements.player = null
	Elements.swarms.clear()
	_report()

func _report() -> void:
	print("IMPORTED_EQUIPMENT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
