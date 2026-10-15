extends SceneTree
## Real input and scene transitions; unique disposable saves, no player profiles.
var checks := 0
var failures := 0
var output := ""
var movie := false
var main: Node
var tag := "user://menu-continuity-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
func _initialize() -> void:
 MetaProgress.disabled = true
 MetaProgress.settings = MetaProgress.SETTINGS.duplicate(true)
 MetaProgress.settings["calm"] = true
 RunSave.path = tag + "-run.save"; CampaignSave.path = tag + "-campaign.save"; MetaProgress.save_path = tag + "-meta.save"
 RunSave.pending = {}; Realm.in_title = true; Realm.current = "graveyard"; Realm.daily = false
 root.size = Vector2i(1280,720); seed(15162)
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
  elif arg == "--movie": movie = true
 _run.call_deferred()
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures += 1; push_error("FAIL: " + message)
func frames(n:=3) -> void:
 for i in n: await process_frame
func action(id: String) -> void:
 var e := InputEventAction.new();e.action=id;e.pressed=true;Input.parse_input_event(e);await frames()
 e=InputEventAction.new();e.action=id;e.pressed=false;Input.parse_input_event(e);await frames()
func snap(name: String) -> void:
 if movie: await frames(90)
 if output == "" or DisplayServer.get_name() == "headless": return
 DirAccess.make_dir_recursive_absolute(output)
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func inside(c: Control) -> bool:
 return root.get_visible_rect().grow(1).encloses(c.get_global_rect())
func choices(stats: PlayerStats) -> Array[Dictionary]:
 var cards: Array[Dictionary]=[]
 for id in ["bolt_damage","lightning","aura"]:
  var c: Dictionary=Upgrades.DEFS[id].duplicate(true);c["id"]=id;c["level"]=1;c["affected"]=BuildGuide.affected_text(id,stats);cards.append(c)
 return cards
func _run() -> void:
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main;await frames()
 check(main._title.is_open(),"real start screen is open")
 await snap("Start")
 main._title._show_selection("classic");await frames();main._title._first_realm.grab_focus();await action("ui_accept");main=current_scene
 check(not main._in_title and not paused and main._hud.visible,"keyboard Classic choice mounts running Main")
 main.set_process(false)
 if not movie:
  await action("ui_cancel")
  main._pause._quit_button.pressed.emit();await frames()
  main._pause._exit_accept.grab_focus();await action("ui_accept")
  main=current_scene
  check(main._title.is_open() and not paused,"confirmed Classic abandon returns to the actual title")
  main._title._show_selection("classic");await frames();main._title._first_realm.grab_focus();await action("ui_accept");main=current_scene;main.set_process(false)
  check(not main._in_title,"a new run starts normally after confirmed abandon")
 var hud: Hud=main._hud;var pause: PauseMenu=main._pause
 if not movie:
  for size in [Vector2i(1024,576),Vector2i(1280,720),Vector2i(1920,1080)]:
   root.size=size;await frames()
   await action("ui_cancel");check(paused and pause.is_open(),"Escape opens Pause "+str(size))
   for b: Button in [pause._resume,pause._save_button,pause._quit_button]:check(inside(b),"primary action visible without scrolling "+str(size))
   check(root.gui_get_focus_owner()==pause._resume and pause._page_scroll.scroll_vertical==0,"Resume focused at top")
   check(pause._campaign_notice.text.contains("Unfinished chests and rituals"),"Classic save limitation stays visible")
   pause._quit_button.pressed.emit();await frames()
   check(pause._exit_confirmation.visible and pause._exit_cancel.has_focus(),"destructive action opens cancel-focused confirmation")
   for i in 4:await action("ui_focus_next")
   check(pause._exit_confirmation.is_ancestor_of(root.gui_get_focus_owner()),"Tab stays inside destructive confirmation")
   await action("ui_cancel")
   pause._exit_accept.pressed.emit()
   check(paused and pause.is_open() and not pause._exit_confirmation.visible and current_scene==main,"cancel keeps the current run paused and intact")
   pause._show_controls(true);await frames()
   check(root.gui_get_focus_owner()!=null and pause._controls_box.is_ancestor_of(root.gui_get_focus_owner()),"Controls gives keyboard focus to a key")
   await action("ui_cancel")
   check(paused and pause._main_box.visible and root.gui_get_focus_owner()==pause._resume,"Controls cancellation returns focus without resuming")
   pause._guide_button.pressed.emit();await frames();await action("ui_cancel")
   check(paused and pause._main_box.visible,"Guide cancellation keeps game paused")
   pause._resume.grab_focus();await action("ui_accept");check(not paused and not pause.is_open(),"Resume restores play")
   hud.show_upgrades(choices(main._player.stats),2,"LEVEL UP","Choose a power · 1 / 2 / 3",2);paused=true;await frames()
   for card: Button in hud._upgrade_row.get_children():
    check(inside(card) and card.scale==Vector2.ONE,"stable upgrade card in bounds "+str(size))
    var col:=card.get_child(0) as Control
    check(card.size.y>=col.get_combined_minimum_size().y+31,"card contains all preview text")
   check(inside(hud._reroll_button) and hud._reroll_button.focus_mode==Control.FOCUS_ALL,"reroll is visible and keyboard focusable")
   hud._upgrade_root.hide();paused=false
  root.size=Vector2i(1280,720);await frames()
  # Duplicate/stale activation cannot spend the same choice twice.
  var picked: Array[String]=[]
  var listener:=func(id: String) -> void:picked.append(id)
  hud.upgrade_chosen.connect(listener)
  hud.show_upgrades(choices(main._player.stats));await frames()
  var stale:=hud._upgrade_row.get_child(0) as Button
  hud.show_upgrades(choices(main._player.stats));stale.pressed.emit()
  check(picked.is_empty(),"stale card cannot select a replacement offer")
  var active:=hud._upgrade_row.get_child(0) as Button
  active.pressed.emit();active.pressed.emit();check(picked.size()==1,"double click chooses exactly once")
  hud.upgrade_chosen.disconnect(listener)
  # Every real upgrade description/affected preview fits its own growing card.
  for id: String in Upgrades.DEFS:
   var card: Dictionary=Upgrades.DEFS[id].duplicate(true);card["id"]=id;card["level"]=1;card["affected"]=BuildGuide.affected_text(id,main._player.stats)
   hud.show_upgrades([card]);await frames(2)
   var view:=hud._upgrade_row.get_child(0) as Button
   check(view.size.y>=(view.get_child(0) as Control).get_combined_minimum_size().y+31,"real text fits: "+id)
  hud._upgrade_root.hide();paused=false
 # Isolated Pause checks the accepted action emits once, including campaign wording.
 var isolated := PauseMenu.new();root.add_child(isolated);isolated.campaign_mode=true;isolated.open()
 var exits: Array[int]=[];isolated.quit_to_title.connect(func() -> void:exits.append(1))
 isolated._quit_button.pressed.emit();await frames()
 check(isolated._exit_message.text.contains("Unbanked") and isolated._exit_accept.text=="Retreat","campaign confirmation describes real forfeiture")
 isolated._exit_accept.pressed.emit();isolated._exit_accept.pressed.emit()
 check(exits.size()==1,"double confirmation emits one exit")
 isolated.free();await frames()
 # Render the actual flow: Pause -> earned XP choice -> real reward reveal -> death -> title.
 await action("ui_cancel");await snap("Pause")
 pause._quit_button.pressed.emit();await frames();await snap("Cancel_Abandon");await action("ui_cancel")
 await action("ui_cancel")
 main._rerolls=2;main._banishes_left=2
 main._player.add_xp(main._player.stats.xp_to_next)
 await frames();check(main._choosing_upgrade and paused,"XP threshold opens actual level-up menu")
 await snap("Upgrade")
 var selected: String=hud._upgrade_ids[0]
 var before:=Upgrades.level_of(selected,main._player.stats)
 await action("ui_accept")
 check(not paused and not main._choosing_upgrade and Upgrades.level_of(selected,main._player.stats)==before+1,"keyboard upgrade grants one rank and resumes")
 # Accelerated reward boundary: real chest spawns, fixture defeats its guards,
 # and the unchanged director grant path updates shards, loot and the reveal.
 var events: EventDirector=main._events
 events._start_chest(main._player.pos2)
 var chest: Dictionary=events._events[-1]
 events._update_chest(chest,main._player.pos2)
 check(not chest["guards"].is_empty(),"real chest spawned its guards")
 for g: Array in chest["guards"]:
  var swarm: EnemySwarm=g[0]
  for k in swarm.count:
   if swarm.ids[k]==g[1]:swarm.damage(k,100000)
 var shards_before:=events.shards
 events._update_chest(chest,main._player.pos2)
 events._update_chest(chest,main._player.pos2)
 check(chest["paid"] and events.shards==shards_before+5 and hud._reward_reveal_shown,"reward grant once and actual reveal")
 await snap("Reward")
 hud.dismiss_reward()
 main._player.invulnerable=false;main._player.shield_left=0;main._player.recovery_charge=false
 main._player.take_damage(100000,"UI transition test")
 for i in 240:
  if main._dying>0:main._death_frame(1.0/60.0)
 await frames();check(main._game_over and hud._game_over_root.visible,"damage uses real end-run screen")
 check(hud._toasts.get_children().all(func(n: Control) -> bool:return not n.visible or bool(n.get_meta("important",false))),"ordinary combat notices do not overlap end-run actions")
 await snap("End")
 var realms: Button=null
 for b: Button in hud._restart_button.get_parent().get_children():
  if b.text=="Choose realm":realms=b
 check(realms!=null and inside(realms),"return action stays visible outside report scroll")
 if realms:realms.grab_focus();await action("ui_accept")
 main=current_scene;check(main._title.is_open() and not paused,"end-run return reloads clean title")
 await snap("Return_Title")
 main._title._show_selection("campaign");await frames();main._title._campaign_new.grab_focus();await action("ui_accept")
 var shell:=current_scene as CampaignShell
 check(shell!=null and shell.controller.state["phase"]=="TOWN","title New Campaign reaches actual town hub")
 if shell:
  await snap("Hub")
  check(shell._view!=null and not paused,"hub is live after end-run return")
  shell.free();current_scene=null
 await frames();Elements.reset();Juice.reset()
 for base in [RunSave.path,CampaignSave.path,MetaProgress.save_path]:
  for suffix in ["",".bak",".previous",".rollback",".tmp"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(base+suffix))
 print("MENU CONTINUITY: %d checks, %d failures" % [checks,failures]);quit(0 if failures==0 else 1)
