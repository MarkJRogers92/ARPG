class_name CampaignGuidance
extends RefCounted
## Short, presentation-only directions for campaign combat. All state is
## supplied by the authoritative expedition and final-mechanics directors.


static func contract_action(contract_id: String, seals: int, elite_spawned: bool,
		elite_dead: bool, cache_claimed: bool, guardian_arrived: bool) -> String:
	if contract_id == "finale":
		return "The countdown needs no interaction; stay alive." if not guardian_arrived else ""
	match contract_id:
		"breach", "seal_breach":
			return "Use %s at each marked seal to close it." % Controls.tag("interact") if seals < 3 else "All seals closed; survive until extraction."
		"elite_hunt":
			if elite_dead:
				return "Target defeated; survive until extraction."
			return "The marked target arrives at 5:00; stay alive until then." if not elite_spawned else "Defeat the marked elite before the deadline."
		"cursed_cache":
			return "Optional: use %s at the marked cache to claim it." % Controls.tag("interact") if not cache_claimed else "Cache claimed; survive until extraction."
		"hunt":
			return "Extraction is automatic; no site needs interaction."
	return ""


static func guardian_intro(kind: String) -> String:
	match kind:
		"lich":
			return "Soul wards make him invulnerable. Destroy the phylacteries when they rise."
		"colossus":
			return "Step off the fracture lines; after they strike, attack during his exposure."
		"tyrant":
			return "His cinder seals shield him. Lure each meteor onto a seal to break it."
	return ""


static func guardian_hint(kind: String, mechanic_hint: String, fracture_lines: int) -> String:
	if mechanic_hint != "":
		return mechanic_hint
	if kind == "colossus" and fracture_lines > 0:
		return "Fracture lines are forming. Step off them."
	return ""
