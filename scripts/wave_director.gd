class_name WaveDirector
extends Node
## Decides how fast enemies spawn and which type. The overall rate and enemy HP
## ramp up with time, and each enemy type declares when it appears and how
## common it is (the "Spawning" exports on its EnemySwarm), so a new type needs
## no changes here. Tune the exports to change the difficulty curve.
##
## Two authored layers sit on top of the raw curve (see MissionRhythm):
##  - a mission rhythm of opening / surge / reward / finale phases, keyed by the
##    fraction of the real mission duration that has elapsed, and
##  - danger/population budgets that bound how many ranged, charger and large
##    enemies (and how many enemies overall) the director keeps alive.
## The budgets count every living normal actor, including ones spawned by
## objectives and events; the director simply never spends past its remaining
## cap, and still spawns fodder when the dangerous roles are full. It never
## removes actors and never blocks scripted/event spawns.
##
## Emits `phase_changed` once per transition. The reward phase's payload carries
## `reward_opportunity: true` exactly once per mission; the primary session
## listens for it and schedules its own event.

## Fired once when the mission rhythm enters a new phase. The payload is the
## phase table entry (id, label, rate_mult, danger_mult, bias, ...). On the
## reward phase `reward_opportunity` is true exactly once per mission.
signal phase_changed(phase: Dictionary)

## Population and danger ceilings. "Total" bounds every living normal actor the
## director accounts for; "danger" bounds the weighted sum of the dangerous
## roles. Campaign missions are deliberately much tighter than a Classic night.
const CLASSIC_TOTAL_CAP := 700
const CLASSIC_DANGER_CAP := 70
const CAMPAIGN_TOTAL_CAP := 240
const CAMPAIGN_DANGER_CAP := 24

## Normal-actor roles. FODDER is any ordinary melee enemy and costs no danger.
## EXCLUDED marks swarms the budget ignores entirely (bosses and event-only
## swarms with zero spawn weight, e.g. Debt Collectors, Phylacteries, Goblins).
const FODDER := "fodder"
const EXCLUDED := ""
const DANGER_RANGED := "ranged"
const DANGER_CHARGER := "charger"
const DANGER_LARGE := "large"
## A normal swarm this wide (or one of these models) reads as "large".
const LARGE_RADIUS := 0.7
const LARGE_MODELS := ["brute", "colossus", "tyrant"]
## Weighted danger cost per dangerous actor.
const DANGER_COST := {"ranged": 2, "charger": 2, "large": 3}

## Enemies per second at t=0.
@export var base_rate := 1.2
## Extra enemies per second, gained every second.
@export var rate_growth := 0.04
## Extra enemies per second, gained every second squared: the late-game ramp.
@export var rate_acceleration := 0.0003
@export var max_spawn_per_frame := 60
## Enemy HP multiplier grows by 1.0 every this many seconds...
@export var hp_growth_seconds := 600.0
## ...plus (time / this) squared, so late enemies keep outscaling a maxed build.
## 0 turns the squared term off.
@export var hp_squared_seconds := 330.0
## The realm's difficulty: multiplies enemy HP and the spawn rate.
@export var hp_scale := 1.0
@export var rate_scale := 1.0
## Elites (see EnemySwarm) start appearing at this game time...
@export var elite_start_time := 50.0
## ...at this many per minute, growing by `elites_per_minute_growth` every
## minute up to `elites_per_minute_max`. A rate, not a share of spawns, so the
## huge late-game spawn rate doesn't flood the field (and the ground) with them.
@export var elites_per_minute := 1.5
@export var elites_per_minute_growth := 0.4
@export var elites_per_minute_max := 5.0

## Game time in seconds, counted from the first tick.
var elapsed := 0.0

## Pressure: the night pushes back against a hero who's walking through it.
## While the horde is being wiped out faster than it can gather and the hero
## is barely scratched, pressure climbs (more enemy health, and somewhat more
## enemies: the spawn rate rises with its square root, at most 1.6x); when
## the hero is hurting it eases off. 1 = the plain curve.
var pressure := 1.0
## How fast pressure builds, and how high it may go: the cap starts at 1 at
## `pressure_start` and grows by `pressure_ramp` a minute (Ascension makes it
## grow faster), up to `pressure_max`. Early on there's none: a hero is
## untouched then just because the horde is thin.
@export var pressure_rate := 0.03
@export var pressure_ramp := 2.0
@export var pressure_max := 20.0
@export var pressure_start := 300.0

var _swarms: Array[EnemySwarm] = []
var _weights: Array[float] = []
## Reused per-pick candidate buffers (avoids allocating inside the spawn loop).
var _scratch_swarms: Array[EnemySwarm] = []
var _scratch_weights: Array[float] = []
var _accum := 0.0
var _elite_accum := 0.0
## Campaign missions keep the real elapsed clock above, while enemy age is a
## separately tuned, capped input to the wave and HP curves.
var expedition_profile := false
var _profile_age_rate := 1.0
var _profile_age_cap := 900.0

## The authored rhythm and the transition bookkeeping that makes `phase_changed`
## fire once per phase (and the reward opportunity once per mission).
var _rhythm: MissionRhythm
var _phase_id := ""
var _reward_announced := false


func configure_expedition(profile: Dictionary) -> void:
	expedition_profile = true
	_profile_age_rate = maxf(float(profile.get("age_rate", 1.0)), 0.01)
	_profile_age_cap = maxf(float(profile.get("growth_cap", 900.0)), 1.0)
	base_rate = 0.48
	rate_growth = 0.0045
	rate_acceleration = 0.000004
	hp_growth_seconds = 600.0
	hp_squared_seconds = 330.0
	hp_scale = float(profile.get("hp_scale", 1.0))
	rate_scale = float(profile.get("spawn_rate", 1.0))
	pressure = 1.0
	pressure_start = INF
	elite_start_time = 45.0
	elites_per_minute = 1.0
	elites_per_minute_growth = 0.12
	elites_per_minute_max = 2.0
	# An expedition profile may name its duration and contract; when it does the
	# rhythm is authored for that length. Absent them the director keeps whatever
	# rhythm it already had (Classic 900 s by default).
	var rhythm_duration := float(profile.get("duration", 0.0))
	if rhythm_duration > 0.0:
		configure_rhythm(rhythm_duration, String(profile.get("contract_id", "hunt")))
	# An explicit re-configure re-arms the transition bookkeeping even when the
	# profile carries no duration (the caller may configure the rhythm next).
	_phase_id = ""
	_reward_announced = false


## Authors the mission rhythm. Called by the primary session (and by
## `configure_expedition` when the profile carries a duration). Clears the
## phase transition bookkeeping so the next tick re-locks cleanly.
## `duration` is real seconds; `contract_id` picks the surge role.
func configure_rhythm(duration: float, contract_id: String = "hunt") -> void:
	_ensure_rhythm()
	_rhythm.setup(duration, contract_id)
	_phase_id = ""
	_reward_announced = false


## Restores the authoritative clock after a resume without replaying a stale
## phase transition or re-offering the reward. The primary session owns the
## scheduled-event side and passes `reward_already_settled` from its own saved
## state so a resumed mission never repeats the reward opportunity.
func note_resumed(restored_elapsed: float, reward_already_settled := true) -> void:
	elapsed = maxf(restored_elapsed, 0.0)
	_ensure_rhythm()
	_phase_id = _rhythm.phase_id_at(elapsed)
	_reward_announced = reward_already_settled


## The phase the rhythm is in right now.
func current_phase() -> Dictionary:
	_ensure_rhythm()
	return _rhythm.phase_at(elapsed)


## The id of the phase the rhythm is in right now.
func current_phase_id() -> String:
	_ensure_rhythm()
	return _rhythm.phase_id_at(elapsed)


func profile_age() -> float:
	return minf(elapsed * _profile_age_rate, _profile_age_cap) if expedition_profile else elapsed


func setup(swarms: Array[EnemySwarm]) -> void:
	_swarms = swarms
	_weights.resize(swarms.size())


func tick(delta: float, center: Vector2) -> void:
	elapsed += delta
	_ensure_rhythm()
	_update_phase()
	var phase := _rhythm.phase_at(elapsed)
	_elite_accum = minf(_elite_accum + elite_rate() / 60.0 * delta, 3.0)
	var rate := spawn_rate() * float(phase.get("rate_mult", 1.0))
	_accum = minf(_accum + rate * delta, max_spawn_per_frame + 1.0)
	var n := mini(int(_accum), max_spawn_per_frame)
	_accum -= n
	if n == 0:
		return
	_spawn_wave(n, center, 0.0, true, phase)


## Raises `n` enemies of the types this hour would bring, in a ring around
## `center` (a resumed night gets its horde back this way). Respects the same
## danger/population budgets as a live tick.
func populate(center: Vector2, n: int) -> void:
	if n <= 0:
		return
	_ensure_rhythm()
	var phase := _rhythm.phase_at(elapsed)
	_spawn_wave(n, center, 12.0, false, phase)


## Spawns up to `n` enemies for `phase`, never exceeding the population/danger
## budgets. `ring_floor > 0` overrides each swarm's own ring_min (the resume
## path). Returns how many actually spawned; spawning never stalls on a full
## danger budget because fodder stays eligible.
func _spawn_wave(n: int, center: Vector2, ring_floor: float, allow_elite: bool, phase: Dictionary) -> int:
	if n <= 0 or _swarms.is_empty():
		return 0
	var age := profile_age()
	for i in _swarms.size():
		_weights[i] = _swarms[i].spawn_weight(age)
	var totals := _living_totals()
	var budget := _budget_for(phase)
	var remaining := maxi(int(budget["total"]) - int(totals["total"]), 0)
	var danger := int(totals["danger"])
	var roles: Dictionary = totals["roles"]
	var costs: Dictionary = budget["costs"]
	var hp_mult := hp_multiplier()
	var spawned := 0
	for k in n:
		if remaining <= 0:
			break
		var swarm := _choose(phase, budget, danger, roles)
		if swarm == null:
			break
		var role := danger_role_of(swarm)
		var lo := ring_floor if ring_floor > 0.0 else swarm.ring_min
		var elite := allow_elite and _elite_accum >= 1.0
		if not swarm.spawn(EnemySwarm.random_ring_point(center, lo, swarm.ring_max), hp_mult, elite):
			break # swarm at capacity: don't overspend the same frame
		if elite:
			_elite_accum -= 1.0
		spawned += 1
		remaining -= 1
		if role != FODDER:
			roles[role] = int(roles.get(role, 0)) + 1
			danger += int(costs[role])
	return spawned


## Weighted pick among the swarms that still fit the budget. Fodder is always
## eligible until the total cap bites; dangerous roles drop out at their cap or
## when their cost would exceed the danger budget.
func _choose(phase: Dictionary, budget: Dictionary, danger: int, roles: Dictionary) -> EnemySwarm:
	var bias: Dictionary = phase.get("bias", {})
	var costs: Dictionary = budget["costs"]
	var caps: Dictionary = budget["role_caps"]
	var total := 0.0
	for i in _swarms.size():
		var swarm := _swarms[i]
		var role := danger_role_of(swarm)
		if role == EXCLUDED:
			continue
		if swarm.count >= swarm.capacity:
			continue
		var weight := _weights[i]
		if weight <= 0.0:
			continue
		if role != FODDER:
			if int(roles.get(role, 0)) >= int(caps.get(role, 0)):
				continue
			if danger + int(costs[role]) > int(budget["danger"]):
				continue
			if bias.has(role):
				weight *= float(bias[role])
		_scratch_swarms.append(swarm)
		_scratch_weights.append(weight)
		total += weight
	if total <= 0.0:
		_scratch_swarms.clear()
		_scratch_weights.clear()
		return null
	var roll := randf() * total
	var picked: EnemySwarm = _scratch_swarms[-1]
	for i in _scratch_swarms.size():
		roll -= _scratch_weights[i]
		if roll < 0.0:
			picked = _scratch_swarms[i]
			break
	_scratch_swarms.clear()
	_scratch_weights.clear()
	return picked


## Enemies per second right now.
func spawn_rate() -> float:
	var age := profile_age()
	return (base_rate + rate_growth * age + rate_acceleration * age * age) * rate_scale * minf(sqrt(pressure), 1.6)


## Elites per minute right now.
func elite_rate() -> float:
	var age := profile_age()
	if age < elite_start_time:
		return 0.0
	return minf(elites_per_minute + elites_per_minute_growth * (age - elite_start_time) / 60.0, elites_per_minute_max)


func hp_multiplier() -> float:
	var age := profile_age()
	var mult := 1.0 + age / hp_growth_seconds
	if hp_squared_seconds > 0.0:
		mult += pow(age / hp_squared_seconds, 2.0)
	return mult * hp_scale * pressure


## How many enemies should be alive around the hero at this point of the
## night, for pressure to stay put.
func crowd_target() -> float:
	return 40.0 + profile_age() * 0.45


## Called every frame by main.gd with the hero's health (0..1) and how many
## enemies are alive.
func update_pressure(delta: float, hero_hp: float, alive: int) -> void:
	if expedition_profile:
		pressure = 1.0
		return
	if elapsed < pressure_start:
		return
	if hero_hp < 0.45:
		pressure -= pressure_rate * 3.0 * delta
	elif hero_hp > 0.9:
		# Barely scratched: build. Faster still if the horde is being wiped out.
		pressure += pressure_rate * delta * (2.0 if alive < crowd_target() * 0.85 else 1.0)
	pressure = clampf(pressure, 1.0, pressure_cap())


## How high pressure may be right now.
func pressure_cap() -> float:
	return clampf(1.0 + (elapsed - pressure_start) / 60.0 * pressure_ramp, 1.0, pressure_max)


## Pure, inspectable description of the population/danger budget for this kind
## of run. Used at runtime and by tests, so the caps and weighted costs are
## documented in exactly one place.
static func danger_budget_spec(expedition: bool) -> Dictionary:
	var total := CAMPAIGN_TOTAL_CAP if expedition else CLASSIC_TOTAL_CAP
	var danger := CAMPAIGN_DANGER_CAP if expedition else CLASSIC_DANGER_CAP
	var costs := {"ranged": 2, "charger": 2, "large": 3}
	var caps := {}
	for role in costs.keys():
		caps[role] = int(danger / int(costs[role]))
	var summary := "total=%d danger=%d costs(ranged=%d, charger=%d, large=%d) role_caps(ranged=%d, charger=%d, large=%d)" % [
		total, danger, int(costs[DANGER_RANGED]), int(costs[DANGER_CHARGER]), int(costs[DANGER_LARGE]),
		int(caps[DANGER_RANGED]), int(caps[DANGER_CHARGER]), int(caps[DANGER_LARGE])]
	return {
		"total": total, "danger": danger, "costs": costs, "role_caps": caps,
		"summary": summary, "excluded": "bosses and zero-spawn-weight (event-only) swarms",
	}


## Classifies a swarm for the budget. Ranged wins over large; charger wins over
## both. Bosses and zero-spawn-weight event-only swarms are EXCLUDED, so the
## director's caps never count or limit scripted/event actors.
static func danger_role_of(swarm: EnemySwarm) -> String:
	if swarm == null or swarm.boss or swarm.spawn_share <= 0.0:
		return EXCLUDED
	if swarm.charger:
		return DANGER_CHARGER
	if swarm.attack_range > 0.0:
		return DANGER_RANGED
	if swarm.radius >= LARGE_RADIUS or swarm.model in LARGE_MODELS:
		return DANGER_LARGE
	return FODDER


func _ensure_rhythm() -> void:
	if _rhythm == null:
		_rhythm = MissionRhythm.new()
		_rhythm.setup(MissionRhythm.DEFAULT_DURATION, "hunt")


## Emits `phase_changed` once per transition. The reward payload's
## `reward_opportunity` is only true the first time this mission enters reward.
func _update_phase() -> void:
	_ensure_rhythm()
	var phase := _rhythm.phase_at(elapsed)
	var id := String(phase.get("id", ""))
	if id == _phase_id:
		return
	_phase_id = id
	if bool(phase.get("reward_opportunity", false)):
		if _reward_announced:
			phase["reward_opportunity"] = false
		else:
			_reward_announced = true
	phase_changed.emit(phase)


## Counts every living normal actor the budget accounts for. Bosses and
## zero-spawn-weight swarms are skipped; event actors living inside a normal
## swarm are counted, which is what keeps the director from overspending.
func _living_totals() -> Dictionary:
	var total := 0
	var danger := 0
	var roles := {DANGER_RANGED: 0, DANGER_CHARGER: 0, DANGER_LARGE: 0}
	for swarm in _swarms:
		var role := danger_role_of(swarm)
		if role == EXCLUDED:
			continue
		var alive := swarm.alive_count()
		total += alive
		if role != FODDER:
			roles[role] = int(roles[role]) + alive
			danger += alive * int(DANGER_COST[role])
	return {"total": total, "danger": danger, "roles": roles}


## The era budget with this phase's danger scaling applied (opening and reward
## are deliberately more forgiving; surge and finale run at full).
func _budget_for(phase: Dictionary) -> Dictionary:
	var base := danger_budget_spec(expedition_profile)
	var mult := maxf(float(phase.get("danger_mult", 1.0)), 0.0)
	var costs: Dictionary = base["costs"]
	var base_caps: Dictionary = base["role_caps"]
	var caps := {}
	for role in costs.keys():
		caps[role] = maxi(int(floor(float(base_caps[role]) * mult)), 0)
	return {
		"total": int(base["total"]),
		"danger": maxi(int(floor(float(base["danger"]) * mult)), 0),
		"costs": costs,
		"role_caps": caps,
	}


func _pick(roll: float) -> EnemySwarm:
	for i in _swarms.size():
		roll -= _weights[i]
		if roll < 0.0:
			return _swarms[i]
	return _swarms[-1]
