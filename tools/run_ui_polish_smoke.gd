extends "res://tools/sealbound_chest_smoke.gd"
## Same real-combat proof plus a paused inventory inspection using actual UI input.
## Adds a controlled Cap/Circlet pair. Inspection is canceled; no gear is equipped.
var ui_frame:=0
var ui_tab_seen:=false
var ui_inspected:=false
var ui_closed:=false
func _start() -> void:
	super._start()
	var old:=Item.new();old.slot="helm";old.name="Gravekeeper Cap";old.base_name="Cap";old.rarity=ItemData.Rarity.MAGIC
	old.implicit.assign([{"stat":"max_hp","op":PlayerStats.Op.ADD,"value":60.0},{"stat":"armor","op":PlayerStats.Op.ADD,"value":20.0}]);player.inventory.pickup(old)
	var candidate:=Item.new();candidate.slot="helm";candidate.name="Eye of the Storm";candidate.base_name="Circlet";candidate.rarity=ItemData.Rarity.LEGENDARY;candidate.power="storm_eye"
	candidate.implicit.assign([{"stat":"max_hp","op":PlayerStats.Op.ADD,"value":20.0},{"stat":"armor","op":PlayerStats.Op.ADD,"value":5.0}]);player.inventory.pickup(candidate)
func _ui_action(id: String) -> void:
	var event:=InputEventAction.new();event.action=id;event.pressed=true;Input.parse_input_event(event)
	event=InputEventAction.new();event.action=id;event.pressed=false;Input.parse_input_event.call_deferred(event)
func _process(delta: float) -> bool:
	if main==null or done:return false
	if ui_frame<300:
		ui_frame+=1
		match ui_frame:
			30:_ui_action("inventory")
			35:
				main._inventory_screen._backpack_list.select(0);main._inventory_screen._backpack_list.item_selected.emit(0)
				ui_inspected=main._inventory_screen.is_open() and paused
			90:_capture.call_deferred("Equipment_Interaction")
			150:
				main._inventory_screen._detail_tabs.get_tab_bar().grab_focus();_ui_action("ui_right")
			155:ui_tab_seen=main._inventory_screen._detail_tabs.current_tab==1
			210:_ui_action("ui_left")
			270:_ui_action("ui_cancel")
			275:ui_closed=not main._inventory_screen.is_open() and not paused
		return false
	return super._process(delta)
func _finish() -> void:
	if done:return
	print("UI INTERACTION: ",JSON.stringify({"passed":ui_inspected and ui_tab_seen and ui_closed,"inventory_opened":ui_inspected,"item_rolls_tab_seen":ui_tab_seen,"canceled_without_swap":ui_closed and player.inventory.equipped.get("helm").name=="Gravekeeper Cap","fixture":"eight existing upgrade cards plus controlled Cap/Circlet pair; preview only; no injected damage"}))
	super._finish()
