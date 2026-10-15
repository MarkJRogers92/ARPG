extends SceneTree
## Actual Main pickup/inventory/combat flow with controlled starting gear/drop.
## No injected combat damage or invulnerability; no profile/save mutations.
var main: Node
func _initialize() -> void:
	MetaProgress.disabled=true;MetaProgress.settings=MetaProgress.SETTINGS.duplicate(true)
	Realm.in_title=false;Realm.daily=false;RunSave.pending={};RunSave.path="user://nearby-review.run"
	_run.call_deferred()
func hold(frames: int) -> void:
	for i in frames:await process_frame
func action(id: String) -> void:
	var ev:=InputEventAction.new();ev.action=id;ev.pressed=true;Input.parse_input_event(ev);await process_frame
	ev=InputEventAction.new();ev.action=id;ev.pressed=false;Input.parse_input_event(ev);await process_frame
func require(ok: bool,why: String) -> bool:
	if not ok:push_error(why);quit(1)
	return ok
func _run() -> void:
	seed(41391);main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
	await process_frame;root.size=Vector2i(1280,720)
	var player: Player=main._player;var inv:=player.inventory;var loot: LootManager=main._loot;var ui: InventoryScreen=main._inventory_screen
	var old:=ItemGenerator.generate_with(4,ItemData.Rarity.RARE,"weapon");inv.replace_worn(old)
	while not inv.is_full():inv.pickup(ItemGenerator.generate_with(3,ItemData.Rarity.MAGIC,"weapon"))
	var reward:=ItemGenerator.generate_with(12,ItemData.Rarity.LEGENDARY,"weapon")
	var node:=loot.drop(reward,player.pos2)
	await hold(60)
	if not require(loot.drops.has(node),"Full backpack leaves drop in actual Main"):return
	await action("inventory");ui._source_tabs.get_tab_bar().grab_focus();await action("ui_right");await hold(60)
	if not require(paused and ui._selected==reward and ui._equip_button.disabled,"Nearby comparison pauses and explains full capacity"):return
	ui._source_tabs.get_tab_bar().grab_focus();await action("ui_left");await hold(25)
	var discarded: Item=ui._selected
	ui._discard_button.grab_focus();await action("ui_accept");await hold(15)
	if not require(inv.backpack.size()==23 and not inv.backpack.has(discarded),"Only explicitly discarded carried item is removed"):return
	ui._source_tabs.get_tab_bar().grab_focus();await action("ui_right");await hold(40)
	ui._equip_button.grab_focus();await action("ui_accept");await hold(35)
	if not require(inv.backpack.count(reward)==1 and inv.equipped.weapon==old and ui._equip_button.disabled,"Chosen pickup succeeds once without equipping"):return
	ui._source_tabs.get_tab_bar().grab_focus();await action("ui_left")
	ui._backpack_list.select(inv.backpack.find(reward));ui._on_backpack_selected(inv.backpack.find(reward));await hold(25)
	ui._equip_button.grab_focus();await action("ui_accept");await hold(25)
	if not require(inv.equipped.weapon==reward and inv.backpack.has(old),"Separate equip preserves original weapon in full backpack"):return
	await action("ui_cancel")
	var elapsed: float=main.elapsed
	Input.action_press("move_right");await hold(45);Input.action_release("move_right");await hold(60)
	if not require(not paused and not player.dead and main.elapsed>elapsed+3.0,"Actual Main combat resumes after collection and equip"):return
	print("NEARBY REVIEW PASS: Main full-pack drop / compare / explicit discard / collect once / explicit equip / live movement. kills=",main.kills)
	main.queue_free();await hold(4);quit()
