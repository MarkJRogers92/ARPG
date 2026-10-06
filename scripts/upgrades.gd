class_name Upgrades
extends RefCounted
## The level-up pool. To add an upgrade: add an entry to DEFS and a case to
## apply(). `max` caps how many times it can be taken.

const DEFS := {
	"bolt_damage": {"name": "Sharper Bolts", "desc": "+25% bolt damage", "max": 8},
	"bolt_rate": {"name": "Quick Cast", "desc": "Bolts fire 15% faster", "max": 6},
	"bolt_count": {"name": "Multishot", "desc": "+1 bolt per volley", "max": 5},
	"bolt_pierce": {"name": "Piercing Bolts", "desc": "Bolts pass through +1 enemy", "max": 4},
	"aura": {"name": "Frost Aura", "desc": "Damages enemies close to you", "max": 6},
	"move_speed": {"name": "Swift Boots", "desc": "+10% move speed", "max": 5},
	"max_hp": {"name": "Vitality", "desc": "+25 max HP, heal 25", "max": 8},
	"regen": {"name": "Regeneration", "desc": "+0.5 HP per second", "max": 5},
	"magnet": {"name": "Magnetism", "desc": "+30% pickup range", "max": 5},
}

const HEAL := {"id": "heal", "title": "Second Wind", "desc": "Restore 40% of max HP"}


static func level_of(id: String, stats: PlayerStats) -> int:
	return stats.upgrade_levels.get(id, 0)


## Up to `n` random upgrades that aren't maxed out, as
## [{id, title, desc}]. Falls back to a heal if the pool runs dry.
static func roll(stats: PlayerStats, n := 3) -> Array[Dictionary]:
	var pool: Array[String] = []
	for id: String in DEFS:
		if level_of(id, stats) < DEFS[id]["max"]:
			pool.append(id)
	pool.shuffle()

	var out: Array[Dictionary] = []
	for id in pool.slice(0, n):
		var lvl := level_of(id, stats)
		out.append({
			"id": id,
			"title": "%s  (Lv %d)" % [DEFS[id]["name"], lvl + 1],
			"desc": _describe(id, lvl),
		})
	if out.is_empty():
		out.append(HEAL)
	return out


static func _describe(id: String, current_level: int) -> String:
	if id == "aura" and current_level > 0:
		return "+15% radius, +30% damage"
	return DEFS[id]["desc"]


static func apply(id: String, s: PlayerStats) -> void:
	if id == "heal":
		s.hp = minf(s.max_hp, s.hp + s.max_hp * 0.4)
		return
	s.upgrade_levels[id] = level_of(id, s) + 1
	match id:
		"bolt_damage":
			s.bolt_damage *= 1.25
		"bolt_rate":
			s.bolt_cooldown *= 0.85
		"bolt_count":
			s.bolt_count += 1
		"bolt_pierce":
			s.bolt_pierce += 1
		"aura":
			s.aura_level += 1
			if s.aura_level > 1:
				s.aura_radius *= 1.15
				s.aura_damage *= 1.3
		"move_speed":
			s.move_speed *= 1.1
		"max_hp":
			s.max_hp += 25.0
			s.hp = minf(s.max_hp, s.hp + 25.0)
		"regen":
			s.regen += 0.5
		"magnet":
			s.pickup_radius *= 1.3
