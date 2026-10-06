extends SceneTree
## Simulation-cost benchmark for EnemySwarm. Excludes rendering/GPU time; it
## measures the GDScript update (hash rebuild, separation, movement, buffer
## upload) for N enemies converging on a target.
##
##   godot --headless --path . -s tools/bench_swarm.gd
##   godot --headless --path . -s tools/bench_swarm.gd -- 20000   # custom count

const WARMUP_FRAMES := 600  # let the crowd settle into its steady state
const MEASURE_FRAMES := 120
const DELTA := 1.0 / 60.0


func _process(_delta: float) -> bool:
	# Run from the first frame, not _initialize(), so added nodes have had _ready.
	var counts: Array[int] = [1000, 2000, 4000, 8000, 16000]
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		counts = [int(args[0])]

	print("%8s  %10s  %12s  %s" % ["enemies", "ms/frame", "us/enemy", "(60 fps budget is 16.7 ms)"])
	for n in counts:
		var ms := _bench(n)
		print("%8d  %10.2f  %12.2f" % [n, ms, ms * 1000.0 / n])
	return true # quit


func _bench(n: int) -> float:
	var swarm := EnemySwarm.new()
	swarm.capacity = n
	swarm.recycle_distance = 1.0e9
	root.add_child(swarm)

	# Scatter them over a disc sized so the crowd is dense but not absurd.
	var spread := sqrt(float(n)) * 0.9
	for i in n:
		swarm.spawn(Vector2.from_angle(randf() * TAU) * sqrt(randf()) * spread)

	var target := Vector2.ZERO
	for i in WARMUP_FRAMES:
		swarm.step(DELTA, target)
	var start := Time.get_ticks_usec()
	for i in MEASURE_FRAMES:
		swarm.step(DELTA, target)
	var ms := (Time.get_ticks_usec() - start) / 1000.0 / MEASURE_FRAMES

	root.remove_child(swarm)
	swarm.free()
	return ms
