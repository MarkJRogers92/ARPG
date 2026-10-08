class_name ExpeditionDirector
extends Node3D
## Mission-local objectives and outcome arbitration for a disposable campaign
## combat scene. This node never settles currency or writes account progress.

signal terminal_ready(result: Dictionary)

const RITUAL_SECONDS := 2.0
const OBJECTIVE_COLOR := Color(0.35, 0.92, 1.0)
const ELITE_COLOR := Color(1.0, 0.55, 0.22)
const CACHE_COLOR := Color(0.8, 0.55, 1.0)

var spec: Dictionary = {}
var terminal := false
var result: Dictionary = {}
var seals := 0
var elite_dead := false
var cache_claimed := false
var _main: Node3D
var _player: Player
var _wave: WaveDirector
var _bosses: BossDirector
var _swarms: Array[EnemySwarm] = []
var _rng := RandomNumberGenerator.new()
var _sites: Array[Vector2] = []
var _site_claimed: Array[bool] = []
var _visuals: Array[Node3D] = []
var _elite_spawned := false
var _last_objective_text := ""
var _signal_sent := false
var _marked_swarm: EnemySwarm
var _marked_id := -1
var _ledger_spawned := false
var _ledger_half_spawned := false
var _ledger_reinforcements := 0
var _late_wave_spawned := false
var _unfinished_spawned := false
var _cache_guardians_spawned := false

var contract_id := "hunt"
var duration := 300.0
var deadline := 0.0
var finale := false
var elite_at := 300.0
var cache_enabled := false


func configure(mission: Dictionary, owner: Node3D, player: Player, wave: WaveDirector,
		boss_director: BossDirector, swarms: Array[EnemySwarm]) -> void:
	spec = mission.duplicate(true)
	_main = owner
	_player = player
	_wave = wave
	_bosses = boss_director
	_swarms = swarms
	contract_id = String(spec.get("contract_id", "hunt"))
	finale = bool(spec.get("final_boss", false))
	var contracts := {"hunt": [300.0, 0.0], "breach": [360.0, 420.0], "seal_breach": [360.0, 420.0],
		"elite_hunt": [300.0, 420.0], "cursed_cache": [360.0, 0.0]}
	var values: Array = contracts.get(contract_id, [300.0, 0.0])
	duration = float(spec.get("duration", values[0]))
	deadline = float(spec.get("deadline", values[1]))
	elite_at = float(spec.get("elite_at", 300.0 if contract_id == "elite_hunt" else duration * 0.58))
	cache_enabled = contract_id == "cursed_cache"
	_rng.seed = int(spec.get("mission_seed", 1))
	if contract_id in ["seal_breach", "breach"]:
		for i in 3:
			_add_site("seal_%d" % (i + 1), OBJECTIVE_COLOR, "SEAL %d / 3" % (i + 1))
	elif cache_enabled:
		_add_site("cache", CACHE_COLOR, "CURSED CACHE  ·  %s" % Controls.tag("interact"))
	if contract_id == "elite_hunt":
		_add_site("elite", ELITE_COLOR, "MARKED ELITE")
	if finale:
		_bosses.run_length = 900.0
		_bosses.final_enabled = true
	else:
		_bosses.final_enabled = false
		_bosses.run_length = 900.0
	_setup_difficulty()
	_present_arrival()
	_build_arrival_landmark()


## A brief, nonblocking arrival card repeats the place and the committed task.
## The HUD remains the source of objective timing and interaction prompts.
func _present_arrival() -> void:
	if not is_instance_valid(_main):
		return
	var hud := _main.get_node_or_null("Hud") as Hud
	if hud == null:
		return
	var biome := clampi(int(spec.get("biome_index", 0)), 0, Realm.ORDER.size() - 1)
	var realm: Dictionary = Realm.data(Realm.ORDER[biome])
	var contract: Dictionary = CampaignCatalog.CONTRACTS.get(contract_id, {})
	var task := str(contract.get("name", contract_id.replace("_", " ").capitalize()))
	var objective := objective_text()
	hud.title_card(str(realm.get("name", "The Hollow Graveyard")), "%s  ·  %s" % [task, objective], Color(0.78, 0.88, 0.98), true)
	Sound.play("soul", 0.82, -7.0)


## A low, non-colliding entry seal makes the first Graveyard arrival feel
## deliberately placed while leaving the spawn lane and enemy silhouettes open.
func _build_arrival_landmark() -> void:
	var node_id := str(spec.get("node_id", ""))
	if int(spec.get("biome_index", 0)) != 0 or not node_id.begins_with("0:1:") or finale:
		return
	var kit := MeshKit.new()
	kit.flat = true
	kit.max_segments = 20
	var stone := Color(0.3, 0.34, 0.4)
	var ash_stone := Color(0.24, 0.25, 0.27)
	var brass := Color(0.61, 0.43, 0.24)
	var soul := Color(0.34, 0.86, 1.0)
	var moss := Color(0.17, 0.25, 0.16)
	# A short, walkable causeway leads from the spawn into an open cemetery gate.
	for row in 8:
		var z := -0.5 - float(row) * 0.86
		for col in 3:
			var x := float(col - 1) * 0.92 + (0.16 if row % 2 == 0 else -0.16) + float((row + col * 3) % 3 - 1) * 0.035
			var width := 0.78 + float((row + col) % 3) * 0.035
			var depth := 0.7 + float((row * 2 + col) % 3) * 0.035
			var shade := float((row + col * 2) % 4) * 0.045
			kit.box(Vector3(width, 0.1, depth), MeshKit.at(Vector3(x, 0.045, z), Vector3(0, float((row + col) % 3 - 1) * 3.0, 0)), stone.darkened(0.05 + shade))
	# Loose moss follows the causeway seams instead of becoming a full floor mat.
	for row in [1, 4, 6]:
		var side := -1.0 if row % 2 == 0 else 1.0
		var moss_at := Vector3(side * (1.48 + float(row % 2) * 0.12), 0.06, -0.5 - float(row) * 0.86)
		kit.sphere(0.18, MeshKit.at(moss_at, Vector3.ZERO, Vector3(1.7, 0.16, 0.7)), moss.darkened(0.04), 0, 6, 3)
	# Heavy piers stand outside the fighting lane. Broken shoulders and split
	# lintels frame the route while keeping the center open for the hero and HUD.
	for side: float in [-1.0, 1.0]:
		var x := side * 4.55
		var z := -3.9
		var shade := 0.07 if side < 0.0 else 0.0
		kit.box(Vector3(1.12, 0.18, 1.25), MeshKit.at(Vector3(x, 0.09, z)), ash_stone.lightened(shade))
		kit.box(Vector3(0.94, 0.18, 1.08), MeshKit.at(Vector3(x, 0.27, z)), stone.darkened(0.17))
		kit.box(Vector3(0.7, 0.22, 0.83), MeshKit.at(Vector3(x, 0.47, z)), stone.darkened(0.04))
		kit.box(Vector3(0.61, 1.72, 0.72), MeshKit.at(Vector3(x, 1.42, z)), stone.darkened(0.06 + shade))
		# Raised corner ribs and a narrow seam give the shaft carved courses.
		for edge: float in [-1.0, 1.0]:
			kit.box(Vector3(0.08, 1.68, 0.08), MeshKit.at(Vector3(x + edge * 0.3, 1.42, z - 0.38)), stone.lightened(0.12))
		kit.box(Vector3(0.76, 0.13, 0.88), MeshKit.at(Vector3(x, 2.32, z)), stone.darkened(0.02))
		kit.box(Vector3(1.0, 0.18, 1.12), MeshKit.at(Vector3(x, 2.49, z)), ash_stone.lightened(0.1))
		kit.box(Vector3(1.12, 0.16, 1.24), MeshKit.at(Vector3(x, 2.66, z)), stone.lightened(0.12))
		# A shallow cyan-cut rune faces the arrival lane.
		kit.box(Vector3(0.07, 0.66, 0.035), MeshKit.at(Vector3(x, 1.36, z - 0.383), Vector3(0, 0, side * 5)), soul.darkened(0.1), 0.28)
		kit.box(Vector3(0.22, 0.055, 0.04), MeshKit.at(Vector3(x, 1.42, z - 0.39), Vector3(0, 0, 35)), brass, 0.05)
		var wall_x := side * 6.0
		if side < 0.0:
			kit.box(Vector3(2.18, 0.68, 0.78), MeshKit.at(Vector3(wall_x, 0.5, z + 0.25), Vector3(0, 0, 2)), stone.darkened(0.16))
			kit.box(Vector3(2.25, 0.15, 0.84), MeshKit.at(Vector3(wall_x, 0.91, z + 0.25), Vector3(0, 0, 2)), stone.lightened(0.06))
		else:
			# The eastern wing has slumped; mismatched courses and a fallen block
			# break the silhouette without narrowing the player lane.
			kit.box(Vector3(1.15, 0.48, 0.76), MeshKit.at(Vector3(wall_x - 0.48, 0.39, z + 0.25), Vector3(0, 0, -4)), ash_stone)
			kit.box(Vector3(1.28, 0.63, 0.75), MeshKit.at(Vector3(wall_x + 0.45, 0.43, z + 0.27), Vector3(0, 0, 7)), stone.darkened(0.15))
			kit.box(Vector3(0.8, 0.2, 0.8), MeshKit.at(Vector3(wall_x + 1.0, 0.13, z + 1.05), Vector3(0, 12, 7)), stone.darkened(0.12))
			kit.sphere(0.32, MeshKit.at(Vector3(wall_x - 0.6, 0.79, z + 0.12), Vector3(0, 0, -18), Vector3(1.5, 0.18, 0.8)), moss, 0, 6, 3)
		# Split lintels and lanterns use opposing cool and warm tones.
		var lantern_color := Color(1.0, 0.61, 0.3) if side < 0.0 else soul
		var arm := side * 0.42
		kit.box(Vector3(0.12, 0.1, 0.58), MeshKit.at(Vector3(x + arm, 3.03, z)), brass.lightened(0.08))
		kit.box(Vector3(0.42, 0.09, 0.09), MeshKit.at(Vector3(x + side * 0.61, 3.03, z)), brass)
		kit.box(Vector3(0.3, 0.5, 0.3), MeshKit.at(Vector3(x + side * 0.66, 2.73, z)), ash_stone)
		kit.box(Vector3(0.21, 0.31, 0.21), MeshKit.at(Vector3(x + side * 0.66, 2.74, z)), lantern_color, 0.65)
		kit.sphere(0.11, MeshKit.at(Vector3(x + side * 0.66, 3.04, z)), lantern_color, 0.42, 6, 4)
	# Lintels stop short of the center, leaving a clear doorway sightline.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(2.25, 0.22, 0.82), MeshKit.at(Vector3(side * 3.12, 2.88, -3.9), Vector3(0, 0, side * -2)), stone.lightened(0.05))
		kit.box(Vector3(1.92, 0.13, 0.88), MeshKit.at(Vector3(side * 3.02, 3.045, -3.9), Vector3(0, 0, side * -2)), ash_stone.lightened(0.15))
		kit.box(Vector3(0.08, 0.035, 0.025), MeshKit.at(Vector3(side * 2.65, 2.72, -3.48)), soul.darkened(0.15), 0.28)
	var landmark := MeshInstance3D.new()
	landmark.name = "GraveyardArrivalGate"
	landmark.mesh = kit.commit(Models.material("kit"))
	landmark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(landmark)
	_add_arrival_memorial(Vector2(-7.15, -5.7))


func _add_arrival_memorial(center: Vector2) -> void:
	var memorial_at := Vector2.ZERO
	var found := false
	for candidate: Vector2 in [center, Vector2(7.15, -5.7), Vector2(-7.15, -7.2), Vector2(7.15, -7.2)]:
		var clear := not Obstacles.blocked(candidate, 1.2)
		for site: Vector2 in _sites:
			if candidate.distance_to(site) < 4.0:
				clear = false
				break
		if clear:
			memorial_at = candidate
			found = true
			break
	if not found:
		return
	var mesh := AssetProps.mesh("rune_gravestone")
	if mesh == null:
		return
	var memorial := MeshInstance3D.new()
	memorial.name = "ArrivalMemorial"
	memorial.mesh = mesh
	memorial.position = Vector3(memorial_at.x, 0, memorial_at.y)
	memorial.scale = Vector3.ONE * 0.82
	memorial.rotation_degrees.y = 20.0
	add_child(memorial)


func _setup_difficulty() -> void:
	if _wave == null:
		return
	var biome := int(spec.get("biome_index", 0))
	var elite := bool(spec.get("elite", false))
	var finale_scale := 1.0 if finale else 0.0
	_wave.configure_expedition({
		"spawn_rate": [0.72, 0.82, 0.92][clampi(biome, 0, 2)] * (1.25 if elite else 1.0),
		"hp_scale": [0.8, 0.9, 1.0][clampi(biome, 0, 2)] * (1.15 if elite else 1.0),
		"age_rate": 1.8 if finale else 2.4,
		"growth_cap": 900.0 if finale else 420.0,
		"finale_scale": finale_scale,
	})
	_bosses.expedition_mode = true
	# The Classic base boss reaches roughly ten times its starting HP by 15:00.
	# These campaign-only factors keep that actual array HP in a viable range;
	# the full realm mechanics and 900-second clock remain intact.
	_bosses.final_hp_scale = [0.035, 0.04, 0.045][clampi(biome, 0, 2)]
	_bosses.mid_boss_first_at = 150.0 if not finale else 180.0
	_bosses.mid_boss_interval = 360.0 if not finale else 210.0
	_bosses._next_at = _bosses.mid_boss_first_at
	_bosses.slam_interval = 6.0
	_bosses.ring_interval = 7.5
	_bosses.ring_shots = 14
	_bosses.summon_interval = 18.0
	_bosses.summon_count = 7
	if _main and _main.has_node("Loot"):
		var loot := _main.get_node("Loot") as LootManager
		loot.budgeted = true
		loot.drops_per_minute = 1.0
		loot.token_cap = 1.0


func _add_site(id: String, color: Color, label_text: String) -> void:
	var at := _reachable_site(_sites.size())
	_sites.append(at)
	_site_claimed.append(false)
	var holder := Node3D.new()
	holder.name = id
	holder.position = Vector3(at.x, 0.0, at.y)
	add_child(holder)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.1
	ring_mesh.outer_radius = 1.35
	ring.mesh = ring_mesh
	ring.position.y = 0.08
	ring.material_override = _emissive(color, 0.95)
	holder.add_child(ring)
	var beam := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.08
	cylinder.bottom_radius = 0.22
	cylinder.height = 2.8
	beam.mesh = cylinder
	beam.position.y = 1.45
	beam.material_override = _emissive(color, 0.34)
	holder.add_child(beam)
	var label := Label3D.new()
	label.text = label_text
	label.position.y = 3.1
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 8
	label.modulate = color
	holder.add_child(label)
	ObjectiveProps.attach(holder, id, color)
	_visuals.append(holder)


func _emissive(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	return material


func _reachable_site(index: int) -> Vector2:
	var origin := _player.pos2 if _player else Vector2.ZERO
	var angle_offset := _rng.randf_range(-0.18, 0.18)
	for attempt in 24:
		var angle := TAU * (float(index) / 3.0 + float(attempt) * 0.381966 + angle_offset)
		var radius := 9.0 + float((attempt * 7 + index * 5) % 16)
		var point := origin + Vector2.from_angle(angle) * radius
		if not Obstacles.blocked(point, 1.25):
			return point
	# Deterministic fallback keeps the objective usable even in a dense landmark
	# cluster; the radius is enlarged until it clears the local obstacle test.
	var fallback_angle := TAU * (float(index) / 3.0 + angle_offset)
	for radius in [28.0, 36.0, 44.0, 52.0]:
		var point: Vector2 = origin + Vector2.from_angle(fallback_angle) * float(radius)
		if not Obstacles.blocked(point, 1.0):
			return point
	return origin + Vector2.from_angle(fallback_angle) * 60.0


func tick_objectives(_delta: float) -> void:
	if terminal or _player == null or _player.dead:
		return
	if (contract_id == "elite_hunt" or bool(spec.get("elite", false))) and not _elite_spawned and _wave.elapsed >= elite_at:
		_spawn_marked_elite()
	_sync_marked_elite_marker()
	if contract_id == "hunt" and not _late_wave_spawned and _wave.elapsed >= duration - 35.0:
		_spawn_hunt_pressure_wave()
	if contract_id == "elite_hunt" and _elite_spawned and not elite_dead and _marked_dead():
		elite_dead = true
		if not _visuals.is_empty():
			_visuals[0].visible = false
	if finale:
		_tick_ledger(_wave.elapsed)
	_tick_unfinished(_wave.elapsed)
	if Input.is_action_just_pressed("interact"):
		interact_with_nearest_site()


## The prompt and the interact action use the same eligible nearest site so the
## player always claims the objective named by the HUD.
func interaction_prompt() -> Dictionary:
	var nearest := _nearest_interactable_site()
	if nearest < 0:
		return {}
	var key := Controls.tag("interact")
	if contract_id in ["seal_breach", "breach"]:
		return {"text": "Close %s  ·  %s" % [_site_label(nearest), key], "color": OBJECTIVE_COLOR}
	return {"text": "Open cursed cache  ·  summons guardians  ·  %s" % key, "color": CACHE_COLOR}


func interact_with_nearest_site() -> int:
	var nearest := _nearest_interactable_site()
	if nearest >= 0:
		_complete_site(nearest)
	return nearest


func _nearest_interactable_site() -> int:
	if terminal or _player == null or _player.dead:
		return -1
	if contract_id not in ["seal_breach", "breach", "cursed_cache"]:
		return -1
	var nearest := -1
	var nearest_distance := 2.6 * 2.6
	for i in _sites.size():
		if _site_complete(i):
			continue
		var distance := _player.pos2.distance_squared_to(_sites[i])
		# Keep the original <= tie behavior: the later site wins an exact tie.
		if distance <= nearest_distance:
			nearest = i
			nearest_distance = distance
	return nearest


func _spawn_hunt_pressure_wave() -> void:
	_late_wave_spawned = true
	var grunts := _main.get_node_or_null("Grunts") as EnemySwarm
	var runners := _main.get_node_or_null("Runners") as EnemySwarm
	var at := _reachable_site(12)
	for i in 8:
		if grunts:
			grunts.spawn(at + Vector2.from_angle(TAU * i / 8.0) * 2.5, _wave.hp_multiplier())
	for i in 2:
		if runners:
			runners.spawn(at + Vector2.from_angle(TAU * i / 2.0 + 0.5) * 4.0, _wave.hp_multiplier())
	var hud := _main.get_node_or_null("Hud")
	if hud:
		hud.call("toast", "The last wave closes in. Hold for extraction.", Color(1.0, 0.68, 0.35))


func _spawn_marked_elite() -> void:
	var target: EnemySwarm
	for swarm in _swarms:
		if not swarm.boss and (swarm.charger or swarm.captor or swarm.raise_interval > 0.0 or swarm.mend_interval > 0.0):
			target = swarm
			if swarm.charger:
				break
	if target == null:
		for swarm in _swarms:
			if not swarm.boss and swarm.spawn_share > 0.0:
				target = swarm
				break
	if target == null:
		return
	var at := _sites[0] if not _sites.is_empty() else _reachable_site(0)
	var pos := at
	if Obstacles.blocked(pos, target.radius):
		pos = EnemySwarm.random_ring_point(_player.pos2, 14.0, 18.0)
	if target.spawn(pos, _wave.hp_multiplier() * 1.15, true):
		_elite_spawned = true
		_marked_swarm = target
		_marked_id = target.ids[target.count - 1]
	if not _sites.is_empty():
		(_visuals[0].get_child(2) as Label3D).text = "ELITE  ·  DEFEAT"
	_sync_marked_elite_marker()


func _sync_marked_elite_marker() -> void:
	if contract_id != "elite_hunt" or not _elite_spawned or _sites.is_empty() or _visuals.is_empty():
		return
	if _marked_swarm != null:
		for i in _marked_swarm.count:
			if _marked_swarm.ids[i] != _marked_id:
				continue
			if _marked_swarm.hp[i] > 0.0:
				var target_at: Vector2 = _marked_swarm.pos[i]
				_sites[0] = target_at
				_visuals[0].position = Vector3(target_at.x, 0.0, target_at.y)
				_visuals[0].visible = true
			else:
				_visuals[0].visible = false
			return
	_visuals[0].visible = false


func _site_complete(index: int) -> bool:
	if contract_id in ["seal_breach", "breach"]:
		return index >= 0 and index < _site_claimed.size() and _site_claimed[index]
	if cache_enabled:
		return cache_claimed
	return false


func _complete_site(index: int) -> void:
	if contract_id in ["seal_breach", "breach"]:
		if index < 0 or index >= _site_claimed.size() or _site_claimed[index]:
			return
		_site_claimed[index] = true
		seals = mini(seals + 1, 3)
		_visuals[index].visible = false
		Sound.play("shrine_done")
		Juice.ring(_sites[index], OBJECTIVE_COLOR, 32, 6.0, 0.5, 0.6)
	elif cache_enabled:
		cache_claimed = true
		_visuals[index].visible = false
		_spawn_cache_guardians(_sites[index])
		Sound.play("chest")
		Juice.ring(_sites[index], CACHE_COLOR, 36, 7.0, 0.6, 0.7)


func _site_label(index: int) -> String:
	return "SEAL %d / 3" % (index + 1)


func markers() -> Array:
	var out: Array = []
	for i in _sites.size():
		if _site_complete(i) or not _visuals[i].visible:
			continue
		var color := CACHE_COLOR if cache_enabled else (ELITE_COLOR if contract_id == "elite_hunt" else OBJECTIVE_COLOR)
		var label := "CACHE" if cache_enabled else ("ELITE" if contract_id == "elite_hunt" else _site_label(i))
		out.append({"at": _sites[i], "color": color, "label": label})
	return out


func objective_text() -> String:
	if finale:
		return "Survive until the guardian arrives at 15:00" if not _bosses.final_arrived else "Defeat the biome guardian"
	match contract_id:
		"seal_breach", "breach":
			if seals >= 3:
				return "All seals closed  ·  survive until extraction"
			if _wave != null and _wave.elapsed >= duration and deadline > 0.0:
				return "Seals: %d / 3  ·  close the rest by %s" % [seals, _format_time(deadline)]
			if _wave != null and _wave.elapsed >= duration:
				return "Seals: %d / 3  ·  close the remaining marked seals" % seals
			return "Seals: %d / 3  ·  close all and survive to %s" % [seals, _format_time(duration)]
		"elite_hunt":
			if elite_dead:
				return "Marked elite defeated  ·  hold to extraction"
			if _elite_spawned:
				return "Defeat the marked elite by 7:00"
			return "Marked elite arrives at 5:00"
		"cursed_cache":
			return "Cursed cache: %s  ·  survive to 6:00" % ("claimed" if cache_claimed else "optional")
		_:
			return "Survive to 5:00  ·  extraction is automatic"


func guidance_text() -> String:
	return CampaignGuidance.contract_action(contract_id, seals, _elite_spawned,
			elite_dead, cache_claimed, _bosses.final_arrived if _bosses else false)


func clock_text(elapsed: float) -> String:
	if finale:
		if _bosses.final_arrived:
			return "DEFEAT THE BIOME GUARDIAN"
		return "BIOME GUARDIAN ARRIVES IN  %s" % _format_time(maxf(900.0 - elapsed, 0.0))
	if contract_id == "elite_hunt" and _elite_spawned and not elite_dead:
		return "ELITE DEADLINE  %s" % _format_time(maxf(deadline - elapsed, 0.0))
	if contract_id in ["seal_breach", "breach"] and seals < 3 and elapsed >= duration and deadline > 0.0:
		return "SEAL DEADLINE  %s" % _format_time(maxf(deadline - elapsed, 0.0))
	return "%s  /  %s" % [_format_time(elapsed), _format_time(duration)]


func _format_time(seconds: float) -> String:
	var whole := maxi(ceili(seconds), 0)
	return "%d:%02d" % [whole / 60, whole % 60]


## Called once at the end of the combat frame, after every damage source and
## contact damage has run. Death wins ties and boss HP is read from its arrays.
func arbitrate_frame(combat_elapsed: float, player_dead: bool, final_dead: bool) -> bool:
	if terminal:
		return true
	if contract_id == "elite_hunt" and _elite_spawned and not elite_dead and not _marked_dead():
		if _wave.elapsed <= deadline:
			pass
		else:
			_finish("failure", combat_elapsed)
			return true
	if player_dead:
		_finish("failure", combat_elapsed)
		return true
	if finale:
		if _bosses.final_arrived and final_dead and combat_elapsed >= 900.0:
			_finish("success", combat_elapsed)
		return terminal
	match contract_id:
		"hunt":
			if combat_elapsed >= duration:
				_finish("success", duration)
		"seal_breach", "breach":
			if deadline > 0.0 and combat_elapsed > deadline:
				_finish("failure", deadline)
			elif combat_elapsed >= duration and seals >= 3:
				_finish("success", combat_elapsed)
		"elite_hunt":
			if deadline > 0.0 and combat_elapsed > deadline:
				_finish("failure", deadline)
			elif combat_elapsed >= duration and elite_dead:
				_finish("success", combat_elapsed)
		"cursed_cache":
			if combat_elapsed >= duration:
				_finish("success", duration)
	return terminal


func _marked_dead() -> bool:
	if _marked_swarm == null or _marked_id < 0:
		return false
	for i in _marked_swarm.count:
		if _marked_swarm.ids[i] == _marked_id:
			return _marked_swarm.hp[i] <= 0.0
	return true


func observe_elite_death(swarm: EnemySwarm, enemy_id: int) -> void:
	if contract_id == "elite_hunt" and not terminal and swarm == _marked_swarm and enemy_id == _marked_id and _marked_dead():
		elite_dead = true
		if not _sites.is_empty():
			_visuals[0].visible = false


func _tick_unfinished(elapsed: float) -> void:
	if _unfinished_spawned:
		return
	for effect in spec.get("effects", []):
		if not effect is Dictionary or String(effect.get("id", "")) != "unfinished":
			continue
		if elapsed < maxf(45.0, duration * 0.5):
			return
		_unfinished_spawned = true
		_spawn_specialist(_reachable_site(14), true)
		var hud := _main.get_node_or_null("Hud")
		if hud:
			hud.call("toast", "UNFINISHED CONTRACT: a named specialist joins the hunt.", ELITE_COLOR)
		return


func _spawn_cache_guardians(at: Vector2) -> void:
	if _cache_guardians_spawned:
		return
	_cache_guardians_spawned = true
	var shields := _main.get_node_or_null("Shieldbearers") as EnemySwarm
	var grunts := _main.get_node_or_null("Grunts") as EnemySwarm
	if shields:
		shields.spawn(at + Vector2(2.8, 0.0), _wave.hp_multiplier(), true)
	if grunts:
		for i in 4:
			grunts.spawn(at + Vector2.from_angle(TAU * i / 4.0) * 3.6, _wave.hp_multiplier())
	var hud := _main.get_node_or_null("Hud")
	if hud:
		hud.call("toast", "The cursed cache wakes its guardian and hungry dead.  +%d G on extraction" % (50 * (int(spec.get("biome_index", 0)) + 1)), CACHE_COLOR)


func _spawn_specialist(at: Vector2, elite: bool) -> void:
	var target: EnemySwarm
	for swarm in _swarms:
		if not swarm.boss and (swarm.charger or swarm.captor or swarm.raise_interval > 0.0 or swarm.mend_interval > 0.0):
			target = swarm
			if swarm.charger:
				break
	if target == null:
		for swarm in _swarms:
			if not swarm.boss and swarm.spawn_share > 0.0:
				target = swarm
				break
	if target:
		var spawn_at := at if not Obstacles.blocked(at, target.radius) else EnemySwarm.random_ring_point(_player.pos2, 14.0, 18.0)
		target.spawn(spawn_at, _wave.hp_multiplier(), elite)


func _tick_ledger(elapsed: float) -> void:
	var clauses: Array = spec.get("clauses", [])
	if clauses.is_empty() or not _bosses.final_arrived or _final_is_dead():
		return
	var boss_elapsed := maxf(elapsed - 900.0, 0.0)
	var clauses_set := {}
	for clause in clauses:
		var id := String(clause.get("id", "")) if clause is Dictionary else String(clause)
		clauses_set[id] = true
	var hud := _main.get_node_or_null("Hud")
	if clauses_set.has("advance_payment") and not _ledger_spawned:
		_ledger_spawned = true
		var collector := _main.get_node_or_null("Collectors") as EnemySwarm
		if collector:
			collector.spawn(_reachable_site(5), _wave.hp_multiplier(), true)
		if hud:
			hud.call("toast", "THE LEDGER COLLECTS: a Debt Collector joins the final boss.", Color(1.0, 0.55, 0.3))
	if clauses_set.has("stolen_arsenal") and not _ledger_half_spawned and _final_below_half():
		_ledger_half_spawned = true
		var guards := _main.get_node_or_null("Shieldbearers") as EnemySwarm
		if guards:
			for i in 2:
				guards.spawn(_reachable_site(6 + i), _wave.hp_multiplier(), true)
		if hud:
			hud.call("toast", "THE ARSENAL RISES: two shieldbearers close around the boss.", Color(0.85, 0.68, 1.0))
	if clauses_set.has("borrowed_battalion") and _ledger_reinforcements < 2:
		var target_time := 45.0 if _ledger_reinforcements == 0 else 90.0
		if boss_elapsed >= target_time:
			_ledger_reinforcements += 1
			var grunts := _main.get_node_or_null("Grunts") as EnemySwarm
			if grunts:
				for i in 5:
					grunts.spawn(_reachable_site(8 + _ledger_reinforcements * 5 + i), _wave.hp_multiplier())
			if hud:
				hud.call("toast", "THE BORROWED BATTALION ANSWERS (%d / 2)." % _ledger_reinforcements, Color(0.65, 0.85, 1.0))


func _final_is_dead() -> bool:
	if _main and bool(_main.get("_campaign_final_boss_dead")):
		return true
	var final_swarm := _main.get_node_or_null("FinalBoss") as EnemySwarm
	return final_swarm != null and final_swarm.count > 0 and final_swarm.alive_count() == 0


func _final_below_half() -> bool:
	var final_swarm := _main.get_node_or_null("FinalBoss") as EnemySwarm
	if final_swarm == null:
		return false
	for i in final_swarm.count:
		if final_swarm.hp[i] > 0.0:
			var boss_state: Dictionary = _bosses._bosses.get(final_swarm.ids[i], {})
			if boss_state.is_empty():
				return false
			return final_swarm.hp[i] <= float(boss_state.get("max_hp", final_swarm.hp[i])) * 0.5
	return false


func _finish(outcome: String, at_time: float) -> void:
	if terminal:
		return
	terminal = true
	result = {
		"campaign_id": spec.get("campaign_id", ""),
		"node_id": spec.get("node_id", ""),
		"attempt_id": spec.get("attempt_id", ""),
		"outcome": outcome,
		"elapsed": maxf(at_time, 0.0),
		"objectives": {"seals": seals, "elite_dead": elite_dead, "cache_claimed": cache_claimed,
			"boss_dead": finale and outcome == "success"},
	}
