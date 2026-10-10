class_name DecorCompositions
extends RefCounted
## Authored X/Z layouts. One primary slot owns the entire place; members are
## static set dressing, not additional gameplay/landmark selection rolls.
## A mirrored variant preserves coherent fronts and the same approach clearance.

const RADIUS := 5.2
## Stop broad approaches short of the chunk edge, leaving room for bodies to
## pass even beside a neighbouring legacy obstacle at its minimum inset.
const APPROACH_END := 4.45

static func layout(kind: String, variant: int = 0) -> Dictionary:
	var id := ""
	var at := Vector2.ZERO
	var yaw := 0.0
	var members: Array[Dictionary] = []
	var lanes: Array[Dictionary] = []
	var pads: Array[Dictionary] = []
	match kind:
		"warden_soul_altar", "warden_ritual_circle", "warden_sarcophagus", "warden_bone_barricade", "warden_grave_fence", "warden_mausoleum":
			id = "graveyard_mausoleum_court" if kind == "warden_mausoleum" else "graveyard_burial_plot"
			at = Vector2(0, -1.7)
			# Two aligned grave rows frame a central aisle, with lamps at the rear.
			for x: float in [-1.8, 1.8]:
				for z: float in [0.4, 2.1]:
					members.append(_m("warden_gravestone", Vector2(x, z)))
			members.append(_m("warden_soul_lantern", Vector2(-2.6, -1.4)))
			members.append(_m("warden_soul_brazier", Vector2(2.6, -1.4)))
			if kind == "warden_mausoleum":
				# Single side segments: never tile duplicate terminal posts.
				members.append(_m("warden_grave_fence", Vector2(-3.6, 1.3), PI * 0.5))
				members.append(_m("warden_grave_fence", Vector2(3.6, 1.3), PI * 0.5))
			else:
				members.append(_m("warden_reliquary_chest", Vector2(-2.5, -3.2)))
				members.append(_m("warden_broken_obelisk", Vector2(2.5, -3.2)))
			lanes = [_lane(Vector2(0, APPROACH_END), Vector2(0, 1.1 if kind == "warden_mausoleum" else 0.4))]
			pads = [_pad(Vector2(0, -0.2), Vector2(6.8, 6.6), "graveyard")]
		"warden_iron_gate":
			id = "graveyard_private_plot"
			at = Vector2(-2.7, -0.8)
			yaw = PI * 0.5 # The sealed gate closes a side plot, not the public aisle.
			members = [_m("warden_grave_fence", Vector2(-2.7, 2.0), PI * 0.5),
				_m("warden_grave_fence", Vector2(3.5, 0.6), PI * 0.5),
				_m("warden_gravestone", Vector2(1.6, -1)), _m("warden_gravestone", Vector2(1.6, 1)),
				_m("warden_soul_lantern", Vector2(-1.6, -3)), _m("warden_broken_obelisk", Vector2(2.8, -2.8)),
				_m("warden_reliquary_chest", Vector2(-0.5, -2.8))]
			lanes = [_lane(Vector2(0, APPROACH_END), Vector2(0, -0.6), 1.9)]
			pads = [_pad(Vector2(0, -0.3), Vector2(6.5, 6.2), "graveyard")]
		"wastes_frost_shrine":
			id = "wastes_shrine_trail"
			at = Vector2(0, -1.9)
			members = [_m("wastes_dead_pine", Vector2(-3, -2.4)), _m("wastes_dead_pine", Vector2(3, -2.4)),
				_m("wastes_ice_barricade", Vector2(0, -4)),
				_m("wastes_glacial_cluster", Vector2(-2.05, 0)), _m("wastes_rune_cairn", Vector2(2.05, 0)),
				_m("wastes_glacial_cluster", Vector2(-2.05, 2.4)), _m("wastes_rune_cairn", Vector2(2.05, 2.4))]
			lanes = [_lane(Vector2(0, APPROACH_END), Vector2(0, -0.1))]
			pads = [_pad(Vector2(0, -1.1), Vector2(6, 4.5), "frozen")]
		"wastes_supply_sled":
			id = "wastes_sheltered_supply_camp"
			at = Vector2(-1.65, -1.3)
			members = [_m("wastes_dead_pine", Vector2(-3.5, 1.6)), _m("wastes_dead_pine", Vector2(2.6, -2.7)),
				_m("wastes_ice_barricade", Vector2(-0.7, -3.9)),
				_m("wastes_glacial_cluster", Vector2(2.9, 1.7)), _m("wastes_rune_cairn", Vector2(2.9, -0.8))]
			lanes = [_lane(Vector2(0.6, APPROACH_END), Vector2(0.6, -1.2))]
			pads = [_pad(Vector2(0, -0.6), Vector2(6.8, 5.4), "frozen")]
		"wastes_ice_barricade":
			id = "wastes_open_snow_track"
			at = Vector2(-2.6, -0.7)
			yaw = PI * 0.5
			members = [_m("wastes_supply_sled", Vector2(2.4, -1.6)),
				_m("wastes_dead_pine", Vector2(-2.7, 2.2)), _m("wastes_dead_pine", Vector2(2.7, 2.3)),
				_m("wastes_glacial_cluster", Vector2(-1.9, -3)), _m("wastes_rune_cairn", Vector2(1.8, -3.6))]
			lanes = [_lane(Vector2(0, APPROACH_END), Vector2(0, -3.3), 2.0)]
			pads = [_pad(Vector2.ZERO, Vector2(6, 5), "frozen")]
		"rift_archway":
			id = "rift_waystone_approach"
			at = Vector2(0, -1.65)
			members = [_m("rift_ashen_tree", Vector2(-3, -2.5)), _m("rift_ashen_tree", Vector2(3, -2.5)),
				_m("rift_magma_vent", Vector2(2.1, 0.3)),
				_m("rift_scorched_waystone", Vector2(-2.3, 2.5)), _m("rift_scorched_waystone", Vector2(2.3, 2.5)),
				_m("rift_obsidian_barricade", Vector2(-3.6, 0), PI * 0.5)]
			# Approach stops before the arch. Its narrow original opening is unchanged.
			lanes = [_lane(Vector2(0, APPROACH_END), Vector2(0, 0.4))]
			pads = [_pad(Vector2(0, -0.3), Vector2(6, 6.5), "ember")]
		"rift_crucible_forge":
			id = "rift_open_forge_yard"
			at = Vector2(-1.8, -1.4)
			members = [_m("rift_obsidian_barricade", Vector2(-0.4, -3.8)),
				_m("rift_ashen_tree", Vector2(-3.35, 2.1)), _m("rift_ashen_tree", Vector2(2.8, -2.4)),
				_m("rift_magma_vent", Vector2(2.6, 0.2)), _m("rift_magma_vent", Vector2(-2.8, 0.2)),
				_m("rift_scorched_waystone", Vector2(2.6, 2.4))]
			lanes = [_lane(Vector2(0.4, APPROACH_END), Vector2(0.4, -1.4))]
			pads = [_pad(Vector2(0, -0.5), Vector2(6.5, 5.8), "ember")]
		"rift_obsidian_barricade":
			id = "rift_scorched_workyard"
			at = Vector2(0, -3)
			members = [_m("rift_crucible_forge", Vector2(-2.5, -1.1)), _m("rift_magma_vent", Vector2(2.4, -1.1)),
				_m("rift_scorched_waystone", Vector2(-2.1, 0.8)), _m("rift_scorched_waystone", Vector2(2.1, 0.8)),
				_m("rift_ashen_tree", Vector2(-3.35, 2.4)), _m("rift_ashen_tree", Vector2(3.35, 2.4))]
			lanes = [_lane(Vector2(0, APPROACH_END), Vector2(0, -1.25))]
			pads = [_pad(Vector2(0, -0.3), Vector2(6.5, 6), "ember")]
		_:
			return {}
	if posmod(variant, 2) == 1:
		at.x = -at.x
		yaw = -yaw
		for member: Dictionary in members:
			member["at"] = Vector2(-member["at"].x, member["at"].y)
			member["yaw"] = -float(member["yaw"])
		for lane: Dictionary in lanes:
			lane["a"] = Vector2(-lane["a"].x, lane["a"].y)
			lane["b"] = Vector2(-lane["b"].x, lane["b"].y)
		for pad: Dictionary in pads:
			pad["at"] = Vector2(-pad["at"].x, pad["at"].y)
	return {"id": id, "anchor_at": at, "anchor_yaw": yaw, "radius": RADIUS, "members": members, "lanes": lanes, "pads": pads}


static func _m(kind: String, at: Vector2, yaw: float = 0.0) -> Dictionary:
	return {"kind": kind, "at": at, "yaw": yaw, "scale": 1.0}


static func _lane(a: Vector2, b: Vector2, width: float = 2.2) -> Dictionary:
	return {"a": a, "b": b, "width": width}


static func _pad(at: Vector2, size: Vector2, style: String) -> Dictionary:
	return {"at": at, "size": size, "yaw": 0.0, "style": style}
