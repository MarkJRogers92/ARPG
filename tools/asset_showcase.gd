extends SceneTree
## Developer-only check of the imported GLB scenery (AssetProps) in the real
## game: the live hero, camera, lighting and renderer. Needs a display:
##
##   for r in graveyard frozen ember; do for s in 1_before 1_after 2_start 3_crowd_late \
##       4_behind 5_gallery_a 5_gallery_b; do
##     xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --fixed-fps 60 \
##         -s tools/asset_showcase.gd -- out_dir $r $s; done; done
##
## One shot per run (a fresh game each time, so every pair matches):
##   1_before / 1_after  a spot with a set piece: the realm without the imported
##                       scenery (the old look) and as shipped (same seed and time)
##   2_start             the start of a run, as shipped
##   3_crowd_late        that spot at deep night with a horde flowing around it
##   4_behind            the hero just behind the set piece (see-through window)
##   5_gallery_a / _b    every imported kind of the realm laid out in rows,
##                       printing "LABEL kind x y" (screen positions) for captions
## Spawning, events and hazards are off except in the crowd shot. Save data is
## not touched (MetaProgress.disabled). Prints "PERF ..." render counters.

const GALLERY_COLUMNS := [-13.0, -7.8, -2.6, 2.6, 7.8, 13.0]
const GALLERY_ROWS := [-4.8, 0.2, 5.0]
const GALLERY_HERO := Vector2(0.0, 0.5)

var _out := "user://asset_showcase"
var _realm := "graveyard"
var _shot := "1_after"
var _main: Node
var _frame := 0
var _frame_ms := 0.0
var _labels: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_realm = args[1]
	if args.size() > 2:
		_shot = args[2]
	DirAccess.make_dir_recursive_absolute(_out)
	MetaProgress.disabled = true
	seed(7)
	Realm.current = _realm
	Realm.in_title = false
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	var player: Player = _main.get_node("Player")
	var decor: WorldDecor = _main.get_node("Decor")
	_frame += 1
	player.stats.hp = player.stats.max_hp
	if _frame == 1:
		_setup(player, decor)
	if _shot == "3_crowd_late":
		_main.elapsed = 840.0 # deep night lighting (the boss clock doesn't move)
		if _frame == 2:
			var grunts: EnemySwarm = _main.get_node("Grunts")
			for k in 220:
				grunts.spawn(EnemySwarm.random_ring_point(player.pos2, 6.0, 16.0))
	if _frame >= 45 and _frame < 75:
		_frame_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 / 30.0
	if _frame == 75:
		var camera := (_main.get_node("CameraRig/Camera3D") as Camera3D)
		# Labels are in viewport units; the saved image may be larger (content scaling).
		var image_size := Vector2(root.get_texture().get_size())
		var view_size := root.get_visible_rect().size
		print("VIEW %d %d IMAGE %d %d" % [view_size.x, view_size.y, image_size.x, image_size.y])
		for l: Array in _labels:
			var sp := camera.unproject_position(l[1])
			print("LABEL %s %d %d" % [l[0], sp.x, sp.y])
		print("PERF %s_%s draw_calls=%d objects=%d primitives=%d process_ms=%.2f video_mem_mb=%.1f obstacles=%d" % [_realm, _shot,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), _frame_ms,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Obstacles.circles.size()])
		var img := root.get_texture().get_image()
		img.save_png(_out.path_join("%s_%s.png" % [_realm, _shot]))
		print("saved %s_%s" % [_realm, _shot])
		quit(0)
		return true
	return false


func _setup(player: Player, decor: WorldDecor) -> void:
	var director: WaveDirector = _main.get_node("WaveDirector")
	director.rate_scale = 0.0
	director.elites_per_minute = 0.0
	director.elites_per_minute_growth = 0.0
	(_main.get_node("Events") as EventDirector)._timer = 1.0e9
	(_main.get_node("Hazards") as HazardDirector).kind = ""
	var shipped: Dictionary = Realm.data(_realm)["props"]
	var at := Vector2.ZERO
	if _shot.begins_with("5_"):
		decor.density = {"grass": shipped.get("grass", 0.0)}
		decor.fixed = _gallery(_shot == "5_gallery_b")
		at = GALLERY_HERO
	elif _shot != "2_start":
		var spot := find_spot(_realm)
		at = spot[0] if _shot != "4_behind" else spot[1]
		if _shot == "1_before":
			decor.density = _without_imports(shipped)
	player.global_position = Vector3(at.x, 0.0, at.y)
	(_main.get_node("CameraRig") as Node3D).global_position = player.global_position
	decor._center = Vector2i(1 << 30, 0)
	decor.follow(at)


static func _without_imports(d: Dictionary) -> Dictionary:
	var out := {}
	for kind: String in d:
		if not AssetProps.has(kind):
			out[kind] = d[kind]
	return out


## The realm's imported kinds in rows around the hero (half per shot).
func _gallery(second: bool) -> Array:
	var kinds: Array = AssetProps.KINDS.keys().filter(func(k: String) -> bool:
		return AssetProps.data(k)["realm"] == _realm)
	var per := GALLERY_COLUMNS.size() * GALLERY_ROWS.size()
	kinds = kinds.slice(per, per * 2) if second else kinds.slice(0, per)
	var out := []
	for i in kinds.size():
		var at := Vector2(GALLERY_COLUMNS[i % GALLERY_COLUMNS.size()], GALLERY_ROWS[i / GALLERY_COLUMNS.size()])
		out.append({"kind": kinds[i], "at": at, "yaw": 0.0, "scale": 1.0})
		_labels.append([kinds[i], Vector3(at.x, 0.0, at.y + 1.0)])
	return out


## A spot away from the start where the shipped scatter puts a solid set piece
## with smaller imported props around it: [hero spot, spot just behind it].
static func find_spot(realm: String) -> Array:
	var decor := WorldDecor.new()
	decor.density = Realm.data(realm)["props"]
	var best := []
	for ring in range(3, 9):
		for cy in range(-ring, ring + 1):
			for cx in range(-ring, ring + 1):
				if maxi(absi(cx), absi(cy)) != ring:
					continue
				var xf := _empty()
				var placed := decor._place_assets(Vector2i(cx, cy), xf, _empty(), [], [])
				for p: Array in placed:
					if not p[2]:
						continue
					var kind := _kind_at(xf, p[0])
					if kind == "" or AssetProps.data(kind)["solid"].is_empty():
						continue
					var view: Vector2 = p[0] + Vector2(-3.0, 3.5)
					var smalls := 0
					for ny in range(cy - 1, cy + 2):
						for nx in range(cx - 2, cx + 3):
							for q: Array in decor._place_assets(Vector2i(nx, ny), _empty(), _empty(), [], []):
								if not q[2] and absf(q[0].x - view.x) < 12.0 and q[0].y - view.y > -7.5 and q[0].y - view.y < 5.5:
									smalls += 1
					if best.is_empty() or smalls > best[0]:
						best = [smalls, view, p[0] + Vector2(0.0, -(p[1] + 0.9))]
		if not best.is_empty() and best[0] >= 4:
			break
	decor.free()
	return [best[1], best[2]]


static func _kind_at(xf: Dictionary, at: Vector2) -> String:
	for kind: String in xf:
		for t: Transform3D in xf[kind]:
			if Vector2(t.origin.x, t.origin.z).is_equal_approx(at):
				return kind
	return ""


static func _empty() -> Dictionary:
	var d := {}
	for kind: String in AssetProps.KINDS:
		d[kind] = []
	return d
