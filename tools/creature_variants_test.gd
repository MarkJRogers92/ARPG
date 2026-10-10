extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	MetaProgress.disabled = true
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)
func _run() -> void:
	Elements.player = null
	Elements.swarms.clear()
	for realm: String in CreatureModels.REALMS:
		for role: String in CreatureModels.REALMS[realm]:
			var kind: String = CreatureModels.kind_for(realm,role)
			_test_asset(kind)
			_test_swarm(kind,role)
	_test_realm()
	_test_deaths()
	_test_budget()
	_test_animation_states()
	check(CreatureModels.mesh("missing") == null,"missing art falls back")
	CreatureModels.enabled = false
	check(CreatureModels.kind_for("graveyard","grunt").is_empty(),"disabled route retains original")
	check(CreatureModels.mesh("coffin_crawler") == null,"disabled art fallback")
	CreatureModels.enabled = true
	print("CREATURE VARIANTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func _test_asset(kind: String) -> void:
	var m := CreatureModels.mesh(kind)
	check(m != null,"mesh loads "+kind)
	if m == null:return
	var data := CreatureModels.rig(kind)
	check(data.bones.size() <= 32,"bounded joint palette "+kind)
	for i in data.bones.size():
		var b: Dictionary = data.bones[i]
		check(b.parent < i,"acyclic parent chain "+kind)
		check(absf(Vector3(b.axis[0],b.axis[1],b.axis[2]).length()-1.0)<0.0001,"unit joint axis")
	check(m.get_surface_count()==2,"both material surfaces "+kind)
	check(absf(m.get_aabb().position.y)<0.001,"feet at origin "+kind)
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		for uv: Vector2 in a[Mesh.ARRAY_TEX_UV2]:check(uv.x>=0 and uv.x<data.bones.size(),"valid authored joint ID")
		for uv: Vector2 in a[Mesh.ARRAY_TEX_UV]:check(absf(uv.x)<0.001 or absf(uv.x-.72)<0.001,"glow contract preserved")
	var other := CreatureModels.mesh(kind)
	check(m != other,"each swarm owns material assignment")
	var mat := CreatureModels.material(kind,true,Color(0.2,0.6,1))
	check(mat.get_shader_parameter("spectral"),"spectral cues retained")
	check(mat.get_shader_parameter("joint_pivots").size()==32,"all uniform joints initialized")
func _make(role: String,kind: String) -> EnemySwarm:
	var s := EnemySwarm.new()
	s.capacity=12
	s.model=role
	s.creature_model=kind
	s.charger=role=="lancer"
	root.add_child(s)
	return s
func _test_swarm(kind: String,role: String) -> void:
	var a := _make(role,"")
	var b := _make(role,kind)
	check(b._creature_active,"GPU creature active "+kind)
	check(b.get_child_count()==(4 if b.charger else 3),"fixed batched node count "+kind)
	seed(88001)
	for i in 12:a.spawn(Vector2(7+i*.4,2+i%3),1.0,i==2)
	var next := randf()
	seed(88001)
	for i in 12:b.spawn(Vector2(7+i*.4,2+i%3),1.0,i==2)
	check(randf()==next,"no new gameplay RNG draws "+kind)
	check(a.hp==b.hp and a._fire==b._fire,"identical spawn state "+kind)
	for frame in 90:
		a.step(1.0/60,Vector2.ZERO)
		b.step(1.0/60,Vector2.ZERO)
		check(a.pos==b.pos and a.hp==b.hp,"movement/stats match old role "+kind)
	check(b.multimesh.visible_instance_count==6 and b._variant_layer.multimesh.visible_instance_count==6,"exactly once old/new split")
	var killed_id := b.ids[1]
	var killed_at := b.pos[1]
	b.damage(1,10000)
	b.step(0,Vector2.ZERO)
	check(b.count==11,"dead removed from simulation immediately")
	check(b._creature_deaths._count==1,"new appearance leaves one cosmetic death")
	check(b.multimesh.visible_instance_count+b._variant_layer.multimesh.visible_instance_count==11,"swap removal does not duplicate render")
	var near_count := b.grid.query(killed_at,1.0)
	for j in near_count:check(b.ids[b.grid.results[j]] != killed_id,"dead body absent from contact spatial index")
	b._creature_deaths._process(1.0)
	check(b._creature_deaths._count==0 and not b._creature_deaths.is_processing(),"death batch stops when empty")
	# All state codes are cosmetic and keep instance custom hit/status channels.
	b._flash[0]=.8
	b.chill[0]=1.0
	b.burn[0]=1.0
	b.burn_dps[0]=0
	b.mark_afflicted(0)
	b.step(.016,Vector2.ZERO)
	check(b._buffer[MultiMeshUtil.OFFSET_CUSTOM]>.6,"hit cue survives")
	check(b._buffer[MultiMeshUtil.OFFSET_CUSTOM+3]==1.0,"burn cue survives")
	a.free();b.free()
func _test_realm() -> void:
	for realm: String in CreatureModels.REALMS:
		var main: Node=load("res://scenes/main.tscn").instantiate()
		Realm.apply_gameplay(main,realm)
		var total:=0
		for child in main.get_children():
			if child is EnemySwarm:
				if not child.creature_model.is_empty():total+=1
		check(total==2,"two creature appearances per realm "+realm)
		main.free()
func _test_deaths() -> void:
	var s:=_make("grunt","coffin_crawler")
	for i in 12:s.spawn(Vector2(i,0))
	s.step(0,Vector2.ZERO)
	for i in 100:s._creature_deaths.capture(s._buffer,i%12,s.pos[i%12])
	check(s._creature_deaths._count==24,"death pool remains bounded under bursts")
	s._creature_deaths._process(1.0)
	check(s._creature_deaths._count==0,"full death pool releases all entries")
	s._creature_deaths.capture(s._buffer,1,Vector2(20,25))
	check(s._creature_deaths._buffer[3]==20 and s._creature_deaths._buffer[11]==25,"fresh spawn deaths use actual position")
	s.despawn_all();s.step(0,Vector2.ZERO)
	check(s._creature_deaths._count==0,"despawn clears remnants without creating deaths")
	s.free()

func _test_budget() -> void:
	var s := EnemySwarm.new()
	s.capacity=100
	s.creature_model="coffin_crawler"
	root.add_child(s)
	for i in 100:s.spawn(Vector2(i,5))
	s.step(0,Vector2.ZERO)
	check(s._creature_live==16,"bounded live creature admission")
	check(s._variant_layer.multimesh.visible_instance_count==16 and s.multimesh.visible_instance_count==84,"all excess enemies use originals exactly once")
	var before:=s._appearance.duplicate()
	s.step(.016,Vector2.ZERO)
	check(s._appearance==before,"living appearances never pop as population changes")
	s.damage(1,10000);s.step(0,Vector2.ZERO)
	check(s._creature_live==15,"death releases admission slot")
	s.spawn(Vector2.ZERO);s.damage(0,10000);s.step(0,Vector2.ZERO);s.spawn(Vector2.ZERO)
	check(s._creature_live==16,"future eligible spawn reuses released slot")
	s.despawn_all();s.step(0,Vector2.ZERO)
	check(s._creature_live==0,"despawn releases all creature admission slots")
	s.free()

func _test_animation_states() -> void:
	var s := _make("lancer","antler_revenant")
	s.spawn(Vector2(5,0));s.spawn(Vector2(5,0))
	for state in [1,2,3]:
		s._cstate[1]=state
		s._ctime[1]=1.0
		s.step(0,Vector2.ZERO)
		var code:float=s._buffer[MultiMeshUtil.FLOATS_PER_INSTANCE+MultiMeshUtil.OFFSET_COLOR+3]
		check((code>=2 and code<=3) if state==1 else ((code==4) if state==2 else (code>=5 and code<=6)),"charge visual state follows authoritative AI")
	s.free()
	var c:=_make("grunt","coffin_crawler")
	c.spawn(Vector2.ZERO);c.spawn(Vector2(.1,0));c.step(0,Vector2.ZERO)
	check(c._buffer[MultiMeshUtil.FLOATS_PER_INSTANCE+MultiMeshUtil.OFFSET_COLOR+3]==7.0,"contact cosmetic attack is activated")
	c.free()
