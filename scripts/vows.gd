class_name Vows
extends Node
## Whispered Vows: twice a night (0:45 and 7:30) the dead whisper one small,
## optional challenge. It is accepted on the spot and has a time limit; one at a
## time. Keep it and you earn run Soul Shards and a blessing; miss it and the
## whisper simply fades, with no penalty. Classic nights only (main.gd leaves
## `enabled` off in the campaign).
##
## Events reach it through small hooks main.gd calls (on_kill, on_elite,
## on_dash, on_raise, on_soul); reactions are read off Elements.metrics and
## distance from the position handed to tick(). Nothing here is saved: a
## resumed night starts fresh and does not re-offer a window that has passed.

signal whispered(title: String, subtitle: String)
signal kept(blessing: String)
signal faded(text: String)

const WINDOWS := [45.0, 450.0]
const SHARDS := 4
const COLOR := Color(0.7, 0.75, 0.95)
const KEPT_COLOR := Color(1.0, 0.85, 0.35)
const BURST_SECONDS := 20.0

## id -> text (%d is the target), feed (what counts), limit in seconds, and
## `requires` (a capability checked against the hero, see _can).
const POOL := {
	"shatter": {"text": "Shatter %d foes", "target": 25, "limit": 120.0, "requires": "shatter"},
	"melt": {"text": "Melt %d foes", "target": 20, "limit": 120.0, "requires": "melt"},
	"overload": {"text": "Overload %d foes", "target": 20, "limit": 120.0, "requires": "overload"},
	"burst": {"text": "Slay %d foes in 20 seconds", "target": 20, "limit": 120.0, "requires": ""},
	"raise": {"text": "Raise %d minions", "target": 4, "limit": 150.0, "requires": "army"},
	"elite": {"text": "Slay an elite without dashing", "target": 1, "limit": 120.0, "requires": ""},
	"steady": {"text": "Stay above half health", "target": 90, "limit": 90.0, "requires": "healthy"},
	"walk": {"text": "Walk the night: travel %d m", "target": 250, "limit": 150.0, "requires": ""},
	"souls": {"text": "Gather %d souls", "target": 20, "limit": 120.0, "requires": ""},
}
const REACTION_KIND := {"shatter": "Shatter", "melt": "Melt", "overload": "Overload"}

## Switched off in the campaign (it has its own objectives).
var enabled := true
## The seeded stream (a Daily Night seeds it, so everyone is whispered the same).
var rng := RandomNumberGenerator.new()
## Run shards won since main.gd last collected them.
var shards := 0
var offered := 0
var kept_count := 0
## The vow in force: {} for none, else id, text, target, progress, left, limit.
var active := {}

var stats: PlayerStats
var _next_window := 0
var _hp_frac := 1.0
var _last_pos := Vector2.ZERO
var _has_pos := false
var _base := 0
var _kill_times: Array[float] = []
var _now := 0.0


func setup(player_stats: PlayerStats) -> void:
	stats = player_stats


## A resumed night starts fresh: no vow, and windows already behind us stay shut.
func resume_at(elapsed: float) -> void:
	active = {}
	_next_window = 0
	while _next_window < WINDOWS.size() and WINDOWS[_next_window] <= elapsed:
		_next_window += 1


## Whether the hero can actually do `need` this night.
func _can(need: String) -> bool:
	if need == "":
		return true
	if stats == null:
		return false
	match need:
		"shatter":
			return Upgrades._has_chill_source(stats) and stats.lightning_level > 0
		"melt":
			return Upgrades._has_chill_source(stats) and Upgrades._has_burn_source(stats)
		"overload":
			return stats.lightning_level > 0 and Upgrades._has_burn_source(stats)
		"army":
			return stats.minion_max > 0
		"healthy":
			return _hp_frac >= 0.6
	return false


## The vows this hero could be whispered right now (stable order).
func eligible() -> Array[String]:
	var out: Array[String] = []
	for id: String in POOL:
		if _can(POOL[id]["requires"]):
			out.append(id)
	return out


func tick(delta: float, elapsed: float, hp_frac: float, pos: Vector2) -> void:
	if not enabled:
		return
	_now = elapsed
	_hp_frac = hp_frac
	if _has_pos and active.has("id") and active["id"] == "walk":
		# A teleport is not a walk: cap what one frame can add.
		active["progress"] += minf(pos.distance_to(_last_pos), 4.0)
	_last_pos = pos
	_has_pos = true
	if active.is_empty():
		if _next_window < WINDOWS.size() and elapsed >= WINDOWS[_next_window]:
			_next_window += 1
			_whisper(elapsed)
		return
	active["left"] -= delta
	match active["id"]:
		"shatter", "melt", "overload":
			var row: Dictionary = Elements.metrics.reactions.get(REACTION_KIND[active["id"]], {})
			var count := int(row.get("triggers", 0))
			if count < _base:
				_base = count
			active["progress"] = count - _base
		"burst":
			while not _kill_times.is_empty() and _kill_times[0] < elapsed - BURST_SECONDS:
				_kill_times.pop_front()
			active["progress"] = maxi(int(active["progress"]), _kill_times.size())
		"steady":
			active["progress"] = active["limit"] - maxf(active["left"], 0.0)
			if hp_frac < 0.5:
				_end(false)
				return
			if active["left"] <= 0.0:
				_end(true)
				return
	_settle()


func _whisper(elapsed: float) -> void:
	var ids := eligible()
	if ids.is_empty():
		return
	offer(ids[rng.randi() % ids.size()], elapsed)


## Whispers vow `id` now (the scheduler's pick; tests call it directly).
func offer(id: String, elapsed: float) -> void:
	var def: Dictionary = POOL[id]
	var target: int = def["target"]
	if id == "burst":
		target = 12 + int(elapsed / 30.0)
	var text: String = def["text"] % target if "%d" in def["text"] else def["text"]
	active = {"id": id, "text": text, "target": target, "progress": 0, "left": def["limit"], "limit": def["limit"]}
	_kill_times.clear()
	_has_pos = false
	if REACTION_KIND.has(id):
		_base = int(Elements.metrics.reactions.get(REACTION_KIND[id], {}).get("triggers", 0))
	offered += 1
	whispered.emit("A vow is whispered", text)


## Ends the vow when it has been met or has run out.
func _settle() -> void:
	if active.is_empty() or active["id"] == "steady":
		return
	if active["progress"] >= active["target"]:
		_end(true)
	elif active["left"] <= 0.0:
		_end(false)


func _end(success: bool) -> void:
	active = {}
	if success:
		kept_count += 1
		shards += SHARDS
		var names := EventDirector.BLESSINGS.keys()
		kept.emit(names[rng.randi() % names.size()])
	else:
		faded.emit("The whisper fades")


# --- hooks ---------------------------------------------------------------------

func on_kill() -> void:
	if enabled and active.get("id", "") == "burst":
		_kill_times.append(_now)
		active["progress"] = maxi(int(active["progress"]), _kill_times.size())
		_settle()


func on_elite() -> void:
	if enabled and active.get("id", "") == "elite":
		active["progress"] += 1
		_settle()


func on_dash() -> void:
	if enabled and active.get("id", "") == "elite":
		_end(false)


func on_raise() -> void:
	if enabled and active.get("id", "") == "raise":
		active["progress"] += 1
		_settle()


func on_soul(count := 1) -> void:
	if enabled and active.get("id", "") == "souls":
		active["progress"] += count
		_settle()


# --- display -------------------------------------------------------------------

## The HUD line ("" when no vow is in force).
func hud_text() -> String:
	if active.is_empty():
		return ""
	var left := maxi(ceili(active["left"]), 0)
	var time := "%d:%02d" % [left / 60, left % 60]
	if active["id"] == "steady":
		return "VOW  ·  %s  ·  %s" % [active["text"], time]
	return "VOW  ·  %s  —  %d/%d  ·  %s" % [active["text"], mini(int(active["progress"]), active["target"]), active["target"], time]


## "Vows kept: 1/2" for the run report ("" if none were whispered).
func report_text() -> String:
	return "Vows kept: %d/%d" % [kept_count, offered] if offered > 0 else ""
