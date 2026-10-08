extends SceneTree
## Fixed-frame campaign combat harness. It creates a real disposable campaign,
## reaches the requested route through CampaignController, then waits for the
## combat root's actual frame-arbitrated result and settles it through the same
## controller API. It creates isolated disposable campaign/profile files; no
## existing player profile or campaign saves are read or modified.
##
## godot --headless --path . --fixed-fps 60 -s tools/campaign_combat_bot.gd -- <hunt|breach|elite_hunt|cursed_cache|finale> <graveyard|frozen|ember> <seed> <greedy|tank|random> <max-minutes> [elite] [clauses=a,b] [full]

const PRIORITY := {
	"greedy": ["bolt_count", "bolt_damage", "bolt_rate", "aura", "bolt_pierce", "regen", "max_hp", "legion", "magnet", "move_speed"],
	"tank": ["max_hp", "regen", "move_speed", "bolt_damage", "bolt_rate", "aura", "bolt_count", "bolt_pierce", "magnet"],
}
const CLASS_PRIORITY := {
	"stormcaller": ["lightning", "aura", "orbit", "bolt_count", "bolt_rate", "bolt_damage", "legion", "regen", "max_hp", "move_speed", "magnet"],
}
const CAMPAIGN_TALENT_PRIORITY := ["o1", "o2", "o4", "o3", "o7", "o6", "o5",
	"a1", "a2", "a4", "a3", "a6", "a5", "d1", "d2", "d4", "d6", "d7", "d3", "d5",
	"u1", "u2", "u5", "u3", "u4", "u6", "u7"]
const SENSE_RADIUS := 7.0
const EVENT_SAFE_CHOICE := {"toll": "leave", "ash_map": "gold", "coffins": "leave", "inventory": "leave",
	"quiet_bell": "leave", "loaded_passage": "gold", "unfinished": "leave", "honest_ferryman": "leave"}

var _main: Node
var _player: Player
var _director: ExpeditionDirector
var _swarms: Array[EnemySwarm] = []
var _controller: CampaignController
var _seed := 7
var _contract := "hunt"
var _biome := "graveyard"
var _policy := "greedy"
var _hero_class := "battlemage"
var _max_seconds := 22.0 * 60.0
var _elite := false
var _full_profile := false
var _clauses: Array[String] = []
var _frame := 0
var _next_report := 60.0
var _next_gear := 1.0
var _next_interact := 0.0
var _next_pickup_scan_frame := 0
var _pickup_target := Vector2.INF
var _release_interact := false
var _wall_deadline_msec := 0
var _campaign_path := ""
var _profile_path := ""
var _done := false
var _cleanup_started := false
var _cleanup_wait_frames := 0
var _exit_code := 1
var _result := {}
var _items := 0
var _dash_count := 0
var _observed_final_arrival_at := -1.0
var _observed_initial_final_seals := -1
var _observed_advance_payment_at := -1.0
var _observed_stolen_arsenal_at := -1.0
var _observed_borrowed_reinforcement_times: Array[float] = []
var _observed_reinforcement_count := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _contract = args[0]
	if args.size() > 1: _biome = args[1]
	if args.size() > 2: _seed = int(args[2])
	if args.size() > 3: _policy = args[3]
	if args.size() > 4: _max_seconds = float(args[4]) * 60.0
	for arg in args.slice(5):
		if arg == "elite":
			_elite = true
		elif arg == "full":
			_full_profile = true
		elif arg.begins_with("class="):
			_hero_class = arg.substr(6)
		elif arg.begins_with("clauses="):
			for clause in arg.substr(8).split(",", false):
				_clauses.append(clause)
	if not _biome in Realm.REALMS or not ["greedy", "tank", "random"].has(_policy) or not CampaignCatalog.CONTRACTS.has(_contract):
		printerr("BAD ARGS: contract=%s biome=%s policy=%s" % [_contract, _biome, _policy])
		quit(2)
		return
	seed(_seed)
	_wall_deadline_msec = Time.get_ticks_msec() + int(_max_seconds * 2000.0 + 120000.0)
	_setup_controller_and_spec()


func _setup_controller_and_spec() -> void:
	var unique := "%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_campaign_path = "user://campaign_combat_bot_%s.save" % unique
	_profile_path = "user://campaign_combat_bot_profile_%s.save" % unique
	CampaignSave.path = _campaign_path
	MetaProgress.save_path = _profile_path
	MetaProgress.disabled = false
	MetaProgress.load_save()
	if _full_profile:
		if HeroClass.CLASSES.has(_hero_class):
			MetaProgress.classes[_hero_class] = true
			MetaProgress.hero_class = _hero_class
		# A disposable, deterministic endgame account snapshot. Main later reloads
		# this isolated profile file, while the combat build uses the captured spec.
		MetaProgress.shards = 100000
		for id: String in MetaProgress.UPGRADES:
			MetaProgress.ranks[id] = int(MetaProgress.UPGRADES[id]["max"])
		for id: String in Upgrades.DEFS:
			if Upgrades.DEFS[id].has("unlock"):
				MetaProgress.cards[id] = true
		for id: String in Relics.DEFS:
			MetaProgress.relics[id] = true
		MetaProgress.relic = "iron_heart"
		for kind in ["Grunts", "Runners", "Brutes", "Chargers"]:
			MetaProgress.bestiary[kind] = 5000
	_controller = CampaignController.new()
	_controller.name = "SmokeCampaignController"
	root.add_child(_controller)
	var desired_biome := Realm.ORDER.find(_biome)
	if _contract == "finale":
		print("FIXTURE: preceding route successes use CampaignController settlement fixtures; requested finale combat is natural fixed-60Hz play.")
	var route_seed := _seed
	if _contract != "finale" and desired_biome == 0:
		for offset in 5000:
			var candidate := CampaignCatalog.route(_seed + offset, 0)
			var matching := false
			for id: String in candidate["start"]:
				var node: Dictionary = candidate["nodes"][id]
				if node["contract"] == _contract and (not _elite or node["elite"]):
					matching = true
					break
			if matching:
				route_seed = _seed + offset
				break
	var created := _controller.create(_hero_class, route_seed)
	if not created.get("ok", false):
		_fail("campaign create failed: " + String(created.get("error", "")))
		return
	_allocate_campaign_build()
	if _contract == "finale":
		for biome_step in desired_biome + 1:
			for depth in 3:
				var short_spec := _depart_at_depth(depth + 1, "")
				if short_spec.is_empty(): return
				if not _synthetic_success(short_spec): return
			if biome_step < desired_biome:
				var boss_spec := _depart_at_depth(4, "finale")
				if boss_spec.is_empty(): return
				if not _synthetic_success(boss_spec, true): return
		var final_spec := _depart_at_depth(4, "finale")
		if final_spec.is_empty(): return
		_main = load("res://scenes/main.tscn").instantiate()
		_main.expedition_spec = _controller.state["departure"].duplicate(true)
	else:
		var chosen_id := ""
		for node: Dictionary in _controller.available_routes():
			if node["contract"] == _contract and (not _elite or node["elite"]):
				chosen_id = node["id"]
				break
		if chosen_id == "":
			_fail("no matching route found for requested contract")
			return
		var route := _controller.choose_route(chosen_id)
		if not route.get("ok", false) or not _resolve_event(): return
		var departure := _controller.depart()
		if not departure.get("ok", false):
			_fail("departure failed: " + String(departure.get("error", "")))
			return
		_main = load("res://scenes/main.tscn").instantiate()
		_main.expedition_spec = departure["spec"].duplicate(true)
	_main.expedition_finished.connect(_on_result)
	root.add_child(_main)


func _depart_at_depth(depth: int, required_contract: String) -> Dictionary:
	var candidates := _controller.available_routes()
	var chosen := {}
	for node: Dictionary in candidates:
		if int(node["depth"]) == depth and (required_contract == "" or node["contract"] == required_contract):
			chosen = node
			break
	if chosen.is_empty():
		_fail("campaign route has no node at depth %d (%s)" % [depth, required_contract])
		return {}
	var routed := _controller.choose_route(String(chosen["id"]))
	if not routed.get("ok", false) or not _resolve_event(): return {}
	if depth == 4 and int(_controller.state["biome_index"]) == Realm.ORDER.find(_biome) and not _clauses.is_empty() and _controller.state["clauses"].is_empty():
		for clause_id in _clauses.slice(0, 2):
			var accepted := _controller.accept_clause(clause_id, "weapon", 0)
			if not accepted.get("ok", false):
				_fail("clause acceptance failed: " + String(accepted.get("error", "")))
				return {}
		_claim_tray()
	var response := _controller.depart()
	if not response.get("ok", false):
		_fail("departure failed: " + String(response.get("error", "")))
		return {}
	return response["spec"]


func _resolve_event() -> bool:
	if _controller.state["phase"] != "EVENT_PENDING": return true
	var event: Dictionary = _controller.state["event"]
	var choice := String(EVENT_SAFE_CHOICE.get(String(event.get("id", "")), "leave"))
	var response := _controller.resolve_event(choice)
	if not response.get("ok", false):
		_fail("event resolution failed: " + String(response.get("error", "")))
		return false
	return true


func _synthetic_success(spec: Dictionary, final_boss := false) -> bool:
	var objectives := {"seals": 3, "elite_dead": true, "cache_claimed": true, "boss_dead": final_boss}
	var result := {"campaign_id": spec["campaign_id"], "node_id": spec["node_id"], "attempt_id": spec["attempt_id"],
		"outcome": "success", "elapsed": maxf(float(spec["duration"]), 1200.0 if final_boss else float(spec["duration"])),
		"objectives": objectives, "inventory": spec["starting_loadout"]["inventory"], "loose_shards": 0, "kills_by": {}, "veteran": {}, "report": {"smoke_preprogress": true}}
	var settled := _controller.settle(result)
	if not settled.get("ok", false):
		_fail("synthetic campaign progression failed: " + String(settled.get("error", "")))
		return false
	_controller.acknowledge_result()
	_allocate_campaign_build()
	if not final_boss and _controller.state["wager"].get("status", "") in ["open", "won"]:
		_controller.take_wager()
	_claim_tray()
	if not _controller.state["veteran_candidate"].is_empty():
		_controller.decline_veteran()
	return true


func _claim_tray() -> void:
	for id: String in _controller.state["inventory"]["tray"].duplicate():
		var response := _controller.claim_item(id)
		if not response.get("ok", false):
			_fail("could not claim temporary progression reward: " + String(response.get("error", "")))
			return


func _allocate_campaign_build() -> void:
	# Use the campaign's real town APIs so preprogress scenarios represent a
	# plausible earned build, including its three starting talent points.
	var tree := SkillTree.new(PlayerStats.new())
	tree.restore(_controller.state["talents"])
	while tree.points > 0:
		var allocated := false
		for id: String in CAMPAIGN_TALENT_PRIORITY:
			if not tree.can_allocate(id):
				continue
			var response := _controller.allocate_talent(id)
			if response.get("ok", false):
				tree.restore(_controller.state["talents"])
				allocated = true
				break
		if not allocated:
			break
	if int(_controller.state["talents"]["earned"]) > 3 and _controller.state["specialization"] == "":
		var paths: Array = Specializations.PATHS.get(_hero_class, [])
		if not paths.is_empty(): _controller.choose_specialization(String(paths[0]["id"]))


func _campaign_talent_report() -> Dictionary:
	if _controller == null or not _controller.state.has("talents"):
		return {}
	var talents: Dictionary = _controller.state["talents"]
	var spent := 0
	for id in talents.get("allocated", []):
		if id != SkillData.ROOT:
			spent += SkillData.cost(String(id))
	return {"earned": int(talents.get("earned", 0)), "spent": spent, "unspent": int(talents.get("points", 0))}


func _process(_delta: float) -> bool:
	_frame += 1
	if Input.is_action_pressed("dash"):
		Input.action_release("dash")
	if _done:
		if not _cleanup_started:
			_cleanup_started = true
			if is_instance_valid(_main): _main.queue_free()
			if is_instance_valid(_controller): _controller.queue_free()
			return false
		_cleanup_wait_frames += 1
		if _cleanup_wait_frames < 2: return false
		_cleanup_test_files()
		quit(_exit_code)
		return true
	if Time.get_ticks_msec() >= _wall_deadline_msec:
		_fail("wall-clock watchdog expired")
		_exit_code = 4
		return false
	if is_instance_valid(_main) and _main.elapsed >= _max_seconds:
		_fail("simulation duration limit reached")
		return false
	if _frame < 2: return false
	if _player == null:
		_player = _main.get_node("Player")
		_director = _main.get_node("ExpeditionDirector")
		_swarms.clear()
		for node in get_nodes_in_group(EnemySwarm.GROUP):
			if node is EnemySwarm:
				_swarms.append(node)
		_main.get_node("Loot").item_picked.connect(func(_item: Item, _pickup_result: String) -> void: _items += 1)
	if _release_interact:
		Input.action_release("interact")
		_release_interact = false
	_sample_campaign_telemetry()
	_steer_and_interact()
	if _main._hud._upgrade_root.visible:
		_pick_upgrade()
	if _main.elapsed >= _next_gear:
		_next_gear = _main.elapsed + 1.0
		_player.inventory.equip_upgrades()
	if _main.elapsed >= _next_report:
		_next_report += 60.0
		_report("T")
	return false


func _steer_and_interact() -> void:
	var here := _player.pos2
	var target := _objective_target()
	if target != Vector2.INF:
		if _contract == "elite_hunt" and _director._elite_spawned and not _director.elite_dead:
			_kite_elite(target)
			return
		var to_target := target - here
		if to_target.length() <= 2.35 and _main.elapsed >= _next_interact:
			Input.action_press("interact")
			_release_interact = true
			_next_interact = _main.elapsed + 0.25
		else:
			# Sweep a nearby drop on the way to a marker, but keep the mission
			# objective as the clear priority when it is still far away.
			var pickup := _nearby_pickup_target()
			if to_target.length() > 9.0 and pickup != Vector2.INF and here.distance_to(pickup) < 6.5:
				_steer(_avoid_enemies((pickup - here).normalized()))
				return
			_steer(to_target.normalized())
			return
	if _contract == "finale" and _handle_finale_combat():
		return
	if _handle_midboss_combat():
		return
	var pickup_target := _nearby_pickup_target()
	if pickup_target != Vector2.INF:
		_steer(_avoid_enemies((pickup_target - here).normalized()))
		return
	var away := Vector2.ZERO
	var crowd := 0
	for swarm: EnemySwarm in _swarms:
		var n := swarm.grid.query(here, SENSE_RADIUS)
		var found := swarm.grid.results
		for k in n:
			var d := here - swarm.pos[found[k]]
			var dist := maxf(d.length(), 0.4)
			away += d / (dist * dist)
			crowd += 1
	var heading := away.normalized() if crowd > 0 else Vector2.from_angle(_main.elapsed * 0.45)
	if crowd > 0:
		heading = (heading + heading.rotated(PI * 0.5) * 0.7).normalized()
	_steer(heading)


func _kite_elite(elite_at: Vector2) -> void:
	var here := _player.pos2
	var radial := here - elite_at
	var distance := radial.length()
	if distance < 0.01:
		radial = Vector2.RIGHT
		distance = 0.01
	var outward := radial / distance
	var heading: Vector2
	if distance < 5.8:
		heading = outward
	elif distance > 8.5:
		heading = (elite_at + outward * 7.0 - here).normalized()
	else:
		var tangent := Vector2(-outward.y, outward.x)
		heading = (tangent + outward * clampf((distance - 7.0) * 0.45, -0.45, 0.45)).normalized()
	_steer(_avoid_enemies(heading))


func _handle_finale_combat() -> bool:
	if not _main._bosses.final_arrived or _main._final.alive_count() <= 0:
		return false
	var boss_index := -1
	for i in _main._final.count:
		if _main._final.hp[i] > 0.0:
			boss_index = i
			break
	if boss_index < 0:
		return false
	var combat_target: Vector2 = _main._final.pos[boss_index]
	var mechanics: FinalMechanics = _main._final_mech
	if Realm.current == "graveyard" and mechanics._warded:
		var wards: EnemySwarm = _main.get_node("Phylacteries") as EnemySwarm
		var ward_index := wards.nearest(_player.pos2, 100000.0)
		if ward_index >= 0:
			combat_target = wards.pos[ward_index]
	elif Realm.current == "ember" and not mechanics._seals.is_empty():
		var nearest := 0
		var best_distance := INF
		for i in mechanics._seals.size():
			var seal_at: Vector2 = mechanics._seals[i]["at"]
			var distance := _player.pos2.distance_squared_to(seal_at)
			if distance < best_distance:
				best_distance = distance
				nearest = i
		var seal_at: Vector2 = mechanics._seals[nearest]["at"]
		# A meteor snapshots the hero's position when its warning appears and
		# breaks a seal if that point is within 4 m of the seal. Hold close to a
		# chosen seal until the meteor is fixed, then leave its blast radius while
		# its 1.5-second windup runs.
		for meteor: Dictionary in mechanics._meteors:
			var impact_at: Vector2 = meteor["at"]
			if impact_at.distance_to(seal_at) > FinalMechanics.METEOR_RADIUS + FinalMechanics.SEAL_RADIUS:
				continue
			if float(meteor.get("t", 0.0)) >= FinalMechanics.METEOR_WINDUP:
				continue
			var escape := _player.pos2 - impact_at
			if escape.length_squared() < 0.01:
				escape = _player.pos2 - seal_at
			if escape.length_squared() < 0.01:
				escape = _player.pos2 - _main._final.pos[boss_index]
			if escape.length_squared() < 0.01:
				escape = Vector2.RIGHT
			_steer(_avoid_enemies(escape.normalized()))
			return true
		var to_seal := seal_at - _player.pos2
		if to_seal.length() > 2.2:
			_steer(to_seal.normalized())
		else:
			_steer(Vector2.ZERO)
		return true
	var offset := _player.pos2 - combat_target
	var distance := offset.length()
	var outward := offset.normalized() if distance > 0.01 else Vector2.RIGHT
	var heading: Vector2
	if distance < 5.5:
		heading = outward
	elif distance > 8.0:
		heading = (combat_target + outward * 6.8 - _player.pos2).normalized()
	else:
		var tangent := Vector2(-outward.y, outward.x)
		heading = (tangent + outward * clampf((distance - 6.8) * 0.5, -0.5, 0.5)).normalized()
	_steer(_avoid_enemies(heading))
	return true


func _handle_midboss_combat() -> bool:
	var boss_swarm: EnemySwarm = _main._bosses._swarm
	if boss_swarm == null or boss_swarm.alive_count() == 0:
		return false
	var target_index := boss_swarm.nearest(_player.pos2, 100000.0)
	if target_index < 0:
		return false
	var target: Vector2 = boss_swarm.pos[target_index]
	var offset := _player.pos2 - target
	var distance := offset.length()
	var outward := offset.normalized() if distance > 0.01 else Vector2.RIGHT
	var heading: Vector2
	if distance < 7.5:
		heading = outward
	elif distance > 11.5:
		heading = (target + outward * 9.5 - _player.pos2).normalized()
	else:
		var tangent := Vector2(-outward.y, outward.x)
		heading = (tangent + outward * clampf((distance - 9.5) * 0.45, -0.5, 0.5)).normalized()
	_steer(_avoid_enemies(heading))
	return true


func _avoid_enemies(heading: Vector2) -> Vector2:
	var away := Vector2.ZERO
	var here := _player.pos2
	for swarm: EnemySwarm in _swarms:
		var n := swarm.grid.query(here, SENSE_RADIUS)
		var found := swarm.grid.results
		for k in n:
			var d := here - swarm.pos[found[k]]
			var distance := maxf(d.length(), 0.4)
			away += d / (distance * distance)
	if away.length_squared() > 0.0001:
		return (heading + away.normalized() * 0.7).normalized()
	return heading


func _nearby_pickup_target() -> Vector2:
	if _frame < _next_pickup_scan_frame:
		return _pickup_target
	_next_pickup_scan_frame = _frame + 12
	_pickup_target = Vector2.INF
	var here := _player.pos2
	var best_distance_sq := 42.0 * 42.0
	var loot := _main.get_node_or_null("Loot") as LootManager
	if loot:
		for drop: LootDrop in loot.drops:
			var distance_sq := here.distance_squared_to(drop.pos2)
			if distance_sq < best_distance_sq:
				best_distance_sq = distance_sq
				_pickup_target = drop.pos2
	# Loot is the scarce reward; otherwise gather nearby XP, which improves the
	# real build and increases the chance of surviving an elite encounter.
	if _pickup_target != Vector2.INF:
		return _pickup_target
	var gems := _main._gems as GemSwarm
	if gems:
		best_distance_sq = 20.0 * 20.0
		for i in gems.count:
			var distance_sq := here.distance_squared_to(gems._pos[i])
			if distance_sq < best_distance_sq:
				best_distance_sq = distance_sq
				_pickup_target = gems._pos[i]
	return _pickup_target


func _objective_target() -> Vector2:
	if _director == null or _director.terminal: return Vector2.INF
	if _contract in ["breach", "cursed_cache"]:
		for i in _director._sites.size():
			if not _director._site_complete(i): return _director._sites[i]
	if _contract == "elite_hunt" and _director._elite_spawned and not _director.elite_dead and _director._marked_swarm:
		for i in _director._marked_swarm.count:
			if _director._marked_swarm.ids[i] == _director._marked_id and _director._marked_swarm.hp[i] > 0.0:
				return _director._marked_swarm.pos[i]
	return Vector2.INF


func _steer(heading: Vector2) -> void:
	heading = _avoid_obstacles(heading.normalized())
	Input.action_press("move_left", maxf(-heading.x, 0.0))
	Input.action_press("move_right", maxf(heading.x, 0.0))
	Input.action_press("move_up", maxf(-heading.y, 0.0))
	Input.action_press("move_down", maxf(heading.y, 0.0))
	if _player != null and _player.dash_cooldown_fraction() <= 0.0 and not _player.is_dashing() and (_telegraph_threatens_player() or _crowded_danger()):
		Input.action_press("dash")
		_dash_count += 1


func _avoid_obstacles(heading: Vector2) -> Vector2:
	if heading.length_squared() < 0.001:
		return Vector2.ZERO
	var adjusted := heading
	var here := _player.pos2
	for obstacle: Array in Obstacles.circles:
		var offset: Vector2 = obstacle[0] - here
		var distance := offset.length()
		var clearance: float = float(obstacle[1]) + Player.RADIUS + 3.0
		if distance >= clearance or distance < 0.01 or adjusted.dot(offset / distance) < -0.25:
			continue
		var toward := offset / distance
		var tangent := Vector2(-toward.y, toward.x)
		if adjusted.dot(-tangent) > adjusted.dot(tangent):
			tangent = -tangent
		var strength := clampf((clearance - distance) / 3.0, 0.0, 0.9)
		adjusted = (adjusted * (1.0 - strength) + tangent * strength + -toward * strength * 0.3).normalized()
	return adjusted


func _telegraph_threatens_player() -> bool:
	var here := _player.pos2
	var boss_director: BossDirector = _main._bosses
	for slam: Dictionary in boss_director._slams:
		var remaining := boss_director.slam_windup - float(slam.get("t", 0.0))
		if remaining <= 0.38 and remaining > 0.0 and here.distance_to(slam["at"]) <= boss_director.slam_radius + Player.RADIUS + 1.0:
			return true
	var mechanics: FinalMechanics = _main._final_mech
	for line: Dictionary in mechanics._lines:
		var remaining := FinalMechanics.FRACTURE_WINDUP - float(line.get("t", 0.0))
		if remaining <= 0.38 and remaining > 0.0:
			var rel: Vector2 = here - line["from"]
			var along := rel.dot(line["dir"])
			var across := absf(rel.dot((line["dir"] as Vector2).orthogonal()))
			if along > 0.0 and along < FinalMechanics.FRACTURE_LENGTH and across < FinalMechanics.FRACTURE_WIDTH + Player.RADIUS + 0.3:
				return true
	for meteor: Dictionary in mechanics._meteors:
		var remaining := FinalMechanics.METEOR_WINDUP - float(meteor.get("t", 0.0))
		if remaining <= 0.32 and remaining > 0.0 and here.distance_to(meteor["at"]) <= FinalMechanics.METEOR_RADIUS + Player.RADIUS + 0.5:
			return true
	var mid_mechanics: MidMechanics = _main._mid_mech
	for wave: Dictionary in mid_mechanics._waves:
		var elapsed := float(wave.get("t", -1.0))
		var radius := maxf(MidMechanics.QUAKE_SPEED * elapsed + 0.5, 0.0)
		var distance := here.distance_to(wave["at"])
		var seconds_to_contact := 1.0 + (distance - 0.5) / MidMechanics.QUAKE_SPEED if elapsed < 0.0 else (distance - radius) / MidMechanics.QUAKE_SPEED
		if seconds_to_contact >= 0.0 and seconds_to_contact <= 0.25 and distance < MidMechanics.QUAKE_REACH:
			return true
	return false


func _crowded_danger() -> bool:
	var nearby := 0
	var here := _player.pos2
	for swarm: EnemySwarm in _swarms:
		var n := swarm.grid.query(here, 2.4)
		nearby += n
		if nearby >= 3:
			return true
	return nearby >= 2 and _player.stats.hp / maxf(_player.stats.max_hp, 1.0) < 0.65


func _sample_campaign_telemetry() -> void:
	var elapsed := float(_main._director.elapsed)
	if _main._bosses.final_arrived and _observed_final_arrival_at < 0.0:
		_observed_final_arrival_at = elapsed
		_observed_initial_final_seals = _main._final_mech.seals_left()
	if _director._ledger_spawned and _observed_advance_payment_at < 0.0:
		_observed_advance_payment_at = elapsed
	if _director._ledger_half_spawned and _observed_stolen_arsenal_at < 0.0:
		_observed_stolen_arsenal_at = elapsed
	if _director._ledger_reinforcements > _observed_reinforcement_count:
		for _i in range(_director._ledger_reinforcements - _observed_reinforcement_count):
			_observed_borrowed_reinforcement_times.append(elapsed)
		_observed_reinforcement_count = _director._ledger_reinforcements


func _pick_upgrade() -> void:
	var hud: Hud = _main._hud
	var offered: Array[String] = hud._upgrade_ids
	if offered.is_empty(): return
	var priorities: Array = CLASS_PRIORITY.get(_hero_class, PRIORITY[_policy])
	var best := 999
	var choice := 0
	for i in offered.size():
		var rank: int = priorities.find(offered[i])
		if rank >= 0 and rank < best:
			best = rank
			choice = i
	hud._choose(choice)


func _on_result(result: Dictionary) -> void:
	_result = result.duplicate(true)
	_result["report"]["campaign_talents"] = _campaign_talent_report()
	var loot := _main.get_node_or_null("Loot") as LootManager
	_result["report"]["loot_on_ground"] = loot.drops.size() if loot else -1
	var final_hp := -1.0
	var boss_dead := false
	if _main._bosses.final_arrived:
		final_hp = 0.0
		for i in _main._final.count:
			final_hp += maxf(_main._final.hp[i], 0.0)
		boss_dead = _main._final.alive_count() == 0
	_result["report"]["final_hp_remaining"] = final_hp
	_result["report"]["final_boss_dead"] = boss_dead
	_result["report"]["last_damage_cause"] = _player.last_cause
	_result["report"]["damage_taken_by"] = _player.damage_taken_by.duplicate(true)
	_result["report"]["dashes_used"] = _dash_count
	_result["report"]["final_boss_arrived"] = _main._bosses.final_arrived
	_result["report"]["observed_final_spawn_time"] = _observed_final_arrival_at
	var seals_remaining: int = _main._final_mech.seals_left() if _observed_initial_final_seals >= 0 else -1
	_result["report"]["final_seals_initial"] = _observed_initial_final_seals
	_result["report"]["final_seals_remaining"] = seals_remaining
	_result["report"]["final_seals_broken"] = maxi(_observed_initial_final_seals - seals_remaining, 0) if _observed_initial_final_seals >= 0 else -1
	_result["report"]["ledger_spawned"] = _director._ledger_spawned
	_result["report"]["ledger_spawned_observed_at"] = _observed_advance_payment_at
	_result["report"]["ledger_half_spawned"] = _director._ledger_half_spawned
	_result["report"]["ledger_half_spawned_observed_at"] = _observed_stolen_arsenal_at
	_result["report"]["ledger_reinforcements"] = _director._ledger_reinforcements
	_result["report"]["ledger_reinforcement_observed_times"] = _observed_borrowed_reinforcement_times.duplicate()
	var settled := _controller.settle(_result)
	_result["settlement_ok"] = settled.get("ok", false)
	_result["settlement_error"] = settled.get("error", "")
	_result["settlement"] = settled.get("result", {})
	_done = true
	_exit_code = 0 if _result["settlement_ok"] and String(_result.get("outcome", "")) == "success" else 1
	print("RESULT %s" % JSON.stringify(_result))


func _report(tag: String) -> void:
	var boss_hp := -1.0
	if _main._final.count > 0:
		for i in _main._final.count:
			if _main._final.hp[i] > 0.0:
				boss_hp = _main._final.hp[i]
				break
	print("%s biome=%s contract=%s seed=%d t=%.1f level=%d hp=%.0f/%.0f kills=%d loot=%d final_hp=%.0f elite_dead=%s seals=%d cache=%s" % [
		tag, _biome, _contract, _seed, _main.elapsed, _player.stats.level, _player.stats.hp, _player.stats.max_hp,
		_main.kills, _items, boss_hp, str(_director.elite_dead), _director.seals, str(_director.cache_claimed)])


func _fail(message: String) -> void:
	printerr("CAMPAIGN BOT FAILED: " + message)
	_done = true
	var report := {"failure": message}
	report["campaign_talents"] = _campaign_talent_report()
	if is_instance_valid(_main):
		report["elapsed"] = _main.elapsed
		report["final_boss_arrived"] = _main._bosses.final_arrived
		report["final_hp_remaining"] = -1.0
		if _main._bosses.final_arrived:
			report["final_hp_remaining"] = 0.0
			for i in _main._final.count:
				report["final_hp_remaining"] += maxf(_main._final.hp[i], 0.0)
	if _player != null and is_instance_valid(_player):
		report["last_damage_cause"] = _player.last_cause
		report["damage_taken_by"] = _player.damage_taken_by.duplicate(true)
	_result = {"outcome": "failed", "settlement_ok": false, "report": report}
	_exit_code = 1
	print("RESULT %s" % JSON.stringify(_result))


func _cleanup_test_files() -> void:
	for path in [_campaign_path, _campaign_path + ".bak", _campaign_path + ".previous", _campaign_path + ".rollback", _profile_path, _profile_path + ".bak", _profile_path + ".rollback"]:
		var absolute := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path): DirAccess.remove_absolute(absolute)
