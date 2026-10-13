class_name DamageNumbers
extends Node3D
## Floating damage numbers from a fixed pool of labels: when the pool runs
## out, an eligible old label is reused. A bounded spatial/priority budget
## keeps clusters of numbers off silhouettes and warning edges. Values remain
## individual hits, never fabricated sums. Ordinary hits are still sampled.

@export var pool_size := 48
## Show one in this many non-crit numbers.
@export var normal_every := 5

var _labels: Array[Label3D] = []
var _age := PackedFloat32Array()
var _vel := PackedVector3Array()
var _origins := PackedVector2Array()
var _priority := PackedByteArray() # ordinary hit / critical hit / reaction
var _next := 0
var _normal_count := 0

const LIFE := 0.8
const NUMBER_LIMIT := 16
const CALM_NUMBER_LIMIT := 10
const REACTION_LIMIT := 4
const CLUSTER_RADIUS := 1.5
const MIN_READ_TIME := 0.16


func _ready() -> void:
	for i in pool_size:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = false
		label.pixel_size = 0.01
		label.font_size = 40
		label.outline_size = 12
		label.outline_modulate = Color(0, 0, 0, 0.85)
		label.render_priority = 5
		label.visible = false
		add_child(label)
		_labels.append(label)
	_age.resize(pool_size)
	_vel.resize(pool_size)
	_origins.resize(pool_size)
	_priority.resize(pool_size)
	for i in pool_size:
		_age[i] = LIFE


func show_number(at: Vector2, amount: float, crit: bool, color: Color) -> void:
	if not crit:
		_normal_count += 1
		if _normal_count % normal_every != 0:
			return
	# Keep the original three global RNG draws, even when a visual is omitted.
	# Presentation must not shift future gameplay rolls.
	var offset := Vector2(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2))
	var drift := randf_range(-0.6, 0.6)
	var i := _choose_slot(at, 1 if crit else 0)
	if i < 0: return
	_next = (i + 1) % pool_size
	var label := _labels[i]
	label.text = str(roundi(amount))
	label.position = Vector3(at.x + offset.x, 1.8, at.y + offset.y)
	label.modulate = Color(1.0, 0.82, 0.25) if crit else color
	label.font_size = 46 if crit else 30
	label.scale = Vector3.ONE * (1.18 if crit and not Juice.calm else 1.0)
	label.visible = true
	_age[i] = 0.0
	_origins[i] = at
	_priority[i] = 1 if crit else 0
	_vel[i] = Vector3(drift, 3.2 if crit else 2.4, 0.0)


## Reactions have priority over numeric hits, within their own small budget.
func show_text(at: Vector2, text: String, color: Color) -> void:
	var i := _choose_slot(at, 2)
	if i < 0: return
	_next = (i + 1) % pool_size
	var label := _labels[i]
	label.text = text
	label.position = Vector3(at.x, 2.4, at.y)
	label.modulate = color
	label.font_size = 44
	label.scale = Vector3.ONE * (1.18 if not Juice.calm else 1.0)
	label.visible = true
	_age[i] = 0.0
	_origins[i] = at
	_priority[i] = 2
	_vel[i] = Vector3(0.0, 3.0, 0.0)


func _choose_slot(at: Vector2, priority: int) -> int:
	var number_count := 0
	var reaction_count := 0
	var free := -1
	var closest := -1
	var closest_d2 := CLUSTER_RADIUS * CLUSTER_RADIUS
	var oldest := -1
	var oldest_age := -1.0
	for offset in pool_size:
		var i := (_next + offset) % pool_size
		if _age[i] >= LIFE:
			if free < 0: free = i
			continue
		if _priority[i] == 2: reaction_count += 1
		else: number_count += 1
		var d2 := at.distance_squared_to(_origins[i])
		if d2 < CLUSTER_RADIUS * CLUSTER_RADIUS:
			# A small hit never replaces a crit/reaction. Keep rapid repeated
			# numbers readable instead of rewriting them every rendered frame.
			if _priority[i] > priority: return -1
			if _priority[i] == priority and priority < 2 and _age[i] < MIN_READ_TIME: return -1
			if d2 < closest_d2:
				closest = i
				closest_d2 = d2
		if _priority[i] <= priority and (_priority[i] == 2) == (priority == 2) and _age[i] > oldest_age:
			oldest = i
			oldest_age = _age[i]
	var limit := REACTION_LIMIT if priority == 2 else (CALM_NUMBER_LIMIT if Juice.calm else NUMBER_LIMIT)
	if (reaction_count if priority == 2 else number_count) >= limit:
		if closest >= 0 and (_priority[closest] == 2) == (priority == 2): return closest
		return oldest
	if closest >= 0: return closest
	if free >= 0: return free
	# Tiny custom pools still respect priority. A reaction can displace a hit.
	if oldest >= 0: return oldest
	if priority == 2:
		for i in pool_size:
			if _priority[i] < 2: return i
	return -1


func _process(delta: float) -> void:
	# A live Calm toggle applies immediately, including already-visible labels.
	if Juice.calm:
		var numeric: Array[int] = []
		for i in pool_size:
			if _age[i] < LIFE and _priority[i] < 2: numeric.append(i)
		while numeric.size() > CALM_NUMBER_LIMIT:
			var oldest := numeric[0]
			for i: int in numeric:
				if _priority[i] < _priority[oldest] or (_priority[i] == _priority[oldest] and _age[i] > _age[oldest]): oldest = i
			_age[oldest] = LIFE
			_labels[oldest].visible = false
			numeric.erase(oldest)
	for i in pool_size:
		if _age[i] >= LIFE:
			continue
		var label := _labels[i]
		_age[i] += delta
		var t := _age[i] / LIFE
		if t >= 1.0:
			label.visible = false
			continue
		_vel[i].y -= 5.0 * delta
		label.position += _vel[i] * delta
		label.modulate.a = 1.0 - t * t
		# A restrained emphasis; Calm removes size animation entirely.
		if _priority[i] > 0:
			label.scale = Vector3.ONE * lerpf(1.0 if Juice.calm else 1.18, 1.0, minf(t * 4.0, 1.0))
