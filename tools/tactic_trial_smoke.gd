extends SceneTree
## Full authored mission, natural spawning, kit only, no invulnerability. The
## bot follows a small circuit, dashes on cooldown, and takes useful legal cards.
var main: Node
var controller: CampaignController
var trial := "trial_army"
var frame := 0
var upgrades := 0
var path := ""
const WALK := ["move_right", "move_down", "move_left", "move_up"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): trial = args[0]
	if not TacticTrials.DEFS.has(trial):
		quit(1)
		return
	MetaProgress.disabled = true
	MetaProgress._loaded = true
	MetaProgress.bestiary = {"QA Fixture": 5000}
	RunSave.pending = {}
	Realm.in_title = false
	path = "user://trial-smoke-%d-%d.save" % [OS.get_process_id(), Time.get_ticks_usec()]
	CampaignSave.path = path
	_start.call_deferred()

func _start() -> void:
	controller = CampaignController.new()
	root.add_child(controller)
	if not controller.create("battlemage", 58103)["ok"]:
		quit(1)
		return
	var next := controller.snapshot()
	var id: String = next["graph"]["start"][0]
	next["graph"]["nodes"][id].merge({"contract": trial, "event": "", "elite": false, "commission": "", "reward_theme": CampaignCatalog.reward_theme(trial)}, true)
	if not controller._commit(next)["ok"] or not controller.choose_route(id)["ok"]:
		quit(1)
		return
	var spec: Dictionary = controller.depart()["spec"]
	main = load("res://scenes/main.tscn").instantiate()
	main.expedition_spec = spec
	root.add_child(main)
	print("TACTIC TRIAL · ", trial, " · kit-only loadout · ", ProjectSettings.globalize_path("user://"))

func _process(_delta: float) -> bool:
	if main == null: return false
	frame += 1
	var player: Player = main._player
	var hud: Hud = main._hud
	var heading: String = WALK[(frame / 90) % WALK.size()]
	for action: String in WALK:
		if action == heading: Input.action_press(action)
		else: Input.action_release(action)
	if frame % 30 == 0: Input.action_press("dash")
	else: Input.action_release("dash")
	if hud._upgrade_root.visible:
		var index := 0
		var priority := ["legion", "harvest", "max_hp", "regen", "move_speed"] if trial == "trial_army" else (["aura", "lightning", "frostbite", "wisps", "ignite", "max_hp"] if trial == "trial_reaction" else ["max_hp", "regen", "move_speed", "legion", "harvest"])
		for preferred: String in priority:
			if preferred in hud._upgrade_ids:
				index = hud._upgrade_ids.find(preferred)
				break
		hud._choose(index)
		upgrades += 1
	if frame % 1800 == 0:
		print("t=%.1f · HP %.1f/%.1f · %d enemies · army %d · %s" % [main._director.elapsed, player.stats.hp, player.stats.max_hp, main._enemy_count(), main._army.count, TacticTrials.progress(trial, Elements.damage_by, player.dash_uses)["text"]])
	if not main._expedition_terminal and frame < 16000: return false
	var terminal: Dictionary = main._expedition_result
	var ok: bool = terminal.get("outcome", "") == "success" and not player.dead and CampaignCatalog.valid_success(main.expedition_spec, terminal)
	if ok: ok = controller.settle(terminal)["ok"]
	print("TACTIC SMOKE %s · %s · t=%.2f · deaths=%s · kills=%d · upgrades=%d · damage=%s" % ["PASSED" if ok else "FAILED", trial, main._director.elapsed, player.dead, main.kills, upgrades, str(Elements.damage_by)])
	for action: String in WALK + ["dash"]: Input.action_release(action)
	main.free()
	controller.free()
	Elements.reset()
	Juice.reset()
	for suffix in ["", ".bak", ".previous", ".rollback", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	quit(0 if ok else 1)
	return true
