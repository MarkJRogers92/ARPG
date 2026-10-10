extends SceneTree
## A close-up animation review, not a gameplay or performance demonstration.
var draws:=[]
var frame:=0
var title:Label
var caption:Label
var output:="res://build/creature-gallery"
var capturing:=false
func _initialize()->void:setup.call_deferred()
func setup()->void:
 MetaProgress.disabled=true
 var args:=OS.get_cmdline_user_args()
 if args.size()>0:output=args[0]
 DirAccess.make_dir_recursive_absolute(output)
 root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1280,720);root.content_scale_size=Vector2i(1280,720)
 var scene:=Node3D.new();root.add_child(scene);current_scene=scene
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.025,.04,.055);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.6,.67,.8);env.environment.ambient_light_energy=.95;scene.add_child(env)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-25,0);sun.light_energy=2.0;scene.add_child(sun)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8.5;scene.add_child(camera);camera.position=Vector3(0,11,14);camera.look_at(Vector3(0,.65,0));camera.current=true
 var floor:=MeshInstance3D.new();floor.mesh=PlaneMesh.new();floor.mesh.size=Vector2(22,16);floor.position.y=-.03;var fm:=StandardMaterial3D.new();fm.albedo_color=Color(.085,.115,.14);floor.material_override=fm;scene.add_child(floor)
 var kinds:=["coffin_crawler","rime_widow","slag_scorpion","gallows_raven","antler_revenant","furnace_tortoise"]
 for i in 6:
  var mm:=MultiMeshInstance3D.new();var kind:String=kinds[i];var mesh:=CreatureModels.mesh(kind);var mat:=CreatureModels.material(kind,false,Color.WHITE)
  for s in mesh.get_surface_count():mesh.surface_set_material(s,mat)
  scene.add_child(mm);MultiMeshUtil.setup(mm,mesh,1,mat);mm.multimesh.visible_instance_count=1;mm.multimesh.set_instance_transform(0,Transform3D(Basis(Vector3.UP,PI),Vector3((i%3-1)*4.0,0,-2.25 if i<3 else 2.25)));mm.multimesh.set_instance_custom_data(0,Color(0,float(i)*.11,0,0));draws.append(mm)
 var layer:=CanvasLayer.new();root.add_child(layer)
 title=Label.new();title.position=Vector2(28,14);title.add_theme_font_size_override("font_size",29);title.text="SOULBOUND  /  CREATURE ANIMATION REVIEW";layer.add_child(title)
 caption=Label.new();caption.position=Vector2(28,52);caption.add_theme_font_size_override("font_size",21);layer.add_child(caption)
 var footer:=Label.new();footer.position=Vector2(28,661);footer.add_theme_font_size_override("font_size",17);footer.text="Coffin Crawler · Rime Widow · Slag Scorpion   /   Gallows Raven · Antler Revenant · Furnace Tortoise\nRuntime GPU joints • close-up review lighting • existing game behaviors remain unchanged";layer.add_child(footer)
func _process(_delta:float)->bool:
 if draws.is_empty() or capturing:return false
 frame+=1
 var time:=float(frame)/30.0
 var state:=0.0
 var label:="IDLE"
 if frame>=90 and frame<210:state=1.0;label="WALK / SCUTTLE / WINGBEAT"
 elif frame>=210 and frame<270:state=7.0;label="ATTACK MOTION"
 elif frame>=270 and frame<300:label="HIT REACTION"
 elif frame>=300 and frame<330:state=8.0+float(frame-300)/30.0;label="DEATH / COSMETIC REMOVAL"
 elif frame>=330:state=1.0;label="LOCOMOTION"
 caption.text=label
 for mm:MultiMeshInstance3D in draws:
  mm.multimesh.set_instance_color(0,Color(1,1,1,state))
  var custom:=mm.multimesh.get_instance_custom_data(0);custom.r=sin(float(frame-270)/30*PI) if frame>=270 and frame<300 else 0.0;mm.multimesh.set_instance_custom_data(0,custom)
  var mat:=mm.multimesh.mesh.surface_get_material(0) as ShaderMaterial;mat.set_shader_parameter("preview_time",time)
 if frame in [30,100,150,240,285,315]:capture()
 if frame>=420:quit()
 return false
func capture()->void:
 capturing=true
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png(output+"/pose_%03d.png"%frame)
 capturing=false
