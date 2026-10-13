extends SceneTree
## Read-only guide and real rebinding UI; disposable settings, no player profile.
var checks:=0
var failures:=0
var output:=""
var main: Node
func _initialize() -> void:
 MetaProgress.disabled=true;MetaProgress.settings=MetaProgress.SETTINGS.duplicate(true)
 Realm.in_title=false;Realm.current="graveyard";Realm.daily=false;root.size=Vector2i(1280,720);seed(60164)
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 _run.call_deferred()
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL: "+message)
func frames(n:=3) -> void:
 for i in n:await process_frame
func action(id: String) -> void:
 var e:=InputEventAction.new();e.action=id;e.pressed=true;Input.parse_input_event(e);await frames()
 e=InputEventAction.new();e.action=id;e.pressed=false;Input.parse_input_event(e);await frames()
func key(code: int) -> void:
 var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await frames()
 e=InputEventKey.new();e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e);await frames()
func inside(c: Control) -> bool:return root.get_visible_rect().grow(1).encloses(c.get_global_rect())
func snap(name: String) -> void:
 if output=="" or DisplayServer.get_name()=="headless":return
 DirAccess.make_dir_recursive_absolute(output);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func _run() -> void:
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main;await frames();main.set_process(false)
 var pause: PauseMenu=main._pause
 var stats: PlayerStats=main._player.stats
 for i in 4:Upgrades.apply("bolt_damage",stats)
 var baseline:=stats._mods.duplicate(true);var ranks:=stats.upgrade_levels.duplicate(true);var hp:=stats.hp
 var fixed_before: Dictionary={}
 for pair: Array in Controls.ACTIONS:
  fixed_before[pair[0]]=InputMap.action_get_events(pair[0]).filter(func(e: InputEvent) -> bool:return not e is InputEventKey or (e.physical_keycode if e.physical_keycode!=0 else e.keycode) in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT])
 for size in [Vector2i(1024,576),Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=size;await frames();await action("ui_cancel")
  pause._guide_button.pressed.emit();await frames()
  var guide: BuildGuidePanel=pause._guide_panel
  check(paused and guide.visible and inside(guide._scroll) and inside(guide._details_scroll) and inside(guide._back),"guide columns and Back fit "+str(size))
  check(guide._next_step.text=="Take 4 more Sharper Bolts cards and 1 Piercing Bolts card.","next step uses actual missing card ranks")
  guide._set_pinned("")
  var body: Button=guide._row_by_id["soul_lance"].get_child(0)
  body.grab_focus();await action("ui_right")
  check(root.gui_get_focus_owner()==guide._pin_by_id["soul_lance"],"keyboard moves from recipe to its pin")
  await action("ui_accept");check(pause.pinned_evolution=="soul_lance" and guide._detail_name.text.contains("pinned"),"pin is explicit and details reflect it")
  await action("ui_right");check(root.gui_get_focus_owner()==guide._details_scroll,"keyboard reaches detail preview")
  guide._details.text += "\nA long preview line.".repeat(40);await frames();await action("ui_down")
  check(guide._details_scroll.scroll_vertical>0 and inside(guide._back),"long details scroll by keyboard without hiding Back")
  await snap("Guide_"+str(size.x))
  await action("ui_cancel");check(paused and pause._main_box.visible,"guide cancel returns to Pause")
  pause._show_controls(true);await frames()
  check(pause._binding_buttons.size()==Controls.ACTIONS.size(),"every binding is present")
  for b: Button in pause._binding_buttons.values():check(inside(b),"binding stays visible "+b.name+" "+str(size))
  var dash: Button=pause._binding_buttons["dash"]
  var original:=Controls.key_code("dash")
  dash.grab_focus();await action("ui_accept")
  check(pause._listening=="dash" and root.gui_get_focus_owner()==pause._binding_buttons["dash"],"listening retains edited row focus")
  await key(KEY_ESCAPE)
  check(pause._listening=="" and Controls.key_code("dash")==original and pause._controls_feedback.contains("unchanged"),"Escape cancels binding without closing Controls")
  pause._binding_buttons["dash"].pressed.emit();await frames();await key(KEY_F)
  check(Controls.key_code("dash")==KEY_F and pause._controls_feedback.contains("F") and root.gui_get_focus_owner()==pause._binding_buttons["dash"],"binding applies and keeps edited row focus")
  var previous_interact:=Controls.key_code("interact")
  pause._binding_buttons["dash"].pressed.emit();await frames();await key(previous_interact)
  check(Controls.key_code("dash")==previous_interact and Controls.key_code("interact")==KEY_F,"used key swaps existing primary bindings")
  check(pause._controls_feedback.contains("Use moved to F") and Controls.tag("interact")=="[F]","swap notice and current hint match actual mapping")
  await snap("Controls_"+str(size.x))
  var stale: Button=pause._binding_buttons["dash"]
  pause._fill_controls();stale.pressed.emit();check(pause._listening=="","detached binding button cannot restart capture")
  var reset: Button=null
  var back: Button=null
  for b: Button in pause._controls_box.find_children("*","Button",true,false):
   if b.text=="Reset to defaults":reset=b
   if b.text=="Back":back=b
  check(reset!=null and back!=null and inside(reset) and inside(back),"Reset and Back visible without scrolling")
  reset.pressed.emit();await frames();check(Controls.key_code("dash")==original and pause._controls_feedback.contains("defaults"),"reset uses original defaults and clear feedback")
  await action("ui_cancel");check(paused and pause._main_box.visible,"Controls close returns to Pause")
  await action("ui_cancel");check(not paused,"Resume returns to play")
 check(stats._mods==baseline and stats.upgrade_levels==ranks and stats.hp==hp,"all guide views and pins preserve player stats")
 for pair: Array in Controls.ACTIONS:
  var fixed=InputMap.action_get_events(pair[0]).filter(func(e: InputEvent) -> bool:return not e is InputEventKey or (e.physical_keycode if e.physical_keycode!=0 else e.keycode) in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT])
  check(fixed==fixed_before[pair[0]],"arrow/controller alternatives unchanged "+str(pair[0]))
 root.size=Vector2i(1280,720);await frames();await action("ui_cancel");pause._guide_button.pressed.emit();await frames()
 var guide: BuildGuidePanel=pause._guide_panel
 var ready:=PlayerStats.new()
 for id in ["soul_lance","absolute_zero"]:
  var d: Dictionary=Evolutions.DEFS[id]
  for i in Upgrades.DEFS[d["weapon"]]["max"]:Upgrades.apply(d["weapon"],ready)
  Upgrades.apply(d["catalyst"],ready)
 guide.present(ready);await frames();guide._present_details("soul_lance")
 check(guide._next_step.text.contains("randomly offered") and guide._next_step.text.contains(str(Evolutions.ready(ready).size())),"multiple ready recipes preserve random-offer rule")
 Upgrades.apply("evo:soul_lance",ready);guide.present(ready);await frames();guide._present_details("soul_lance")
 check(guide._next_step.text.contains("Already evolved"),"evolved recipe does not promise another upgrade")
 for row: Dictionary in guide._rows:
  guide._present_details(row["id"]);await frames()
  check(guide._details.text.contains(BuildGuide.affected_text(row["id"],ready)) and inside(guide._back),"exact preview and accessible Back: "+str(row["id"]))
 var almost:=PlayerStats.new()
 for i in 7:Upgrades.apply("bolt_damage",almost)
 guide.present(almost);await frames();guide._present_details("soul_lance")
 check(guide._next_step.text=="Take 1 more Sharper Bolts card and 1 Piercing Bolts card.","singular weapon and catalyst instructions")
 Upgrades.apply("bolt_pierce",almost);guide.present(almost);await frames();guide._present_details("soul_lance")
 check(guide._next_step.text=="Take 1 more Sharper Bolts card.","owned catalyst is not requested again")
 Upgrades.apply("bolt_damage",almost);guide.present(almost);await frames();guide._present_details("soul_lance")
 check(guide._next_step.text=="Ready for the next level-up.","single ready evolution has precise offer rule")
 guide.present(null);await frames();check(guide._details.text=="" and guide._detail_name.text=="No compatible recipes","empty guide clears stale detail")
 guide.present(stats,null,"soul_lance");var stale_pin: CheckButton=guide._pin_by_id["absolute_zero"]
 guide.present(stats,null,"soul_lance");stale_pin.toggled.emit(true)
 check(guide._pinned_id=="soul_lance","stale pin does not change new guide state")
 for i in 3:pause._show_build_guide(false);pause._show_build_guide(true)
 pause.close();await frames();check(not paused,"rapid guide reopen/close has no deferred focus error")
 Controls.reset();main.free();Elements.reset();Juice.reset();await frames()
 print("GUIDE CONTROLS: %d checks, %d failures" % [checks,failures]);quit(0 if failures==0 else 1)
