class_name Ferryman
extends Node3D
## The Ferryman's bargains: a spectral boatman who trades in souls and risk.
##
## Twice a night he appears somewhere near the hero (an arrow points the
## way). Walk up and press E to open his table (WagerPanel):
##   - a Rare prize for a random slot. Take it, or wager it: 70% it becomes a
##     Legendary, 30% it's gone. Win, and you may wager again: 45% for a
##     second Legendary, 55% to lose both. You can take the winnings at any
##     point instead.
##   - Pledge a minion to tilt the first coin: +10%. It leaves the army and
##     comes back after 60 s, win or lose.
##   - Borrow power: +50% damage for 90 s. In 45 s a Debt Collector comes to
##     collect, seizing a minion each time it touches you, until it dies.
## Mid-bosses also come with his side bet: slay it within 45 s for a
## Legendary and 10 Soul Shards.
##
## Every outcome comes from this node's own random stream (not the shared
## one the effects and sound use), is rolled the moment you choose, and is
## paid out exactly once.

signal announced(text: String, color: Color)

const FIRST_AT := 150.0
const SECOND_AT := 420.0
const VISIT_TIME := 75.0
const FIRST_ODDS := 0.7
const SECOND_ODDS := 0.45
const PLEDGE_BONUS := 0.1
const PLEDGE_TIME := 60.0
const LOAN_TIME := 90.0
const LOAN_DELAY := 45.0
const BET_TIME := 45.0
const LOAN_SOURCE := "loan"
const COLOR := Color(0.55, 0.85, 1.0)

## Run shards earned here (main.gd collects them).
var shards := 0
## The side bet's text for the HUD ("" for none).
var bet_text := ""
var prompt := ""
## Visits and results, for the run report and tests.
var stats := {"visits": 0, "banked": 0, "wagers_won": 0, "wagers_lost": 0, "loans": 0, "bets_won": 0, "bets_lost": 0}

var rng := RandomNumberGenerator.new()
var _player: Player
var _army: Army
var _loot: LootManager
var _director: WaveDirector
var _collectors: EnemySwarm
var _panel: WagerPanel
var _elapsed := 0.0
var _schedule: Array[float] = [FIRST_AT, SECOND_AT]
## The current visit: {"at", "node", "left", "stage", "prizes": [Item], "slot", "pledged"}, or {}.
var _visit := {}
var _loan_left := 0.0
var _collector_in := -1.0
var _bet_left := 0.0
var _spin_pending := ""


func setup(player: Player, army: Army, loot: LootManager, director: WaveDirector, collectors: EnemySwarm,
		panel: WagerPanel) -> void:
	_player = player
	_army = army
	_loot = loot
	_director = director
	_collectors = collectors
	_panel = panel
	rng.randomize()
	_panel.chosen.connect(_on_chosen)
	if _collectors:
		_collectors.enemy_died.connect(func(_at: Vector2, _xp: int) -> void:
			var n := _army.release_away()
			if n > 0:
				announced.emit("The Collector falls. Your %d seized minion%s return!" % [n, "" if n == 1 else "s"], COLOR))


func tick(delta: float) -> void:
	_elapsed += delta
	if not _schedule.is_empty() and _elapsed >= _schedule[0] and _visit.is_empty():
		if _arrive():
			_schedule.pop_front()
		else:
			_schedule[0] += 5.0
	_update_visit(delta)
	_update_loan(delta)
	_update_bet(delta)


## Edge-arrow markers for the HUD.
func markers() -> Array:
	var out := []
	if not _visit.is_empty():
		out.append({"at": _visit["at"], "color": COLOR, "label": "FERRYMAN"})
	if _collectors:
		for i in _collectors.count:
			if _collectors.hp[i] > 0.0:
				out.append({"at": _collectors.pos[i], "color": Color(1.0, 0.82, 0.35), "label": "DEBT COLLECTOR"})
	return out


# --- visits ---------------------------------------------------------------------------

func _arrive() -> bool:
	var at := Vector2.INF
	for attempt in 16:
		var p := _player.pos2 + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(13.0, 17.0)
		if not Obstacles.blocked(p, 2.5):
			at = p
			break
	if at == Vector2.INF:
		return false
	var root := Node3D.new()
	root.position = Vector3(at.x, 0.0, at.y)
	add_child(root)
	var model := MeshInstance3D.new()
	model.mesh = Models.ferryman()
	model.rotation.y = PI # face the camera
	root.add_child(model)
	HazardDirector.make_decal(root, Vector2.ZERO, Color(0.55, 0.85, 1.0, 0.5), 0.9, 4.2)
	var light := OmniLight3D.new()
	light.light_color = COLOR
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.position = Vector3(0, 2.6, -0.5)
	root.add_child(light)
	var slot: String = ItemData.SLOTS[rng.randi() % ItemData.SLOTS.size()]
	var prize := ItemGenerator.generate_with(_ilvl(), ItemData.Rarity.RARE, slot)
	_visit = {"at": at, "node": root, "left": VISIT_TIME, "stage": "offer", "prizes": [prize], "slot": slot, "pledged": false}
	stats["visits"] += 1
	Sound.play("shrine_charge", 0.6, 2.0)
	announced.emit("The Ferryman waits nearby. He has an offer...", COLOR)
	return true


func _update_visit(delta: float) -> void:
	prompt = ""
	if _visit.is_empty():
		return
	if not _panel.is_open():
		_visit["left"] -= delta
	if _visit["left"] <= 0.0 and not _panel.is_open():
		announced.emit("The Ferryman poles away into the dark.", UiStyle.MUTED)
		_depart()
		return
	if _player.pos2.distance_to(_visit["at"]) <= 3.2:
		prompt = "[E]  Speak with the Ferryman  ·  a wager for your soul"
		if Input.is_action_just_pressed("interact"):
			open_table()


func open_table() -> void:
	if _visit.is_empty():
		return
	get_tree().paused = true
	_show()


func _show(result := "", result_color := UiStyle.GOLD) -> void:
	var prizes: Array = _visit["prizes"]
	var names := ", ".join(prizes.map(func(i: Item) -> String: return i.name))
	var actions := []
	var odds := ""
	var detail := ""
	var stage: String = _visit["stage"]
	if prizes.size() == 1:
		detail = "  ·  ".join((prizes[0] as Item).description_lines().slice(0, 4))
	match stage:
		"offer":
			var chance := first_odds()
			odds = "Wager it: %d%% it becomes a Legendary, %d%% it's lost to the river." % [roundi(chance * 100), roundi((1.0 - chance) * 100)]
			actions.append(["take", "Take it", true])
			actions.append(["wager", "Wager (%d%%)" % roundi(chance * 100), true])
			var who: bool = _army.count > 0 and not _visit["pledged"]
			actions.append(["pledge", "Pledge a minion (+%d%%)" % roundi(PLEDGE_BONUS * 100) if not _visit["pledged"] else "Minion pledged", who])
			actions.append(["borrow", "Borrow power" if _loan_left <= 0.0 else "In his debt", _loan_left <= 0.0 and _collector_in < 0.0])
			actions.append(["leave", "Leave", true])
		"double":
			odds = "Wager again: %d%% for a second Legendary, %d%% to lose it all." % [roundi(SECOND_ODDS * 100), roundi((1.0 - SECOND_ODDS) * 100)]
			actions.append(["take", "Take the Legendary", true])
			actions.append(["wager", "Wager again (%d%%)" % roundi(SECOND_ODDS * 100), true])
		"spinning":
			odds = "The coin spins..."
		"done":
			actions.append(["leave", "Leave", true])
		"won":
			odds = "\"The river is generous tonight.\""
			actions.append(["take", "Take your winnings", true])
	_panel.show_state({"prize": names if not prizes.is_empty() else "Nothing", "prize_color": (prizes[-1] as Item).color() if not prizes.is_empty() else UiStyle.MUTED,
			"detail": detail, "odds": odds, "result": result, "result_color": result_color, "actions": actions})


## The first wager's odds, with a pledge.
func first_odds() -> float:
	return FIRST_ODDS + (PLEDGE_BONUS if not _visit.is_empty() and _visit["pledged"] else 0.0)


func _on_chosen(action: String) -> void:
	if _visit.is_empty() or _visit["stage"] == "spinning":
		return
	match action:
		"take":
			_bank()
		"leave":
			_close()
			if _visit["stage"] == "done":
				_depart()
		"pledge":
			var r := _army.send_away(PLEDGE_TIME)
			if not r.is_empty():
				_visit["pledged"] = true
				_show("Your %s waits on the raft. +10%%" % r["name"], COLOR)
		"borrow":
			_borrow()
			_show("Power floods you. The Collector will come.", Color(1.0, 0.82, 0.35))
		"wager":
			var second: bool = _visit["stage"] == "double"
			# Committed now; the spin is only for show.
			var win := rng.randf() < (SECOND_ODDS if second else first_odds())
			_visit["stage"] = "spinning"
			_show()
			Sound.play("coin_spin")
			var t := create_tween()
			t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			t.tween_interval(1.0)
			t.tween_callback(_reveal.bind(win, second))


func _reveal(win: bool, second: bool) -> void:
	if _visit.is_empty():
		return
	if win:
		stats["wagers_won"] += 1
		var legendary := ItemGenerator.generate_with(_ilvl(), ItemData.Rarity.LEGENDARY, _visit["slot"] if not second else ItemData.SLOTS[rng.randi() % ItemData.SLOTS.size()])
		if second:
			_visit["prizes"].append(legendary)
			_visit["stage"] = "won"
		else:
			_visit["prizes"] = [legendary]
			_visit["stage"] = "double"
		Sound.play("legendary")
		_show("HEADS. The river gives." if not second else "HEADS AGAIN. Two Legendaries!", Color(1.0, 0.75, 0.3))
	else:
		stats["wagers_lost"] += 1
		_visit["prizes"] = []
		_visit["stage"] = "done"
		Sound.play("defeat", 1.3, -8.0)
		_show("Tails. The river takes it all.", Color(1.0, 0.4, 0.35))


## Pays the prizes out at the raft, once, and sends him off.
func _bank() -> void:
	for item: Item in _visit["prizes"]:
		_loot.drop(item, _visit["at"] + Vector2(rng.randf_range(-1.0, 1.0), 2.2))
	if not _visit["prizes"].is_empty():
		stats["banked"] += 1
	_visit["prizes"] = []
	_close()
	_depart()


func _close() -> void:
	_panel.close()
	get_tree().paused = false


func _depart() -> void:
	if _visit.is_empty():
		return
	Juice.burst(_visit["at"], 1.5, COLOR, 30, 3.0, 0.5, 1.0, 4.0)
	(_visit["node"] as Node3D).queue_free()
	_visit = {}


# --- the loan and its Collector ---------------------------------------------------------

func _borrow() -> void:
	stats["loans"] += 1
	_loan_left = LOAN_TIME
	_collector_in = LOAN_DELAY
	var s := _player.stats
	s.remove_source(LOAN_SOURCE)
	s.add_mods(LOAN_SOURCE, [{"stat": "damage", "op": PlayerStats.Op.MORE, "value": 0.5}])
	s.recalculate()
	Sound.play("shrine_done", 0.8)


func _update_loan(delta: float) -> void:
	if _loan_left > 0.0:
		_loan_left -= delta
		if _loan_left <= 0.0:
			_player.stats.remove_source(LOAN_SOURCE)
			_player.stats.recalculate()
	if _collector_in >= 0.0:
		_collector_in -= delta
		if _collector_in < 0.0:
			_send_collector()


func _send_collector() -> void:
	if _collectors == null:
		return
	var at := _player.pos2 + Vector2.from_angle(rng.randf() * TAU) * 16.0
	_collectors.spawn(at, _director.hp_multiplier())
	Sound.play("boss_arrive", 0.8, -2.0)
	announced.emit("The Debt Collector has come for what you owe!", Color(1.0, 0.82, 0.35))


## A Collector touched the hero: it takes a minion until it dies.
func seize() -> void:
	var r := _army.send_away(-1.0)
	if not r.is_empty():
		announced.emit("The Collector seizes your %s! Kill it to get it back." % r["name"], Color(1.0, 0.6, 0.3))
		Sound.play("minion_death", 0.7)


# --- side bets on mid-bosses ---------------------------------------------------------

func start_bet(boss_name: String) -> void:
	_bet_left = BET_TIME
	announced.emit("The Ferryman's bet: slay %s within %d s." % [boss_name, int(BET_TIME)], COLOR)


func _update_bet(delta: float) -> void:
	if _bet_left <= 0.0:
		bet_text = ""
		return
	_bet_left -= delta
	bet_text = "Ferryman's bet: %d s" % ceili(_bet_left)
	if _bet_left <= 0.0:
		stats["bets_lost"] += 1
		bet_text = ""
		announced.emit("Too slow. The Ferryman shrugs.", UiStyle.MUTED)


func boss_slain(at: Vector2) -> void:
	if _bet_left <= 0.0:
		return
	_bet_left = 0.0
	bet_text = ""
	stats["bets_won"] += 1
	shards += 10
	_loot.drop(ItemGenerator.generate_with(_ilvl(), ItemData.Rarity.LEGENDARY, ItemData.SLOTS[rng.randi() % ItemData.SLOTS.size()]), at + Vector2(0, 2))
	announced.emit("Bet won! The Ferryman pays: a Legendary and 10 Soul Shards.", Color(1.0, 0.8, 0.35))


func _ilvl() -> int:
	return ItemData.ilvl_for_player_level(_player.stats.level)
