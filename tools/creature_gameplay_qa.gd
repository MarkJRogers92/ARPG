extends SceneTree
## Controlled actual Main scene. Uses real input, current hero/camera/lighting,
## existing combat/charge simulation; durable targets keep both looks observable.
var main: Node
var player: Player
var frame := 0
var realm := "graveyard"
var output := ""
var baseline := false
var bench := false
var frames_limit := 480
var capture_busy := false
var measured := PackedFloat64Array()
var last_tick := 0
var observed := {}
var report := {}
var target_swarms := []
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	realm=args[0] if args.size()>0 else "graveyard"
	output=args[1] if args.size()>1 else "res://build/creature-qa"
	baseline=args.size()>2 and args[2]=="old"
	bench=args.size()>3 and args[3]=="bench"
	frames_limit=180 if bench else 480
	DirAccess.make_dir_recursive_absolute(output)
	CreatureModels.enabled=not baseline
	seed(38289)
	MetaProgress.disabled=true
	Realm.current=realm;Realm.in_title=false
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720)
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main);current_scene=main
	_setup.call_deferred()
func _setup() -> void:
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
	player=main.get_node("Player");player.invulnerable=true
	main.get_node("WaveDirector").rate_scale=0.0
	for s: EnemySwarm in get_nodes_in_group(EnemySwarm.GROUP):
		s.despawn_all();s.step(0,Vector2.ZERO)
		if s.get_parent()==main and CreatureModels.REALMS[realm].has(s.model):target_swarms.append(s)
	for si in target_swarms.size():
		var s: EnemySwarm=target_swarms[si]
		if bench:
			for i in mini(s.capacity,500):
				s.spawn(Vector2.from_angle(float(i)*2.399963)* (7.0+sqrt(float(i))*.43))
		else:
			for p in [Vector2(-5.5+si*8,-5.0),Vector2(-2.5+si*8,-5.0)]:s.spawn(p)
		for i in s.count:s.hp[i]=1000000.0
	main.elapsed=300
	report={"realm":realm,"mode":"matched-horde" if bench else "controlled-gameplay","baseline":baseline,"base":"7029bf935c4fb537d5bf21bc5b58dd41bc91a595","device":RenderingServer.get_video_adapter_name(),"viewport":[1280,720],"count_start":main._enemy_count(),"frames":0,"shader_state_codes":{},"screenshots":[],"limitations":"Software renderer; no target Mac FPS claim. Invulnerable automated hero and durable targets, not a human balance test."}
	last_tick=Time.get_ticks_usec()
func _process(_delta: float) -> bool:
	if player==null or capture_busy:return false
	frame+=1
	var now:=Time.get_ticks_usec()
	if frame>60:measured.append(float(now-last_tick)/1000.0)
	last_tick=now
	player.stats.hp=player.stats.max_hp
	var heading: String=["move_right","move_down","move_left","move_up"][((frame-1)/90)%4]
	for a: String in ["move_right","move_down","move_left","move_up"]:
		if heading==a:Input.action_press(a)
		else:Input.action_release(a)
	for s: EnemySwarm in target_swarms:
		if s._creature_active:
			for i in s.count:
				if s._appearance[i]==1:
					var code: float=s._buffer[i*20+15]
					var label: String="%s/%d" % [s.creature_model,int(code)]
					observed[label]=true
	if not bench:
		if frame in [45,120,180,275,360]:_capture("frame_%03d"%frame)
		if frame==170:
			for s: EnemySwarm in target_swarms:
				for i in s.count:
					Elements.hit(s,i,.1,Elements.FROST if i%2==0 else Elements.FIRE)
		if frame==260:
			for s: EnemySwarm in target_swarms:
				for i in s.count:
					if i%2==1:s.damage(i,1.0e9)
	if frame>=frames_limit:_finish()
	return false
func _capture(label: String) -> void:
	capture_busy=true
	await RenderingServer.frame_post_draw
	var path:=output+"/"+realm+"_"+label+".png"
	get_root().get_texture().get_image().save_png(path)
	report.screenshots.append(path)
	capture_busy=false
func _finish() -> void:
	for a: String in ["move_right","move_down","move_left","move_up"]:Input.action_release(a)
	report.frames=frame;report.shader_state_codes=observed
	var sum:=0.0
	for x in measured:sum+=x
	report.mean_frame_ms=sum/maxi(measured.size(),1)
	measured.sort()
	report.p95_frame_ms=measured[int(measured.size()*.95)] if measured.size()>0 else 0
	report.count_end=main._enemy_count()
	var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("CREATURE_GAMEPLAY_QA_COMPLETE ",JSON.stringify(report))
	quit()
