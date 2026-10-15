extends SceneTree
## Contract tests against the actual Main-derived encounter, never a model-only fixture.
var checks := 0
var failures := 0
var main: Node3D
var swarm: GuardianSwarm
var player: Player
var rewards := 0
var contacts: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func reset_guardian(at := Vector2.ZERO) -> Node3D:
	swarm.despawn_all()
	swarm.step(0.0, player.pos2)
	check(swarm.spawn(at), "fresh guardian spawns")
	swarm.step(0.0, player.pos2)
	return swarm.visuals[swarm.ids[0]].actor

func tick(seconds: float, dt := 1.0 / 60.0) -> void:
	for frame in ceili(seconds / dt): swarm.step(dt, player.pos2)

func _run() -> void:
	seed(871301)
	var original_pending := RunSave.pending
	var original_path := RunSave.path
	var original_meta := MetaProgress.disabled
	main = load("res://scenes/pilot/guardian_encounter.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	swarm = main.get_node("Guardians")
	player = main.get_node("Player")
	check(not main._in_title, "opt-in enters actual play")
	check(main._swarms.has(swarm) and player._swarms.has(swarm) and Elements.swarms.has(swarm), "Main/player/Elements all register canonical swarm")
	check(main._army._type_of.has(swarm), "reward soul type registered")
	check(swarm.capacity == 3 and swarm.spawn_weight(10000) == 0.0, "capped and excluded from normal wave generation")
	check(not main.spawn_guardian() and swarm.count == 1, "encounter admits only one living mid-boss")
	check(not main.can_suspend() and MetaProgress.disabled and RunSave.path != original_path, "encounter isolates persistent saves")
	var first_actor: Node3D = swarm.visuals[swarm.ids[0]].actor
	var body_bounds := skinned_bounds(first_actor)
	var warlord: EnemySwarm = main.get_node("Bosses")
	check(absf(body_bounds.size.y - warlord.multimesh.mesh.get_aabb().size.y) < 0.001, "rendered Idle body matches Ogre Warlord height within 1 mm")
	check(body_bounds.position.y >= -0.002 and body_bounds.position.y < 0.03, "scaled standing feet stay at ground")
	check(is_equal_approx(first_actor.scale.x, GuardianSwarm.BODY_SCALE) and swarm.radius == 1.2, "uniform mesh scale and world collision radius configured")
	check(swarm.max_hp == 900.0 and swarm.xp_value == 75 and swarm.sword_damage == 24.0, "mid-boss tuning")
	check(FileAccess.get_sha256("res://assets/meshy_pilot/guardian_one_hand.glb") == "bc055890c4a13f71564b697aebf244a456d458a0839a9aea1fcf1ad320320923", "exact approved v4 animation bytes")
	swarm.enemy_died.connect(func(_at: Vector2, _xp: int): rewards += 1)
	swarm.sword_contact.connect(func(id: int, swing: int, dealt: float): contacts.append({"id": id, "swing": swing, "dealt": dealt}))
	# Movement remains authoritative in the arrays, including chill and knockback.
	player.position = Vector3.ZERO
	var moving_actor := reset_guardian(Vector2(-6,0))
	var start := swarm.pos[0]
	tick(0.25)
	var normal_distance := start.distance_to(swarm.pos[0])
	check(normal_distance > 0.4 and moving_actor.state == &"Walk", "chase advances rows and Walk together")
	moving_actor = reset_guardian(Vector2(-6,0))
	swarm.chill[0] = 2.0
	swarm.mark_afflicted(0)
	start = swarm.pos[0]
	tick(0.25)
	check(absf(start.distance_to(swarm.pos[0]) / normal_distance - 0.5) < 0.01, "frost halves authoritative chase speed")
	swarm.knockback(Vector2(-7,0),3.0,1.0)
	swarm.step(0.0, player.pos2)
	check(Vector2(moving_actor.position.x,moving_actor.position.z).is_equal_approx(swarm.pos[0]), "knockback and rendered root agree")
	check(moving_actor.position.y == 0.0 and moving_actor.model.position.y == 0.0, "movement and transition do not lift actor/model roots")
	player.position = Vector3(0, 0, 3.0)
	player.stats.hp = player.stats.max_hp
	var actor := reset_guardian()
	var entry: Dictionary = swarm.visuals[swarm.ids[0]]
	entry.cooldown = 0.0
	swarm.step(1.0 / 60.0, player.pos2)
	check(actor.state == &"Attack", "close living target starts sword attack")
	check(actor.get_node("CutTelegraph").visible, "directional warning appears at commitment")
	var start_hp := player.stats.hp
	tick(0.60)
	check(player.stats.hp == start_hp, "wind-up cannot damage")
	check(actor.state_elapsed < 0.40, "readable windup lasts at least 0.65 game seconds")
	tick(0.40)
	check(contacts.size() == 1 and player.stats.hp < start_hp, "actual edge crosses player during active window once")
	var after_cut := player.stats.hp
	tick(0.5)
	check(player.stats.hp == after_cut and contacts.size() == 1, "no repeated active/recovery/contact damage")
	check(not actor.get_node("CutTelegraph").visible, "warning ends after the active cut")
	check(swarm.contact_load(player.pos2, Player.RADIUS) == 0.0, "no inherited contact DPS")
	# A side-step after the facing lock evades the blade entirely.
	actor = reset_guardian()
	entry = swarm.visuals[swarm.ids[0]]
	entry.cooldown = 0.0
	swarm.step(0.01, player.pos2)
	tick(0.2)
	var locked_yaw: float = actor.rotation.y
	player.position = Vector3(4, 0, 3.0)
	var n := contacts.size()
	tick(0.85)
	check(contacts.size() == n and is_equal_approx(actor.rotation.y, locked_yaw), "sidestep evades locked swing without homing")
	# Dash immunity consumes that swing's contact; ending dash cannot apply it again.
	player.position = Vector3(0, 0, 3.0)
	actor = reset_guardian()
	swarm.visuals[swarm.ids[0]].cooldown = 0.0
	player._dash_time = 1.0
	n = contacts.size()
	tick(0.95)
	check(contacts.size() == n + 1 and contacts.back().dealt == 0.0, "Player dash immunity respected")
	player._dash_time = 0.0
	start_hp = player.stats.hp
	tick(0.25)
	check(player.stats.hp == start_hp and contacts.size() == n + 1, "same swing cannot re-hit after dash expires")
	# React after 0.35 seconds of the warning with an ordinary-speed side-step.
	player.position = Vector3(0,0,3.0)
	actor = reset_guardian()
	swarm.visuals[swarm.ids[0]].cooldown = 0.0
	tick(0.35)
	n = contacts.size()
	for frame in 48:
		player.position.x -= player.stats.move_speed / 60.0
		swarm.step(1.0 / 60.0, player.pos2)
	check(contacts.size() == n, "ordinary-speed sidestep after 350 ms reaction clears the committed blade")
	# The enlarged sword does not invent radial/body contact at close or far range.
	for range_z: float in [1.2, 4.0]:
		player.position = Vector3(0,0,range_z)
		actor = reset_guardian()
		actor.rotation.y = GuardianSwarm.ATTACK_AIM_OFFSET
		actor.play_attack()
		var e: Dictionary = swarm.visuals[swarm.ids[0]]
		e.start_yaw = actor.rotation.y; e.attack_yaw = actor.rotation.y; e.cooldown = 10.0
		n = contacts.size()
		tick(1.4)
		check(contacts.size() == n, "outside actual blade at %.1f m does not take invisible radial damage" % range_z)
	player.position = Vector3(0,0,3.0)
	# A real Elements hit interrupts immediately and still applies statuses.
	actor = reset_guardian()
	swarm.visuals[swarm.ids[0]].cooldown = 0.0
	tick(0.75)
	n = contacts.size()
	Elements.hit(swarm, 0, 1.0, Elements.FROST)
	check(actor.state == &"Hit" and not actor.window_active and swarm.chill[0] > 0.0, "incoming frost interrupts and closes window")
	tick(0.35)
	check(contacts.size() == n, "interrupted cut does not hit later")
	check(not actor.get_node("CutTelegraph").visible, "interrupt hides warning")
	# A lethal interruption cancels a cut before contact, and cannot revive.
	actor = reset_guardian()
	swarm.visuals[swarm.ids[0]].cooldown = 0.0
	tick(0.75)
	n = contacts.size()
	swarm.damage(0,9999.0)
	check(actor.state == &"Death" and not actor.play_hit() and actor.play_attack() == -1, "death interrupt is terminal")
	tick(0.5)
	check(contacts.size() == n, "killed attacker cannot finish its cut")
	# Stable IDs survive swap removal, with exactly one Main reward emission.
	player.position = Vector3(10,0,10)
	actor = reset_guardian(Vector2(-4,0))
	check(swarm.spawn(Vector2(0,0)) and swarm.spawn(Vector2(4,0)), "three live actors admitted")
	check(not swarm.spawn(Vector2(8,0)), "fourth live actor denied")
	var first_id := swarm.ids[0]
	var last_id := swarm.ids[2]
	var last_actor: Node3D = swarm.visuals[last_id].actor
	var gems_before: int = main._gems.count
	var drops_before: int = main._loot.drops.size()
	swarm.loot_chance = 1.0
	main._loot._tokens = 1.0 # Earlier kills may have spent the normal drop budget.
	var kills: int = main.kills
	var reward_before := rewards
	check(Elements.hit(swarm,0,9999.0,Elements.NONE), "ordinary damage route kills guardian")
	swarm.damage(0,9999.0)
	check(rewards == reward_before+1 and main.kills == kills+1, "one kill reaches Main rewards exactly once")
	check(actor.state == &"Death" and not actor.window_active, "terminal visual begins on real death")
	check(main._gems.count == gems_before+1 and main._gems._value[gems_before] == swarm.xp_value, "Main drops actual guardian XP gem")
	check(main._loot.drops.size() == drops_before+1, "Main loot route receives guardian kill")
	swarm.loot_chance = 0.5
	swarm.step(0.0, player.pos2)
	check(swarm.count == 2 and swarm.ids[0] == last_id and swarm.visuals[last_id].actor == last_actor and not swarm.visuals.has(first_id), "swap removal preserves survivor ID and presentation")
	var query := swarm.grid.query(Vector2(-4,0),0.1)
	for k in query: check(swarm.ids[swarm.grid.results[k]] != first_id, "dead ID excluded from targeting")
	check(swarm.spawn(Vector2(-4,0)) and swarm.ids[2] != first_id, "respawn gets a fresh stable ID")
	# Existing shock amplification also reaches the canonical guardian HP row.
	Elements.apply_status(swarm,1,Elements.LIGHTNING)
	var hp_before_shock := swarm.hp[1]
	Elements.hit(swarm,1,8.0,Elements.NONE)
	check(is_equal_approx(hp_before_shock - swarm.hp[1],10.0), "shock amplifies incoming damage through existing Elements route")
	# Burn is a separate base-class path and must also retire the visual/reward once.
	var burnt_id := swarm.ids[1]
	var burn_actor: Node3D = swarm.visuals[burnt_id].actor
	swarm.hp[1] = 0.1
	swarm.burn[1] = 2.0
	swarm.burn_dps[1] = 20.0
	swarm.mark_afflicted(1)
	reward_before = rewards
	swarm.step(0.05, player.pos2)
	check(rewards == reward_before+1 and burn_actor.state == &"Death" and not swarm.visuals.has(burnt_id), "burn death retires presentation and awards once")
	# Repeated capped spawn/kill/cleanup with deferred node frees, not stale refs.
	for cycle in 12:
		swarm.despawn_all()
		swarm.step(0.0, player.pos2)
		for k in 3: check(swarm.spawn(Vector2(k*3,0)), "repeated spawn admitted")
		for i in swarm.count: swarm.damage(i,9999.0)
		swarm.step(0.0, player.pos2)
		check(swarm.visuals.is_empty() and swarm.corpses.size() <= 3 and swarm.count == 0, "bounded live/death bookkeeping")
		await process_frame
		check(swarm.get_child_count() <= 4, "deferred free leaves only shadow plus capped corpses")
	tick(1.5)
	await process_frame
	check(swarm.corpses.is_empty() and swarm.get_child_count() == 1, "death duration expires and node count returns to baseline")
	reward_before = rewards
	check(swarm.spawn(Vector2.ZERO), "despawn test actor")
	swarm.despawn_all()
	swarm.step(0, player.pos2)
	await process_frame
	check(rewards == reward_before and swarm.visuals.is_empty() and swarm.corpses.is_empty(), "despawn/cleanup emits no reward")
	main.queue_free()
	await process_frame
	check(Elements.player == null and Elements.swarms.is_empty(), "Main teardown clears combat statics")
	check(RunSave.pending == original_pending and RunSave.path == original_path and MetaProgress.disabled == original_meta, "encounter restores previous save context")
	main = load("res://scenes/pilot/guardian_encounter.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main._swarms.size() == get_nodes_in_group(EnemySwarm.GROUP).size(), "second Main session has no stale swarm registration")
	check(main.get_node("Guardians").visuals.size() == 1, "second session starts one fresh guardian")
	current_scene = main
	main._return_to_normal_title()
	await process_frame
	await process_frame
	main = current_scene
	check(main != null and main.get_script().resource_path == "res://scripts/main.gd" and main._in_title, "Quit to title enters the unchanged normal Main title")
	check(not main.has_node("Guardians") and not main._swarms.any(func(s: EnemySwarm) -> bool: return s is GuardianSwarm), "normal scene has no opt-in guardian cohort")
	main.queue_free()
	await process_frame
	print("GUARDIAN INTEGRATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func skinned_bounds(actor: Node3D) -> AABB:
	var out := AABB()
	var first := true
	actor.skeleton.force_update_all_bone_transforms()
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null: continue
		for surface in mesh.mesh.get_surface_count():
			var a := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var slots: int = joints.size() / vertices.size()
			for k in vertices.size():
				var p := Vector3.ZERO
				for slot in slots:
					var bind := joints[k*slots+slot]
					var bone: int = actor.skeleton.find_bone(str(mesh.skin.get_bind_name(bind)))
					p += (actor.skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind) * vertices[k]) * weights[k*slots+slot]
				p = actor.skeleton.global_transform * p
				if first: out = AABB(p,Vector3.ZERO); first = false
				else: out = out.expand(p)
	return out
