class_name RiftDirector
extends Node3D
## Tears in the night that lead somewhere else for a while.
##
##   The Night Market  a ghostly bazaar outside the realm. Step through its
##                     portal (or a graveyard's ritual door) and the realm
##                     holds still: no spawns, no clock, the horde frozen
##                     where it stands. Spend this run's Soul Shards at four
##                     stalls, then take the exit portal (or the market fades
##                     after 75 s). You come back exactly where you left,
##                     with a moment's grace.
##   The Glitch Rift   touch it and for 30 s the world plays like an old
##                     game: chunky pixels, a small palette. Double XP and
##                     souls while it lasts; survive it for a chest.
##
## Both happen in this scene: the market is just a far-off place with its own
## props and light, so nothing about the run (health, build, army, timers)
## has to be saved and restored. Only what main.gd skips while it's open.

signal announced(text: String, color: Color)

const MARKET_AT := Vector2(-6000.0, 6000.0)
const MARKET_TIME := 75.0
const GLITCH_TIME := 30.0
const FIRST_AT := 240.0
const PORTAL_LIFE := 60.0
const REACH := 2.6
const MARKET_COLOR := Color(0.75, 0.55, 1.0)
const GLITCH_COLOR := Color(0.4, 1.0, 0.8)
const STALLS := [
	{"id": "rare", "name": "Bone Merchant", "offer": "A Rare item", "price": 8},
	{"id": "spirit", "name": "Soul Broker", "offer": "A champion spirit", "price": 6},
	{"id": "elixir", "name": "Apothecary", "offer": "Full heal + blessing", "price": 5},
	{"id": "rerolls", "name": "Fortune Teller", "offer": "+2 rerolls", "price": 5},
]

## The prompt for the HUD ("" for none).
var prompt := ""
var glitch_left := 0.0
var visits := 0

var _main: Node
var _player: Player
var _loot: LootManager
var _army: Army
var _events: EventDirector
var _decor: WorldDecor
var _env: Environment
var _swarms: Array[EnemySwarm] = []
var _spend: Callable
var _add_rerolls: Callable
var _timer := FIRST_AT
var _next_kind := "market"
## Portals in the realm: {"kind", "at", "node", "left"}
var _portals: Array[Dictionary] = []
## While in the market: where we came from and what we changed.
var _market := {}
var _market_node: Node3D
var _bought := {}
var _overlay: CanvasLayer
var _glitch_mat: ShaderMaterial
var _grace := 0.0


func setup(main: Node, player: Player, loot: LootManager, army: Army, events: EventDirector, decor: WorldDecor,
		env: Environment, swarms: Array[EnemySwarm], spend: Callable, add_rerolls: Callable) -> void:
	_main = main
	_player = player
	_loot = loot
	_army = army
	_events = events
	_decor = decor
	_env = env
	_swarms = swarms
	_spend = spend
	_add_rerolls = add_rerolls
	_overlay = CanvasLayer.new()
	_overlay.layer = 9
	add_child(_overlay)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glitch_mat = ShaderMaterial.new()
	_glitch_mat.shader = load("res://shaders/glitch.gdshader")
	rect.material = _glitch_mat
	_overlay.add_child(rect)
	_overlay.visible = false


func in_market() -> bool:
	return not _market.is_empty()


func glitching() -> bool:
	return glitch_left > 0.0


## Whether a rift may open now (not with a boss about, nor close to dawn).
func can_open() -> bool:
	var bosses := _main.get_node("BossDirector") as BossDirector
	if bosses.boss_alive() or bosses.final_alive() or bosses.final_arrived:
		return false
	return bosses.time_to_final() > 120.0


func markers() -> Array:
	var out := []
	for p in _portals:
		out.append({"at": p["at"], "color": MARKET_COLOR if p["kind"] == "market" else GLITCH_COLOR,
				"label": "NIGHT MARKET" if p["kind"] == "market" else "GLITCH"})
	if in_market():
		out.append({"at": MARKET_AT + Vector2(0, 5.0), "color": MARKET_COLOR, "label": "EXIT"})
	return out


## In the realm, every frame (portals and the glitch).
func tick(delta: float) -> void:
	_grace = maxf(_grace - delta, 0.0)
	if _grace <= 0.0 and _player.invulnerable and not _main.won:
		_player.invulnerable = false
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(170.0, 220.0)
		if can_open():
			_open_portal(_next_kind)
			_next_kind = "glitch" if _next_kind == "market" else "market"
	prompt = ""
	var i := _portals.size() - 1
	while i >= 0:
		var p := _portals[i]
		p["left"] -= delta
		(p["node"] as Node3D).rotation.y += delta * 1.5
		if p["left"] <= 0.0:
			(p["node"] as Node3D).queue_free()
			_portals.remove_at(i)
		elif _player.pos2.distance_to(p["at"]) <= REACH:
			if p["kind"] == "glitch":
				(p["node"] as Node3D).queue_free()
				_portals.remove_at(i)
				start_glitch()
			else:
				prompt = "[E]  Step through into the Night Market  ·  the night holds still while you shop" if can_open() \
						else "The market won't open with a boss so near"
				if can_open() and Input.is_action_just_pressed("interact"):
					(p["node"] as Node3D).queue_free()
					_portals.remove_at(i)
					enter_market()
					return
		i -= 1
	if glitch_left > 0.0:
		glitch_left -= delta
		_glitch_mat.set_shader_parameter("time", Time.get_ticks_msec() / 1000.0)
		_glitch_mat.set_shader_parameter("strength", clampf(minf(GLITCH_TIME - glitch_left, glitch_left) * 2.0, 0.0, 1.0))
		if glitch_left <= 0.0:
			_end_glitch()


func _open_portal(kind: String) -> void:
	var at := Vector2.INF
	for attempt in 16:
		var p := _player.pos2 + Vector2.from_angle(randf() * TAU) * randf_range(12.0, 16.0)
		if not Obstacles.blocked(p, 2.0):
			at = p
			break
	if at == Vector2.INF:
		return
	var color := MARKET_COLOR if kind == "market" else GLITCH_COLOR
	var root := Node3D.new()
	root.position = Vector3(at.x, 0.0, at.y)
	add_child(root)
	HazardDirector.make_decal(root, Vector2.ZERO, Color(color, 0.7), 1.0, 3.6)
	var kit := MeshKit.new()
	kit.cylinder(0.9, 0.9, 0.12, MeshKit.at(Vector3(0, 1.4, 0), Vector3(90, 0, 0)), color, 2.5, 16, false, false)
	kit.cylinder(0.75, 0.75, 0.14, MeshKit.at(Vector3(0, 1.4, 0), Vector3(90, 0, 0)), Color(0.05, 0.03, 0.1), 0.0, 16)
	if kind == "glitch":
		kit = MeshKit.new()
		for k in 6:
			kit.box(Vector3.ONE * randf_range(0.3, 0.6), MeshKit.at(Vector3(randf_range(-0.5, 0.5), 1.0 + randf_range(-0.4, 0.6), randf_range(-0.5, 0.5)),
					Vector3(randf() * 90, randf() * 90, 0)), color if k % 2 == 0 else Color(1.0, 0.3, 0.8), 2.0)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit(Models.kit_material())
	root.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.8
	light.omni_range = 6.0
	light.position = Vector3(0, 1.6, 0)
	root.add_child(light)
	_portals.append({"kind": kind, "at": at, "node": root, "left": PORTAL_LIFE})
	Sound.play("shrine_charge", 0.7 if kind == "market" else 1.6, 2.0)
	announced.emit("A Night Market opens nearby..." if kind == "market" else "The world flickers. A Glitch has appeared!", color)


# --- the Night Market --------------------------------------------------------------------

func enter_market() -> void:
	if in_market():
		return
	visits += 1
	_bought = {}
	_market = {"from": _player.pos2, "left": MARKET_TIME, "density": _decor.density.duplicate(),
			"fog": _env.fog_light_color, "fog_d": _env.fog_density, "amb": _env.ambient_light_color,
			"amb_e": _env.ambient_light_energy, "bg": _env.background_color}
	for swarm in _swarms:
		swarm.visible = false
	(_main.get_node("EnemyShots") as EnemyShots).clear()
	_decor.density = {"grass": 3.0}
	_teleport(MARKET_AT)
	_build_market()
	_env.fog_light_color = Color(0.2, 0.1, 0.3)
	_env.fog_density = 0.02
	_env.ambient_light_color = Color(0.6, 0.45, 0.9)
	_env.ambient_light_energy = 1.0
	_env.background_color = Color(0.05, 0.02, 0.08)
	Sound.play("shrine_done", 0.7)
	announced.emit("The Night Market. The night outside holds its breath.", MARKET_COLOR)


## Where stall `k` stands, relative to the market's middle: an arc to the north.
static func stall_at(k: int) -> Vector2:
	return Vector2.from_angle(PI * 1.05 + k * PI * 0.9 / (STALLS.size() - 1)) * 8.0


func _build_market() -> void:
	_market_node = Node3D.new()
	_market_node.position = Vector3(MARKET_AT.x, 0.0, MARKET_AT.y)
	add_child(_market_node)
	for k in STALLS.size():
		var at := stall_at(k)
		var stall := Node3D.new()
		stall.position = Vector3(at.x, 0, at.y)
		_market_node.add_child(stall)
		var merchant := MeshInstance3D.new()
		merchant.mesh = Models.ferryman()
		merchant.scale = Vector3.ONE * 0.8
		merchant.rotation.y = atan2(at.x, at.y)
		stall.add_child(merchant)
		for prop in [["crate_stack", Vector3(1.2, 0, 0.4)], ["lantern_post", Vector3(-1.3, 0, 0.2)]]:
			var mi := MeshInstance3D.new()
			mi.mesh = AssetProps.mesh(prop[0])
			mi.position = prop[1]
			mi.scale = Vector3.ONE * 0.8
			stall.add_child(mi)
		var light := OmniLight3D.new()
		light.light_color = MARKET_COLOR.lerp(Color(1.0, 0.8, 0.5), float(k) / STALLS.size())
		light.light_energy = 2.0
		light.omni_range = 5.0
		light.position = Vector3(0, 2.5, 0.8)
		stall.add_child(light)
		var sign := Label3D.new()
		sign.text = "%s\n%s · %d ◆" % [STALLS[k]["name"], STALLS[k]["offer"], STALLS[k]["price"]]
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.font_size = 40
		sign.outline_size = 10
		sign.pixel_size = 0.01
		sign.modulate = Color(1.0, 0.92, 0.75)
		sign.position = Vector3(0, 3.4, 0)
		stall.add_child(sign)
	# Soul braziers around the square, giving off wisps.
	for k in 8:
		var a := k * TAU / 8.0 + 0.2
		var mi := MeshInstance3D.new()
		mi.mesh = AssetProps.mesh("soul_brazier")
		mi.position = Vector3(cos(a), 0, sin(a)) * 12.5
		_market_node.add_child(mi)
	for prop in [["barrel", Vector3(-4.5, 0, 2.5)], ["offering_bowl", Vector3(4.5, 0, 2.2)], ["tome_pedestal", Vector3(0, 0, -2.0)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = AssetProps.mesh(prop[0])
		mi.position = prop[1]
		_market_node.add_child(mi)
	var exit := MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.cylinder(1.0, 1.0, 0.12, MeshKit.at(Vector3(0, 1.4, 0), Vector3(90, 0, 0)), MARKET_COLOR, 2.5, 16, false, false)
	exit.mesh = kit.commit(Models.kit_material())
	exit.position = Vector3(0, 0, 5.0)
	_market_node.add_child(exit)
	HazardDirector.make_decal(_market_node, Vector2(0, 5.0), Color(MARKET_COLOR, 0.7), 1.0, 3.6)


## While in the market, instead of the realm's frame (main.gd).
func market_tick(delta: float) -> void:
	_market["left"] -= delta
	prompt = ""
	var here := _player.pos2 - MARKET_AT
	if here.distance_to(Vector2(0, 5.0)) <= REACH:
		prompt = "[E]  Return to the night"
		if Input.is_action_just_pressed("interact"):
			leave_market()
			return
	for k in STALLS.size():
		var at := stall_at(k)
		if here.distance_to(at) <= REACH:
			var s: Dictionary = STALLS[k]
			if _bought.has(s["id"]):
				prompt = "%s: \"Come again, traveller.\"" % s["name"]
			else:
				prompt = "[E]  %s  ·  %s for %d Soul Shards (you have %d)" % [s["name"], s["offer"], s["price"], _spend.call(0)]
				if Input.is_action_just_pressed("interact"):
					buy(s["id"])
	if _market["left"] <= 10.0 and int(_market["left"] + delta) != int(_market["left"]):
		announced.emit("The market fades... %d" % ceili(_market["left"]), MARKET_COLOR)
	if _market["left"] <= 0.0:
		leave_market()


## Buys from a stall (once per visit). Returns true if it sold.
func buy(id: String) -> bool:
	if _bought.has(id):
		return false
	var stall: Dictionary = {}
	for s: Dictionary in STALLS:
		if s["id"] == id:
			stall = s
	if stall.is_empty() or not _spend.call(stall["price"]):
		Sound.play("ui_hover")
		return false
	_bought[id] = true
	match id:
		"rare":
			var item := ItemGenerator.generate_with(ItemData.ilvl_for_player_level(_player.stats.level),
					ItemData.Rarity.RARE, ItemData.SLOTS.pick_random())
			_loot.drop(item, _player.pos2 + Vector2(0, 1.5))
		"spirit":
			var types := []
			for t in _swarms.size():
				if not _swarms[t].boss and _swarms[t].spawn_share > 0.0:
					types.append(t)
			_army._raise(types.pick_random() if not types.is_empty() else 0, true, false)
		"elixir":
			_player.heal(_player.stats.max_hp)
			_events.bless_for(EventDirector.BLESSINGS.keys().pick_random(), 60.0)
		"rerolls":
			_add_rerolls.call(2)
	Sound.play("gem", 0.8)
	announced.emit("%s: \"A fine choice.\"" % stall["name"], Color(1.0, 0.85, 0.5))
	return true


func leave_market() -> void:
	if not in_market():
		return
	_decor.density = _market["density"]
	_env.fog_light_color = _market["fog"]
	_env.fog_density = _market["fog_d"]
	_env.ambient_light_color = _market["amb"]
	_env.ambient_light_energy = _market["amb_e"]
	_env.background_color = _market["bg"]
	_market_node.queue_free()
	_market_node = null
	var back: Vector2 = _market["from"]
	_market = {}
	for swarm in _swarms:
		swarm.visible = true
	_teleport(back)
	back = Obstacles.resolve(back, Player.RADIUS)
	_player.global_position = Vector3(back.x, 0, back.y)
	# A moment's grace to see what's around.
	_player.invulnerable = true
	_grace = 1.5
	Sound.play("shrine_done", 1.2)
	announced.emit("Back in the night.", MARKET_COLOR)


func _teleport(to: Vector2) -> void:
	_player.global_position = Vector3(to.x, 0.0, to.y)
	var rig := _main.get_node("CameraRig") as Node3D
	rig.global_position = _player.global_position
	_decor._center = Vector2i(1 << 30, 0)
	_decor.follow(to)
	_army.gather(to)


# --- the Glitch ---------------------------------------------------------------------------

func start_glitch() -> void:
	glitch_left = GLITCH_TIME
	_overlay.visible = true
	Sound.play("overload", 0.5)
	announced.emit("GLITCH!  The world remembers an older game. Double XP and souls for %d s!" % int(GLITCH_TIME), GLITCH_COLOR)


func _end_glitch() -> void:
	glitch_left = 0.0
	_overlay.visible = false
	if _player.dead:
		return
	for k in 2:
		_loot.drop(ItemGenerator.generate(ItemData.ilvl_for_player_level(_player.stats.level), 1.5 + _player.stats.magic_find),
				_player.pos2 + Vector2(k * 1.4 - 0.7, 1.5))
	Sound.play("chest")
	announced.emit("The world steadies. The Glitch leaves a gift.", GLITCH_COLOR)
