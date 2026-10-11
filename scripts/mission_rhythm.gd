class_name MissionRhythm
extends RefCounted
## Authored mission rhythm: a pure table of phases keyed by the fraction of the
## configured mission duration that has *really* elapsed.
##
## This object owns no clock, no victory condition and no deadline. WaveDirector
## drives it (passing its authoritative `elapsed`), and ExpeditionDirector still
## arbitrates outcomes. The rhythm only answers "which authored phase is this?"
## and hands back the tuning that phase implies (spawn-rate multiplier, danger
## budget multiplier and a composition bias toward the contract's surge role).
##
## The phase table is deliberately small and readable:
##   opening  - a lighter entry ramp
##   surge    - the mid-mission push, biased toward the contract's danger role
##   reward   - a recovery lull that carries `reward_opportunity` exactly once
##   finale   - the last stretch, heavier again
##
## Fractions are taken against the mission duration, so a 300 s contract and a
## 900 s night both pass through opening -> surge -> reward -> finale. Past the
## duration the fraction saturates and the mission settles in the finale phase
## (no wrap-around, no invented extra phases). This is a table, not authority:
## "repeat/settle" here only means the last phase keeps applying.

## Classic nights run 900 s.
const DEFAULT_DURATION := 900.0

## The three dangerous roles a surge can emphasise.
const ROLE_RANGED := "ranged"
const ROLE_CHARGER := "charger"
const ROLE_LARGE := "large"

## How strongly a surge leans on its role when the budget allows.
const SURGE_BIAS := 2.5

## Which dangerous role each authored contract surges. Unknown contracts cycle
## by a stable hash so two of them don't all pick the same role forever.
const CONTRACT_SURGE_ROLE := {
	"hunt": ROLE_RANGED,
	"breach": ROLE_CHARGER,
	"seal_breach": ROLE_CHARGER,
	"elite_hunt": ROLE_LARGE,
	"cursed_cache": ROLE_RANGED,
}

## Fraction boundaries of each phase. Kept as data so tests and tuning read the
## same numbers the sampling uses.
const OPENING_END := 0.14
const SURGE_END := 0.60
const REWARD_END := 0.74

var duration := DEFAULT_DURATION
var contract_id := "hunt"
var surge_role := ROLE_RANGED
var _phases: Array[Dictionary] = []


func _init() -> void:
	setup(DEFAULT_DURATION, "hunt")


## Builds (or rebuilds) the phase table for a mission of `duration_seconds`
## and a contract. Explicitly resets surge role and table.
func setup(duration_seconds: float, contract: String = "hunt") -> void:
	duration = maxf(duration_seconds, 1.0)
	contract_id = contract if not contract.is_empty() else "hunt"
	surge_role = surge_role_for(contract_id)
	_phases = _build_phases(surge_role)


## Stable mapping from contract to the role its surge phase emphasises.
static func surge_role_for(contract: String) -> String:
	var id := contract if not contract.is_empty() else "hunt"
	if CONTRACT_SURGE_ROLE.has(id):
		return CONTRACT_SURGE_ROLE[id]
	var order := [ROLE_RANGED, ROLE_CHARGER, ROLE_LARGE]
	return order[posmod(hash(id), order.size())]


## The full authored table (a copy, so callers can't rewrite it).
func phases() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for phase in _phases:
		out.append(phase.duplicate(true))
	return out


## Fraction of the configured duration really elapsed, clamped to [0, 1].
func fraction(elapsed: float) -> float:
	return clampf(elapsed / duration, 0.0, 1.0)


## The phase for a real elapsed time. Past the duration this stays the finale.
func phase_at(elapsed: float) -> Dictionary:
	var f := fraction(elapsed)
	for phase in _phases:
		if f >= float(phase["start"]) and f < float(phase["end"]):
			return phase.duplicate(true)
	return _phases[-1].duplicate(true)


## Convenience: just the id of the phase at `elapsed`.
func phase_id_at(elapsed: float) -> String:
	var f := fraction(elapsed)
	for phase in _phases:
		if f >= float(phase["start"]) and f < float(phase["end"]):
			return String(phase["id"])
	return String(_phases[-1]["id"])


## The authored phase with this id, or an empty dictionary.
func phase_by_id(id: String) -> Dictionary:
	for phase in _phases:
		if String(phase["id"]) == id:
			return phase.duplicate(true)
	return {}


## The one authored phase that offers a reward, or "".
func reward_phase_id() -> String:
	for phase in _phases:
		if bool(phase.get("reward_opportunity", false)):
			return String(phase["id"])
	return ""


static func _build_phases(role: String) -> Array[Dictionary]:
	var bias: Dictionary = {}
	if role != "":
		bias[role] = SURGE_BIAS
	return [
		{
			"id": "opening", "label": "Opening",
			"start": 0.0, "end": OPENING_END,
			"rate_mult": 0.85, "danger_mult": 0.5,
			"role": "", "bias": {}, "reward_opportunity": false,
		},
		{
			"id": "surge", "label": "Surge",
			"start": OPENING_END, "end": SURGE_END,
			"rate_mult": 1.15, "danger_mult": 1.0,
			"role": role, "bias": bias, "reward_opportunity": false,
		},
		{
			"id": "reward", "label": "Reward",
			"start": SURGE_END, "end": REWARD_END,
			"rate_mult": 0.6, "danger_mult": 0.35,
			"role": "", "bias": {}, "reward_opportunity": true,
		},
		{
			"id": "finale", "label": "Finale",
			"start": REWARD_END, "end": 1.0,
			"rate_mult": 1.3, "danger_mult": 1.0,
			"role": role, "bias": bias, "reward_opportunity": false,
		},
	]
