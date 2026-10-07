extends SceneTree
## Developer-only check of the imported GLB scenery (AssetProps) in the real
## game: the live hero, camera, lighting and renderer. For each realm it saves
## matched pairs (same seed, viewport, hero position and time) without and with
## the new art, so before/after can be compared directly. Needs a display:
##
##   for r in graveyard frozen ember; do for s in 1_before 1_after 2_behind \
##       3_crowd_late 4_scatter_before 4_scatter_after; do
##     xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --fixed-fps 60 \
##         -s tools/asset_showcase.gd -- out_dir $r $s; done; done
##
## One shot per run (a fresh game each time, so every pair matches). Shots:
##   <realm>_1_before / _1_after     the start, with a small cluster of the new props
##   <realm>_2_behind                the hero walking behind the landmark (occlusion)
##   <realm>_3_crowd_late            a horde and late-night lighting among them
##   <realm>_4_scatter_before/_after away from the start, the proposed densities
##                                   (AssetProps.PROPOSED) added to the realm's scatter
## Enemy spawning, events and hazards are off except in the crowd shot. Save data
## is not touched (MetaProgress.disabled).

const CLUSTERS := {
	"graveyard": [
		{"kind": "rune_gravestone", "at": Vector2(-5.0, -2.2), "yaw": 0.15, "scale": 1.0},
		{"kind": "rune_gravestone", "at": Vector2(-3.2, -3.4), "yaw": -0.2, "scale": 0.95},
		{"kind": "rune_gravestone", "at": Vector2(-6.6, -3.8), "yaw": 0.3, "scale": 1.05},
		{"kind": "soul_brazier", "at": Vector2(2.4, -2.6), "yaw": 0.0, "scale": 1.0},
		{"kind": "soul_brazier", "at": Vector2(-1.4, 3.2), "yaw": 0.8, "scale": 1.0},
		{"kind": "mausoleum", "at": Vector2(6.5, -4.5), "yaw": -0.15, "scale": 1.0},
	],
	"frozen": [
		{"kind": "snow_boulder", "at": Vector2(-5.2, -2.0), "yaw": 0.6, "scale": 1.0},
		{"kind": "snow_boulder", "at": Vector2(3.8, 3.0), "yaw": 2.0, "scale": 0.85},
		{"kind": "frosted_pine", "at": Vector2(-3.4, -4.4), "yaw": 0.0, "scale": 1.15},
		{"kind": "frosted_pine", "at": Vector2(-6.8, -4.0), "yaw": 1.3, "scale": 1.0},
		{"kind": "frosted_pine", "at": Vector2(2.2, -3.8), "yaw": 2.6, "scale": 0.95},
		{"kind": "ice_arch", "at": Vector2(6.5, -4.0), "yaw": -0.15, "scale": 1.0},
	],
	"ember": [
		{"kind": "obsidian_outcrop", "at": Vector2(-5.4, -2.4), "yaw": 0.4, "scale": 1.0},
		{"kind": "obsidian_outcrop", "at": Vector2(3.8, 3.2), "yaw": 2.2, "scale": 0.85},
		{"kind": "brimstone_vent", "at": Vector2(-2.6, -3.6), "yaw": 1.0, "scale": 1.0},
		{"kind": "brimstone_vent", "at": Vector2(2.0, -2.8), "yaw": 3.0, "scale": 0.9},
		{"kind": "skull_gateway", "at": Vector2(6.5, -4.6), "yaw": -0.1, "scale": 1.0},
	],
}
## Where the hero stands to be hidden behind each realm's landmark.
const BEHIND := {"graveyard": Vector2(6.5, -7.0), "frozen": Vector2(6.5, -5.2), "ember": Vector2(6.5, -5.8)}
## Away from the start (no clear zone), for the scatter comparison: spots where
## the proposed densities put a landmark and some smaller pieces on screen.
const FAR := {"graveyard": Vector2(28.3, -134.1), "frozen": Vector2(-52.9, 116.2), "ember": Vector2(147.0, 45.2)}

var _out := "user://asset_showcase"
var _realm := "graveyard"
var _shot := "1_after"
var _main: Node
var _frame := 0
var _frame_ms := 0.0


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
	var realm := _realm
	var shot := _shot
	var player: Player = _main.get_node("Player")
	var decor: WorldDecor = _main.get_node("Decor")
	_frame += 1
	player.stats.hp = player.stats.max_hp
	if _frame == 1:
		var director: WaveDirector = _main.get_node("WaveDirector")
		director.rate_scale = 0.0
		director.elites_per_minute = 0.0
		director.elites_per_minute_growth = 0.0
		(_main.get_node("Events") as EventDirector)._timer = 1.0e9
		(_main.get_node("Hazards") as HazardDirector).kind = ""
		if shot != "1_before" and shot != "4_scatter_before":
			decor.fixed = CLUSTERS[realm]
		if shot == "4_scatter_after":
			var d: Dictionary = Realm.data(realm)["props"].duplicate()
			d.merge(AssetProps.PROPOSED[realm])
			decor.density = d
		var at := Vector2.ZERO
		if shot == "2_behind":
			at = BEHIND[realm]
		elif shot.begins_with("4_"):
			at = FAR[realm]
		player.global_position = Vector3(at.x, 0.0, at.y)
		(_main.get_node("CameraRig") as Node3D).global_position = player.global_position
		decor._center = Vector2i(1 << 30, 0)
		decor.rebuild_now()
	if shot == "3_crowd_late":
		_main.elapsed = 840.0 # deep night (the clock reads late, the horde doesn't scale)
		if _frame == 2:
			var grunts: EnemySwarm = _main.get_node("Grunts")
			for k in 160:
				grunts.spawn(EnemySwarm.random_ring_point(Vector2.ZERO, 5.0, 13.0))
	if _frame >= 45 and _frame < 75:
		_frame_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 / 30.0
	if _frame == 75:
		print("PERF %s_%s draw_calls=%d objects=%d primitives=%d process_ms=%.2f video_mem_mb=%.1f" % [realm, shot,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), _frame_ms,
				Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
		var img := root.get_texture().get_image()
		img.save_png(_out.path_join("%s_%s.png" % [realm, shot]))
		print("saved %s_%s" % [realm, shot])
		quit(0)
		return true
	return false
