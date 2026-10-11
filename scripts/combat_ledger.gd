class_name CombatLedger
extends RefCounted
## Actual non-overkill damage. Active time means combat seconds with the source
## available, not animation/casting time. Pauses, town and Night Market excluded.

const TARGET_CAP := 20000
var elapsed := 0.0
var epoch := 0
var sources := {}
var reactions := {}
var _last_delta := 0.0
var _counted_this_tick := {}

func _row(who: String) -> Dictionary:
	if not sources.has(who):
		sources[who] = {"damage": 0.0, "hits": 0, "targets": {}, "targets_capped": false, "active_seconds": 0.0, "first_at": -1.0, "last_at": -1.0, "measured": true}
	return sources[who]

func tick(delta: float, available: Array) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	_last_delta = delta
	_counted_this_tick.clear()
	for who: String in available:
		if _counted_this_tick.has(who): continue
		_counted_this_tick[who] = true
		var row := _row(who)
		if row["first_at"] < 0.0: row["first_at"] = elapsed
		row["active_seconds"] += delta
		row["last_at"] = elapsed + delta
	elapsed += delta

func record(who: String, amount: float, target := "") -> void:
	if amount <= 0.0 or not is_finite(amount): return
	var row := _row(who)
	row["damage"] += amount
	row["hits"] += 1
	# A removed weapon's projectile, minion element or lingering pulse can hit
	# outside the stat-based availability list. Count that combat frame once.
	if _last_delta > 0.0 and not _counted_this_tick.has(who):
		_counted_this_tick[who] = true
		row["active_seconds"] += _last_delta
		if row["first_at"] < 0.0: row["first_at"] = elapsed - _last_delta
		row["last_at"] = elapsed
	if target != "" and not row["targets"].has(target):
		if row["targets"].size() < TARGET_CAP: row["targets"][target] = true
		else: row["targets_capped"] = true

func reaction(kind: String, damage: float, trigger := false) -> void:
	if not reactions.has(kind): reactions[kind] = {"damage": 0.0, "hits": 0, "triggers": 0}
	if trigger: reactions[kind]["triggers"] += 1
	if damage > 0.0:
		reactions[kind]["damage"] += damage
		reactions[kind]["hits"] += 1

func target_key(swarm: EnemySwarm, index: int) -> String:
	return "%d:%s:%d" % [epoch, swarm.name, swarm.ids[index]]

func snapshot() -> Dictionary:
	return {"elapsed": elapsed, "epoch": epoch, "sources": sources.duplicate(true), "reactions": reactions.duplicate(true)}

func restore(data: Dictionary, legacy_damage: Dictionary = {}) -> void:
	_last_delta = 0.0
	_counted_this_tick.clear()
	elapsed = float(data.get("elapsed", 0.0))
	epoch = int(data.get("epoch", 0)) + 1
	sources = data.get("sources", {}).duplicate(true)
	reactions = data.get("reactions", {}).duplicate(true)
	if data.is_empty():
		for who: String in legacy_damage:
			var row := _row(who)
			row["damage"] = float(legacy_damage[who])
			row["measured"] = false

func report() -> Dictionary:
	var rows: Array[Dictionary] = []
	var total := 0.0
	for who: String in sources:
		var row: Dictionary = sources[who]
		if row["damage"] <= 0.0: continue
		total += row["damage"]
		rows.append({"source": who, "damage": row["damage"], "hits": row["hits"], "targets": row["targets"].size(), "targets_capped": row["targets_capped"], "active_seconds": row["active_seconds"], "first_at": row["first_at"], "last_at": row["last_at"], "measured": row["measured"], "dps": row["damage"] / row["active_seconds"] if row["measured"] and row["active_seconds"] > 0.0 else -1.0})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["damage"] > b["damage"])
	return {"total": total, "rows": rows, "reactions": reactions.duplicate(true), "elapsed": elapsed}

static func summary(report_data: Dictionary, limit := 6) -> String:
	var lines: Array[String] = ["REAL DAMAGE · %d total · DPS / available combat seconds; unique targets per source" % int(report_data.get("total", 0))]
	for row: Dictionary in report_data.get("rows", []).slice(0, limit):
		var performance := "unmeasured legacy time" if not row.get("measured", true) else ("%.1f DPS / %.1f s" % [row["dps"], row["active_seconds"]] if row["dps"] >= 0.0 else "no active-time sample")
		lines.append("%s · %d damage · %s · %d hits · %d%s targets" % [row["source"], int(row["damage"]), performance, row["hits"], row["targets"], "+" if row.get("targets_capped", false) else ""])
	var reactions_text: Array[String] = []
	for kind: String in report_data.get("reactions", {}):
		reactions_text.append("%s %d" % [kind, int(report_data["reactions"][kind]["damage"])])
	if not reactions_text.is_empty(): lines.append("REACTION CONTRIBUTION (included above) · " + " · ".join(reactions_text) + " · Melt credits only its proportional extra damage")
	return "\n".join(lines)

static func available(stats: PlayerStats, army_count: int, trial := "", swarms: Array[EnemySwarm] = []) -> Array:
	var out := []
	if trial not in ["trial_army", "trial_dash"]:
		if trial != "trial_reaction" and not stats.powers.has("reaping"): out.append("Magic Bolt")
		var levels := {"aura_level": "Frost Aura", "lightning_level": "Chain Lightning", "orbit_level": "Spirit Blades", "nova_level": "Arcane Nova", "obol_level": "Obol", "scythe_level": "Reaping Scythe", "spikes_level": "Grave Spikes", "wisp_level": "Wisp Lantern", "trail_level": "Brimstone Trail", "bell_level": "Funeral Bell"}
		for field: String in levels:
			if trial == "trial_reaction" and not field in ["aura_level", "lightning_level", "wisp_level", "trail_level"]: continue
			if stats.get(field) > 0: out.append(levels[field])
	if army_count > 0 and TacticTrials.army_allowed(trial): out.append("Soul Army")
	if stats.powers.has("stormstride") and trial != "trial_army": out.append("Stormstride")
	var fire := (trial not in ["trial_army", "trial_dash"] and (Upgrades._has_burn_source(stats) or stats.powers.has("ember_ring")))
	var frost := trial not in ["trial_army", "trial_dash"] and Upgrades._has_chill_source(stats)
	var lightning := (trial not in ["trial_army", "trial_dash"] and stats.lightning_level > 0) or stats.powers.has("stormstride") and trial != "trial_army"
	# Lingering statuses remain real availability after the granting item goes.
	for swarm in swarms:
		if fire and frost and lightning: break
		for i in swarm.count:
			if swarm.hp[i] <= 0.0: continue
			fire = fire or swarm.burn[i] > 0.0
			frost = frost or swarm.chill[i] > 0.0
			lightning = lightning or swarm.shock[i] > 0.0
			if fire and frost and lightning: break
	if fire: out.append("Burning")
	if (fire and frost) or (fire and lightning) or (frost and lightning): out.append("Reactions")
	for id: String in ["synergy_relay", "synergy_escort", "synergy_wake"]:
		if trial == "" and BuildSynergies.live(id, stats) and (id != "synergy_escort" or army_count > 0): out.append({"synergy_relay": "Frost Relay", "synergy_escort": "Ashen Escort", "synergy_wake": "Blade Wake"}[id])
	return out
