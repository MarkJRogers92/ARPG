class_name CampaignWaystops
extends RefCounted
## Read-only mapping from committed campaign progress to its current town.

const BIOME_IDS := ["hollow_graveyard", "frozen_wastes", "ember_rift"]
const STOPS := [
	[
		{"name": "The Last Lantern", "kind": "lantern", "description": "A final warm light before the road descends into the Hollow Graveyard.", "arrival_line": "The lantern holds. Gather what you need before the road calls again."},
		{"name": "Gravediggers' Camp", "kind": "camp", "description": "A rough camp where grave crews trade maps, iron, and warnings.", "arrival_line": "The gravediggers make room by the fire and point you toward the next marked road."},
		{"name": "Bellwether Crossing", "kind": "village", "description": "A walled crossing whose bells warn the scattered hamlets of the dead.", "arrival_line": "Bellwether's bells ring you in; the road ahead is still open."},
		{"name": "Vigil of Ash", "kind": "monastery", "description": "A watchful monastery keeps the last ward against the graveyard's master.", "arrival_line": "The monks prepare the final ward. The graveyard's guardian is still ahead."},
	],
	[
		{"name": "Whitepass Refuge", "kind": "refuge", "description": "A stone refuge shelters travelers at the first pass into the Frozen Wastes.", "arrival_line": "Whitepass shuts its gates against the storm and welcomes you inside."},
		{"name": "Sledwright's Rest", "kind": "caravan", "description": "A caravan camp repairs runners and trades supplies beneath the ice cliffs.", "arrival_line": "The sledwrights patch your gear and mark a safer line through the snow."},
		{"name": "Rimewatch", "kind": "watchtower", "description": "A high watchtower tracks movement across the frozen ridges.", "arrival_line": "Rimewatch keeps its signal fire lit while you prepare for the next stretch."},
		{"name": "Chapel of the Thaw", "kind": "ice_chapel", "description": "An ancient ice chapel stands where the frozen realm's guardian waits.", "arrival_line": "The chapel keeps a flame for the thaw. First, the frozen guardian must fall."},
	],
	[
		{"name": "Cinderwake Outpost", "kind": "forge", "description": "A fortified forge gives the first foothold in the Ember Rift.", "arrival_line": "Cinderwake's furnaces are still burning. There is time to mend and prepare."},
		{"name": "Redwake Caravan", "kind": "caravan", "description": "A stubborn caravan follows the lava road with water, steel, and spare wheels.", "arrival_line": "Redwake rolls onward at dawn and leaves you a clear route through the ash."},
		{"name": "Coalhaven", "kind": "village", "description": "A black-stone settlement survives beneath the Rift's drifting cinders.", "arrival_line": "Coalhaven opens its shutters. Its people are waiting for the road to end."},
		{"name": "Gate of Embers", "kind": "siege", "description": "The final stronghold faces the Ember Rift's last guardian.", "arrival_line": "The final gate is braced for the Ember Rift's guardian. Dawn waits beyond."},
	],
]
const DAWN := {"name": "Dawn's Rest", "kind": "dawn", "description": "A quiet haven beyond the last guardian, where the road's survivors can rest.", "arrival_line": "The road is behind you. Dawn's Rest is yours to keep."}


static func resolve(state: Dictionary) -> Dictionary:
	var biome_index := clampi(int(state.get("biome_index", 0)), 0, BIOME_IDS.size() - 1)
	if bool(state.get("completed", false)):
		return _payload(DAWN, "waystop:dawn", biome_index, 4)
	var clears: Variant = state.get("cleared_nodes", [])
	var clear_count: int = clears.size() if clears is Array else 0
	var stage := clampi(clear_count, 0, 3)
	var definition: Dictionary = STOPS[biome_index][stage]
	return _payload(definition, "waystop:%s:%d" % [BIOME_IDS[biome_index], stage], biome_index, stage)


static func _payload(definition: Dictionary, stop_id: String, biome_index: int, stage: int) -> Dictionary:
	return {
		"id": stop_id,
		"name": str(definition["name"]),
		"biome_index": biome_index,
		"stage": stage,
		"kind": str(definition["kind"]),
		"description": str(definition["description"]),
		"arrival_line": str(definition["arrival_line"]),
	}
