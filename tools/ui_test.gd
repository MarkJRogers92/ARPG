extends SceneTree
## Drives the real inventory screen through the real input action, headless.
##
##   godot --headless --path . -s tools/ui_test.gd
##
## Exit code 0 on success.

var _main: Node
var _frame := 0
var _failures := 0
var _player: Player
var _screen: InventoryScreen
var _weak: Item
var _strong: Item
var _helm: Item


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", message])


func _press_action(action: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		Input.parse_input_event(e)


func _process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		2:
			_player = _main.get_node("Player")
			_screen = _main.get_node("InventoryScreen")
			_main.get_node("WaveDirector").base_rate = 0.0
			_main.get_node("WaveDirector").rate_growth = 0.0
			_weak = ItemGenerator.generate_with(5, ItemData.Rarity.NORMAL, "weapon")
			_weak.implicit.assign([{"stat": "bolt_damage", "op": PlayerStats.Op.ADD, "value": 1.0}])
			_strong = ItemGenerator.generate_with(5, ItemData.Rarity.RARE, "weapon")
			_strong.implicit.assign([{"stat": "bolt_damage", "op": PlayerStats.Op.ADD, "value": 20.0}])
			_helm = ItemGenerator.generate_with(5, ItemData.Rarity.MAGIC, "helm")
			_player.inventory.pickup(_weak)
			_player.inventory.pickup(_strong)
			_player.inventory.pickup(_helm)
			print("opening the screen with the inventory key")
			_press_action("inventory")
		4:
			_check(_screen.is_open(), "inventory key opens the screen")
			_check(paused, "game is paused while open")
			_check(_screen._backpack_list.item_count == 1 and _screen._equipment_list.item_count == 6,
					"lists show 1 carried item and 6 slots (carried=%d)" % _screen._backpack_list.item_count)
			_check(_player.inventory.equipped.get("weapon") == _weak and _player.inventory.equipped.get("helm") == _helm,
					"weak weapon and helm were auto-worn, strong weapon carried")
			_check(_screen._backpack_list.get_item_text(0).begins_with("▲"), "carried weapon is flagged as an upgrade")
			print("selecting the carried weapon")
			_screen._backpack_list.select(0)
			_screen._backpack_list.item_selected.emit(0)
		6:
			_check(_screen._selected == _strong and not _screen._selected_worn, "selection tracks the carried weapon")
			_check(not _screen._equip_button.disabled and _screen._equip_button.text == "Equip", "Equip button is ready")
			_check(_screen._details.text.contains("Likely upgrade"), "details call it a likely upgrade")
			var before := _player.stats.bolt_damage
			_screen._equip_button.pressed.emit()
			_check(_player.inventory.equipped["weapon"] == _strong, "pressing Equip wears it")
			_check(_player.stats.bolt_damage > before + 15.0, "stats updated (%.1f -> %.1f)" % [before, _player.stats.bolt_damage])
			_check(_player.inventory.backpack.has(_weak), "old weapon moved to the backpack")
			_check(_screen._selected == _strong and _screen._selected_worn and _screen._equip_button.text == "Unequip",
					"selection follows the item to the equipment list")
		8:
			print("discarding the old weapon")
			_screen._backpack_list.select(0)
			_screen._backpack_list.item_selected.emit(0)
			_check(_screen._selected == _weak and not _screen._discard_button.disabled, "Discard is enabled for carried items")
			_screen._discard_button.pressed.emit()
			_check(_player.inventory.backpack.is_empty() and _screen._backpack_list.item_count == 0, "discarded item is gone")
			_check(_screen._details.text.contains("Select an item"), "details reset")
		10:
			print("closing with the inventory key")
			_press_action("inventory")
		12:
			_check(not _screen.is_open(), "inventory key closes the screen")
			_check(not paused, "game is running again")
			print("")
			print("UI TEST %s" % ("PASSED" if _failures == 0 else "FAILED (%d)" % _failures))
			quit(0 if _failures == 0 else 1)
	return false
