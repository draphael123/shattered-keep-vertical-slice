extends Node3D

const HERO=preload("res://scripts/hero.gd")
const ENEMY=preload("res://scripts/enemy.gd")
const SPAWNER=preload("res://scripts/spawner.gd")
const BREAKABLE=preload("res://scripts/breakable.gd")
const PICKUP=preload("res://scripts/pickup.gd")
const TRAP=preload("res://scripts/trap.gd")
const RUNE=preload("res://scripts/rune.gd")
var hero:CharacterBody3D
var layer:CanvasLayer
var menu:Control
var hud:Control
var health_bar:ProgressBar
var ability_bar:ProgressBar
var objective:Label
var score_label:Label
var hero_label:Label
var tutorial_panel:ColorRect
var tutorial_label:Label
var selected_class:="Ironwarden"
var score:=0
var gold:=0
var keys:=0
var stage:=0
var wave_remaining:=0
var game_started:=false
var settings_open:=false
var gates_spawned:=false
var boss_spawned:=false
var rune_progress:=0
var puzzle_active:=false
var puzzle_complete:=false
var rune_nodes:Array[Node3D]=[]
var camera:Camera3D
var awaiting_advance:=false
var advance_target_z:=0.0
var pending_stage:=0
var camera_shake:=0.0
var screen_shake_enabled:=true
var damage_flashes_enabled:=true
var master_volume:=85.0
var tutorial_mode:=false
var tutorial_step:=0
var tutorial_origin:=Vector3.ZERO
var tutorial_attacks:=0

func _ready()->void:
	_build_environment();_build_arena();_build_ui();_show_title()

func material(color:Color,emission:=Color.BLACK,energy:=0.0,metallic:=0.0)->StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.72;m.metallic=metallic
	if energy>0:m.emission_enabled=true;m.emission=emission;m.emission_energy_multiplier=energy
	return m

func box_part(name:String,size:Vector3,pos:Vector3,mat:Material,collision:=false)->MeshInstance3D:
	var n:=MeshInstance3D.new();n.name=name;var mesh:=BoxMesh.new();mesh.size=size;n.mesh=mesh;n.material_override=mat;n.position=pos;add_child(n)
	if collision:
		var body:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.position=pos;body.add_child(shape);add_child(body)
	return n

func _build_environment()->void:
	var env:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("#040b0e")
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("#6a8f91");e.ambient_light_energy=.36;e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	e.glow_enabled=true;e.glow_intensity=1.2;e.fog_enabled=true;e.fog_light_color=Color("#274536");e.fog_density=.022;env.environment=e;add_child(env)
	var moon:=DirectionalLight3D.new();moon.light_color=Color("#b9d99b");moon.light_energy=1.25;moon.rotation_degrees=Vector3(-58,-32,0);moon.shadow_enabled=true;add_child(moon)
	camera=Camera3D.new();camera.position=Vector3(0,17,16);camera.rotation_degrees=Vector3(-47,0,0);camera.fov=40;camera.current=true;add_child(camera)

func _build_arena()->void:
	var wall:=material(Color("#30453d"));box_part("Floor",Vector3(26,.35,56),Vector3(0,-.2,-18),material(Color("#182d23")),true)
	for x in range(-12,13,2):
		for z in range(-44,9,2):
			var path_tile:bool=abs(x)<=5
			var tile_color:Color=Color("#46554b") if path_tile else (Color("#25412f") if (x+z)%4==0 else Color("#203828"))
			var tile:=box_part("Tile",Vector3(1.82,.08,1.82),Vector3(x,.02,z),material(tile_color))
			tile.rotation.y=randf_range(-.018,.018)
	box_part("NorthWall",Vector3(26,3.2,.8),Vector3(0,1.4,-46.2),wall,true)
	box_part("SouthWallL",Vector3(8,.65,.8),Vector3(-9,.15,9.2),wall,true);box_part("SouthWallR",Vector3(8,.65,.8),Vector3(9,.15,9.2),wall,true)
	box_part("WestWall",Vector3(.8,3,56),Vector3(-13.1,1.3,-18),wall,true);box_part("EastWall",Vector3(.8,3,56),Vector3(13.1,1.3,-18),wall,true)
	# Room dividers leave a broad central archway and make progression legible.
	for z in [-8.0,-20.0,-34.0]:
		box_part("DividerL",Vector3(8.8,3,.8),Vector3(-8.6,1.3,z),wall,true)
		box_part("DividerR",Vector3(8.8,3,.8),Vector3(8.6,1.3,z),wall,true)
		for x in [-4.0,4.0]:
			box_part("ArchPier",Vector3(1.0,3.8,1.2),Vector3(x,1.8,z),material(Color("#3b5250")),true)
	for pos in [Vector3(-10,0,6),Vector3(10,0,6),Vector3(-10,0,-13),Vector3(10,0,-13),Vector3(-10,0,-28),Vector3(10,0,-28),Vector3(-10,0,-42),Vector3(10,0,-42)]:
		box_part("Pillar",Vector3(1.2,2.5,1.2),pos+Vector3(0,1.25,0),wall,true)
		for y in [0.0,2.4]:box_part("Trim",Vector3(1.5,.24,1.5),pos+Vector3(0,y+.15,0),material(Color("#405856")))
		var fire:=OmniLight3D.new();fire.position=pos+Vector3(0,3,0);fire.light_color=Color("#ff8f3d");fire.light_energy=3.1;fire.omni_range=7;add_child(fire)
		var flame:=GPUParticles3D.new();flame.position=pos+Vector3(0,2.75,0);flame.amount=42;flame.lifetime=.8
		var pp:=ParticleProcessMaterial.new();pp.direction=Vector3.UP;pp.spread=20;pp.initial_velocity_min=1.2;pp.initial_velocity_max=2.5;pp.gravity=Vector3(0,.5,0);pp.color=Color("#ff8b35")
		var q:=QuadMesh.new();q.size=Vector2(.18,.18);flame.process_material=pp;flame.draw_pass_1=q;add_child(flame)
	# Raised focal dais in the final boss chamber.
	for i in 3:
		var ring:=CylinderMesh.new();ring.top_radius=2.8-i*.35;ring.bottom_radius=2.8-i*.35;ring.height=.12
		var n:=MeshInstance3D.new();n.mesh=ring;n.material_override=material(Color("#263b3a"));n.position=Vector3(0,.03+i*.1,-41);add_child(n)
	# Repeated arches, rubble and banners create a consistent authored route.
	for z in [4.0,-12.0,-26.0,-40.0]:
		for x in [-11.4,11.4]:
			box_part("WallButtress",Vector3(1.1,4.0,1.6),Vector3(x,1.8,z),material(Color("#344b49")))
	for z in [-3.0,-16.0,-30.0]:
		for x in [-9.5,9.5]:
			var rubble:=box_part("Rubble",Vector3(1.4,.65,1.1),Vector3(x,.3,z),material(Color("#314341")))
			rubble.rotation_degrees=Vector3(randf_range(-8,8),randf_range(0,45),randf_range(-6,6))
	# Readable spawn furniture: enemies emerge beside these sarcophagi.
	for z in [-2.0,-14.0,-29.0,-40.0]:
		for x in [-10.2,10.2]:
			var tomb:=box_part("Sarcophagus",Vector3(2.2,.75,1.15),Vector3(x,.35,z),material(Color("#435655")))
			tomb.rotation.y=PI/2
			box_part("TombLid",Vector3(1.85,.16,.92),Vector3(x,.8,z),material(Color("#64706b")))
	for z in range(-43,8,4):
		for x in [-11.6,-9.8,9.8,11.6]:
			_tree(Vector3(x+randf_range(-.45,.45),0,z+randf_range(-.8,.8)),randf_range(.8,1.3))
	for pos in [Vector3(-7,0,3),Vector3(7,0,1),Vector3(-7,0,-11),Vector3(7,0,-18),Vector3(-7,0,-27),Vector3(7,0,-36)]:
		_foliage_cluster(pos)

func _tree(pos:Vector3,scale_value:float)->void:
	var trunk:=CylinderMesh.new();trunk.top_radius=.28*scale_value;trunk.bottom_radius=.48*scale_value;trunk.height=3.8*scale_value
	var t:=MeshInstance3D.new();t.mesh=trunk;t.material_override=material(Color("#49372b"));t.position=pos+Vector3(0,1.9*scale_value,0);add_child(t)
	for offset in [Vector3(0,3.5,0),Vector3(-.65,2.9,.2),Vector3(.6,3.0,-.25)]:
		var crown:=SphereMesh.new();crown.radius=1.15*scale_value;crown.height=2.0*scale_value
		var c:=MeshInstance3D.new();c.mesh=crown;c.material_override=material(Color("#31583b"));c.position=pos+offset*scale_value;add_child(c)

func _foliage_cluster(pos:Vector3)->void:
	for i in 5:
		var leaf:=SphereMesh.new();leaf.radius=randf_range(.18,.34);leaf.height=randf_range(.25,.55)
		var n:=MeshInstance3D.new();n.mesh=leaf;n.material_override=material(Color("#4f7846"));n.position=pos+Vector3(randf_range(-.8,.8),.18,randf_range(-.6,.6));add_child(n)
	var glow:=SphereMesh.new();glow.radius=.12;glow.height=.2
	var g:=MeshInstance3D.new();g.mesh=glow;g.material_override=material(Color("#8fe1a1"),Color("#8fe1a1"),2.5);g.position=pos+Vector3(0,.25,0);add_child(g)

func _build_ui()->void:
	layer=CanvasLayer.new();add_child(layer)
	menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(menu)
	hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.visible=false;layer.add_child(hud)
	var shade:=ColorRect.new();shade.color=Color(0.015,.027,.032,.86);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(shade)
	var top:=Label.new();top.text="THE SHATTERED KEEP";top.position=Vector2(34,24);top.add_theme_font_size_override("font_size",20);top.modulate=Color("#e7ddc8");hud.add_child(top)
	hero_label=Label.new();hero_label.position=Vector2(34,98);hero_label.size=Vector2(310,24);hero_label.modulate=Color("#9bd9c2");hero_label.add_theme_font_size_override("font_size",13);hud.add_child(hero_label)
	health_bar=ProgressBar.new();health_bar.position=Vector2(34,58);health_bar.size=Vector2(300,20);health_bar.show_percentage=false;hud.add_child(health_bar)
	ability_bar=ProgressBar.new();ability_bar.position=Vector2(34,83);ability_bar.size=Vector2(210,8);ability_bar.show_percentage=false;hud.add_child(ability_bar)
	var bar_bg:=StyleBoxFlat.new();bar_bg.bg_color=Color("#101d20");bar_bg.corner_radius_top_left=3;bar_bg.corner_radius_top_right=3;bar_bg.corner_radius_bottom_left=3;bar_bg.corner_radius_bottom_right=3
	var health_fill:=StyleBoxFlat.new();health_fill.bg_color=Color("#c34c45");health_fill.corner_radius_top_left=3;health_fill.corner_radius_top_right=3;health_fill.corner_radius_bottom_left=3;health_fill.corner_radius_bottom_right=3
	var power_fill:=StyleBoxFlat.new();power_fill.bg_color=Color("#54c9bf");power_fill.corner_radius_top_left=3;power_fill.corner_radius_top_right=3;power_fill.corner_radius_bottom_left=3;power_fill.corner_radius_bottom_right=3
	health_bar.add_theme_stylebox_override("background",bar_bg);health_bar.add_theme_stylebox_override("fill",health_fill)
	ability_bar.add_theme_stylebox_override("background",bar_bg);ability_bar.add_theme_stylebox_override("fill",power_fill)
	objective=Label.new();objective.position=Vector2(760,32);objective.size=Vector2(480,44);objective.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;objective.add_theme_font_size_override("font_size",16);hud.add_child(objective)
	score_label=Label.new();score_label.position=Vector2(820,68);score_label.size=Vector2(420,30);score_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;score_label.modulate=Color("#f4ca71");hud.add_child(score_label)
	var controls:=Label.new();controls.text="MOVE  WASD / STICK     ATTACK  LMB / A     POWER  Q / X     DASH  SHIFT / B     PAUSE  ESC";controls.position=Vector2(284,680);controls.modulate=Color("#a5b8b3");controls.add_theme_font_size_override("font_size",12);hud.add_child(controls)
	tutorial_panel=ColorRect.new();tutorial_panel.position=Vector2(350,545);tutorial_panel.size=Vector2(580,92);tutorial_panel.color=Color("#10231ee8");tutorial_panel.visible=false;hud.add_child(tutorial_panel)
	tutorial_label=Label.new();tutorial_label.position=Vector2(22,14);tutorial_label.size=Vector2(536,66);tutorial_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;tutorial_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;tutorial_label.add_theme_font_size_override("font_size",17);tutorial_label.modulate=Color("#e8e0bd");tutorial_panel.add_child(tutorial_label)

func styled_button(text:String,pos:Vector2,size:Vector2,callable:Callable)->Button:
	var b:=Button.new();b.text=text;b.position=pos;b.size=size;b.add_theme_font_size_override("font_size",18);b.pressed.connect(callable)
	var normal:=StyleBoxFlat.new();normal.bg_color=Color("#142225");normal.border_color=Color("#415452");normal.set_border_width_all(1);normal.corner_radius_top_left=3;normal.corner_radius_top_right=3;normal.corner_radius_bottom_left=3;normal.corner_radius_bottom_right=3
	var focus:=normal.duplicate();focus.bg_color=Color("#273b39");focus.border_color=Color("#e5bd65");focus.set_border_width_all(3)
	var hover:=normal.duplicate();hover.bg_color=Color("#203432");hover.border_color=Color("#68d1c7");hover.set_border_width_all(2)
	var pressed:=focus.duplicate();pressed.bg_color=Color("#4a4030")
	b.add_theme_stylebox_override("normal",normal);b.add_theme_stylebox_override("focus",focus);b.add_theme_stylebox_override("hover",hover);b.add_theme_stylebox_override("pressed",pressed)
	b.focus_mode=Control.FOCUS_ALL;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;menu.add_child(b)
	if not menu.get_viewport().gui_get_focus_owner():b.grab_focus()
	return b

func clear_menu()->void:
	for child in menu.get_children():
		if child is ColorRect:continue
		child.queue_free()

func label(text:String,pos:Vector2,size:int,color:=Color.WHITE)->Label:
	var l:=Label.new();l.text=text;l.position=pos;l.add_theme_font_size_override("font_size",size);l.modulate=color;menu.add_child(l);return l

func _show_title()->void:
	clear_menu();menu.visible=true;hud.visible=false
	var sigil:=label("SK",Vector2(590,72),52,Color("#63d5ca"));sigil.size=Vector2(100,70);sigil.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var title:=label("THE SHATTERED KEEP",Vector2(0,165),46,Color("#eadfc9"));title.size=Vector2(1280,60);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var sub:=label("WHISPERWOOD EXPEDITION",Vector2(0,226),16,Color("#8ed79a"));sub.size=Vector2(1280,30);sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var hook:=label("ENTER THE WILD ROAD. BREAK THE ROOTBOUND CURSE.",Vector2(0,285),14,Color("#9eafa0"));hook.size=Vector2(1280,30);hook.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	styled_button("GUIDED TUTORIAL",Vector2(490,350),Vector2(300,54),func():tutorial_mode=true;_show_select())
	styled_button("BEGIN EXPEDITION",Vector2(490,417),Vector2(300,52),func():tutorial_mode=false;_show_select())
	styled_button("SETTINGS",Vector2(490,482),Vector2(300,46),_show_settings)
	var foot:=label("A  G A U N T L E T - S T Y L E   A R C A D E   A D V E N T U R E",Vector2(0,600),11,Color("#687b78"));foot.size=Vector2(1280,20);foot.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func _show_select()->void:
	clear_menu();var heading:=label("CHOOSE YOUR HERO",Vector2(0,38),34,Color("#eadfc9"));heading.size=Vector2(1280,50);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var subtitle:=label("Four distinct roles. Compare ratings, choose a weapon, and enter the wild road.",Vector2(0,84),15,Color("#92a7a3"));subtitle.size=Vector2(1280,30);subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var classes=[["IRONWARDEN","Shield burst • durable","#63d5ca"],["EMBER MAGE","Fire nova • ranged","#ff7045"],["WILDBOW","Arrow volley • swift","#9bd65b"],["DAWN CLERIC","Heal pulse • balanced","#ffd77a"]]
	for i in 4:
		var x=82+i*300;var card:=ColorRect.new();card.position=Vector2(x,130);card.size=Vector2(260,440);card.color=Color(classes[i][2]).darkened(.72);menu.add_child(card)
		var icon:=label(["IW","EM","WB","DC"][i],Vector2(x,151),38,Color(classes[i][2]));icon.size=Vector2(260,55);icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var name:=label(classes[i][0],Vector2(x,211),20,Color("#eee4d3"));name.size=Vector2(260,30);name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var desc:=label(classes[i][1],Vector2(x,247),13,Color("#b4c2bd"));desc.size=Vector2(260,28);desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var ratings=[[4,5,2,2],[3,1,3,5],[4,2,5,2],[3,4,2,4]][i]
		var weapons=["SWORD + SHIELD","FIRE STAFF","LONGBOW","SUN MACE"]
		var weapon:=label(weapons[i],Vector2(x,282),13,Color("#d7c999"));weapon.size=Vector2(260,22);weapon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var stat_text:="DAMAGE   %s\nARMOR     %s\nSPEED     %s\nMAGIC     %s"%[_rating(ratings[0]),_rating(ratings[1]),_rating(ratings[2]),_rating(ratings[3])]
		var stat_label:=label(stat_text,Vector2(x+30,319),13,Color("#d7ded5"));stat_label.size=Vector2(205,116);stat_label.add_theme_constant_override("line_spacing",7)
		var hero_choice:String=["Ironwarden","Ember Mage","Wildbow","Dawn Cleric"][i]
		var b:=styled_button("SELECT",Vector2(x+40,496),Vector2(180,48),func():_start_game(hero_choice));b.add_theme_color_override("font_color",Color(classes[i][2]))
	styled_button("BACK",Vector2(40,635),Vector2(150,42),_show_title)

func _rating(value:int)->String:
	return "#".repeat(value)+"-".repeat(5-value)

func _show_settings()->void:
	clear_menu();settings_open=true;var settings_heading:=label("SETTINGS",Vector2(0,100),36,Color("#eadfc9"));settings_heading.size=Vector2(1280,50);settings_heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label("MASTER VOLUME",Vector2(390,210),16,Color("#9eb1ad"))
	var volume:=HSlider.new();volume.position=Vector2(620,210);volume.size=Vector2(270,30);volume.value=master_volume;volume.focus_mode=Control.FOCUS_ALL;volume.value_changed.connect(_set_volume);menu.add_child(volume)
	label("SCREEN SHAKE",Vector2(390,275),16,Color("#9eb1ad"));var shake:=CheckButton.new();shake.position=Vector2(780,265);shake.button_pressed=screen_shake_enabled;shake.focus_mode=Control.FOCUS_ALL;shake.toggled.connect(func(value):screen_shake_enabled=value);menu.add_child(shake)
	label("DAMAGE FLASHES",Vector2(390,340),16,Color("#9eb1ad"));var flashes:=CheckButton.new();flashes.position=Vector2(780,330);flashes.button_pressed=damage_flashes_enabled;flashes.focus_mode=Control.FOCUS_ALL;flashes.toggled.connect(func(value):damage_flashes_enabled=value);menu.add_child(flashes)
	label("CONTROLS",Vector2(390,405),16,Color("#9eb1ad"));label("Keyboard + mouse / Xbox-style controller",Vector2(620,405),15,Color("#e2d9c8"))
	styled_button("RETURN",Vector2(490,515),Vector2(300,50),_return_from_settings)

func _return_from_settings()->void:
	if game_started:_resume()
	else:_show_title()

func _set_volume(value:float)->void:
	master_volume=value
	var bus:=AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus,linear_to_db(max(value/100.0,.001)))

func _start_game(which:String)->void:
	selected_class=which;clear_menu();menu.visible=false;hud.visible=true;game_started=true;score=0;gold=0;keys=0;stage=1;_refresh_score()
	hero_label.text=selected_class.to_upper()+"  //  LEVEL 1"
	hero=CharacterBody3D.new();hero.set_script(HERO);hero.call("setup",selected_class);add_child(hero);hero.position=Vector3(0,0,6)
	hero.connect("health_changed",_on_health);hero.connect("ability_changed",_on_ability)
	hero.connect("impact",_on_impact)
	_spawn_breakables()
	_spawn_route_pickups()
	if tutorial_mode:
		tutorial_step=0;tutorial_origin=hero.global_position;tutorial_attacks=0;tutorial_panel.visible=true
		objective.text="TRAIL LESSON  //  MOVEMENT";_set_tutorial("MOVE\nUse WASD or the left stick to cross the glowing trail.")
	else:_start_wave(1)

func _set_tutorial(text:String)->void:
	tutorial_label.text=text

func _advance_tutorial()->void:
	tutorial_step+=1
	match tutorial_step:
		1: objective.text="TRAIL LESSON  //  ATTACK";_set_tutorial("ATTACK\nStrike three times with Left Mouse or A.")
		2: objective.text="TRAIL LESSON  //  POWER";_set_tutorial("CLASS POWER\nPress Q or X to unleash your hero's signature power.")
		3: objective.text="TRAIL LESSON  //  DASH";_set_tutorial("DASH\nPress Shift or B to burst through danger.")
		4: objective.text="TRAIL LESSON  //  BREAKABLES";_set_tutorial("SUPPLIES\nSmash a crate and collect what falls.")
		_:
			objective.text="TUTORIAL COMPLETE  //  THE TRAIL OPENS";_set_tutorial("TRAIL READY\nFollow the stone road. Monsters emerge from the forest.")
			await get_tree().create_timer(1.8).timeout
			tutorial_mode=false;tutorial_panel.visible=false;_start_wave(1)

func _start_wave(number:int)->void:
	stage=number
	if number<=2:
		wave_remaining=4+number*2;objective.text="WAVE %d  //  %d CREATURES" %[number,wave_remaining]
		var room_z:float=-2.0 if number==1 else -14.0
		for i in wave_remaining:
			await get_tree().create_timer(.28).timeout
			_spawn_enemy(i%min(number+1,3),Vector3(randf_range(-9,9),0,room_z+randf_range(-3,3)))
	elif number==3:
		_start_puzzle()
	elif number==4:
		gates_spawned=true;objective.text="DESTROY THE THREE MONSTER GATES"
		for pos in [Vector3(-8,0,-29),Vector3(8,0,-29),Vector3(0,0,-26)]:
			var gate:=Node3D.new();gate.set_script(SPAWNER);add_child(gate);gate.position=pos
	else:_spawn_boss()

func _spawn_enemy(kind:int,pos:Vector3,elite:=false)->void:
	var warning:=MeshInstance3D.new();var wm:=CylinderMesh.new();wm.top_radius=.78;wm.bottom_radius=.78;wm.height=.03
	var warning_color:=Color("#f0573f") if kind>=2 else Color("#64e0a0")
	warning.mesh=wm;warning.material_override=material(warning_color,warning_color,3.4);warning.position=pos+Vector3(0,.04,0);add_child(warning)
	var ring:=MeshInstance3D.new();var rm:=TorusMesh.new();rm.inner_radius=.68;rm.outer_radius=.8
	ring.mesh=rm;ring.material_override=material(Color("#fff0a0"),Color("#fff0a0"),4.0);ring.position=pos+Vector3(0,.07,0);add_child(ring)
	var beacon:=MeshInstance3D.new();var bm:=CylinderMesh.new();bm.top_radius=.055;bm.bottom_radius=.22;bm.height=2.8
	beacon.mesh=bm;beacon.material_override=material(warning_color,warning_color,2.4);beacon.position=pos+Vector3(0,1.4,0);add_child(beacon)
	warning.scale=Vector3(.12,1,.12);ring.scale=Vector3(1.2,1,1.2);beacon.scale.y=.05
	var telegraph:=create_tween().set_parallel();telegraph.tween_property(warning,"scale",Vector3.ONE,.5).set_trans(Tween.TRANS_QUAD);telegraph.tween_property(ring,"scale",Vector3(.15,1,.15),.5);telegraph.tween_property(beacon,"scale:y",1.0,.34).set_trans(Tween.TRANS_BACK)
	await get_tree().create_timer(.52).timeout
	var enemy:=CharacterBody3D.new();enemy.set_script(ENEMY);enemy.call("setup",kind,elite);add_child(enemy);enemy.global_position=pos
	enemy.scale=Vector3(.2,.2,.2);var rise:=create_tween();rise.tween_property(enemy,"scale",Vector3.ONE*1.65 if kind==3 else Vector3.ONE,0.25).set_trans(Tween.TRANS_BACK)
	warning.queue_free();ring.queue_free();beacon.queue_free()

func _spawn_boss()->void:
	if boss_spawned:return
	boss_spawned=true;objective.text="THE THORN WARDEN  //  SLAY THE BOSS";_spawn_enemy(3,Vector3(0,0,-41))

func _spawn_breakables()->void:
	for i in 10:
		var item:=Node3D.new();item.set_script(BREAKABLE);item.call("setup",i%2);add_child(item)
		var side:float=-1.0 if i%2==0 else 1.0
		item.position=Vector3(side*(9.2+(i%3)*.65),0,4.0-(i/2)*9.5)
	for pos in [Vector3(-5.2,0,-16),Vector3(-1.8,0,-16),Vector3(1.8,0,-16),Vector3(5.2,0,-16)]:
		var trap:=Node3D.new();trap.set_script(TRAP);add_child(trap);trap.position=pos

func _spawn_route_pickups()->void:
	for data in [[2,Vector3(-6,0,-4)],[0,Vector3(6,0,-12)],[1,Vector3(-7,0,-25)],[3,Vector3(7,0,-38)]]:
		var drop:=Node3D.new();drop.set_script(PICKUP);drop.call("setup",data[0]);add_child(drop);drop.global_position=data[1]

func breakable_destroyed(pos:Vector3)->void:
	score+=100;_refresh_score()
	if tutorial_mode and tutorial_step==4:_advance_tutorial()
	if randf()<.7:
		var health_drop:=randf()<.32
		var count:=1 if health_drop else randi_range(3,6)
		for i in count:
			var drop:=Node3D.new();drop.set_script(PICKUP);drop.call("setup",0 if health_drop else 1);add_child(drop);drop.global_position=pos+Vector3(randf_range(-.2,.2),.1,randf_range(-.2,.2))

func collect_treasure(value:int)->void:
	gold+=value;score+=value*10;_refresh_score()

func collect_key()->void:
	keys+=1;score+=300;_refresh_score()
	objective.text="IRON KEY FOUND  //  LOCKED GATES CAN BE OPENED"

func _refresh_score()->void:
	if score_label:score_label.text="KEYS  %d     GOLD  %04d     SCORE  %06d"%[keys,gold,score]

func _start_puzzle()->void:
	puzzle_active=true;rune_progress=0;objective.text="RUNE LOCK  //  STEP ON 1 • 2 • 3"
	var positions=[Vector3(-3.3,0,-24),Vector3(0,0,-25.2),Vector3(3.3,0,-24)]
	for i in 3:
		var rune:=Node3D.new();rune.set_script(RUNE);rune.call("setup",i);add_child(rune);rune.position=positions[i];rune.connect("stepped",_on_rune_stepped);rune_nodes.append(rune)

func _on_rune_stepped(index:int)->void:
	if not puzzle_active:return
	if index==rune_progress:
		rune_nodes[index].call("set_lit",true);rune_progress+=1
		objective.text="RUNE LOCK  //  %d OF 3 ALIGNED"%rune_progress
		if rune_progress>=3:
			puzzle_active=false;puzzle_complete=true;score+=750;_refresh_score();objective.text="RUNE LOCK OPEN"
			await get_tree().create_timer(1.2).timeout
			for rune in rune_nodes:
				if is_instance_valid(rune):rune.queue_free()
			rune_nodes.clear();_start_wave(4)
	else:
		rune_progress=0;objective.text="WRONG RUNE  //  SEQUENCE RESET"
		for rune in rune_nodes:rune.call("set_lit",false)

func enemy_defeated(kind:int)->void:
	score+=250 if kind<3 else 2500;_refresh_score()
	if kind==3:_victory()
	elif stage<=2:
		wave_remaining-=1;objective.text="WAVE %d  //  %d CREATURES" %[stage,max(wave_remaining,0)]
		if wave_remaining<=0:
			pending_stage=stage+1;advance_target_z=-9.0 if pending_stage==2 else -21.0;awaiting_advance=true
			objective.text="PATH OPEN  //  ADVANCE TO THE NEXT CHAMBER"

func _process(delta:float)->void:
	if game_started and is_instance_valid(hero) and is_instance_valid(camera):
		var desired:=Vector3(clamp(hero.global_position.x*.18,-2.2,2.2),17,hero.global_position.z+16)
		camera_shake=max(0.0,camera_shake-delta*3.0)
		var amount:=camera_shake if screen_shake_enabled else 0.0
		var shake:=Vector3(randf_range(-amount,amount),randf_range(-amount,amount),0)
		camera.global_position=camera.global_position.lerp(desired+shake,1.0-exp(-delta*4.5))
		if tutorial_mode:
			if tutorial_step==0 and hero.global_position.distance_to(tutorial_origin)>2.2:_advance_tutorial()
			elif tutorial_step==1 and Input.is_action_just_pressed("attack"):
				tutorial_attacks+=1
				tutorial_label.text="ATTACK\nStrike three times with Left Mouse or A.  %d / 3"%tutorial_attacks
				if tutorial_attacks>=3:_advance_tutorial()
			elif tutorial_step==2 and Input.is_action_just_pressed("ability"):_advance_tutorial()
			elif tutorial_step==3 and Input.is_action_just_pressed("dash"):_advance_tutorial()
	if awaiting_advance and is_instance_valid(hero) and hero.global_position.z<advance_target_z:
		if pending_stage==2 and keys<=0:
			hero.global_position.z=advance_target_z+.5;objective.text="LOCKED GATE  //  FIND THE IRON KEY"
		else:
			if pending_stage==2:keys-=1;_refresh_score()
			awaiting_advance=false;_start_wave(pending_stage)
	if game_started and gates_spawned and not boss_spawned:
		var gates:=get_tree().get_nodes_in_group("gate")
		objective.text="DESTROY THE MONSTER GATES  //  %d REMAIN"%gates.size()
		if gates.is_empty():gates_spawned=false;await get_tree().create_timer(1.0).timeout;_start_wave(5)
	if game_started and Input.is_action_just_pressed("ui_cancel"):
		if menu.visible:_resume()
		else:_pause()

func _pause()->void:
	menu.visible=true;hud.visible=false;get_tree().paused=true;clear_menu()
	var pause_heading:=label("EXPEDITION PAUSED",Vector2(0,160),36,Color("#eadfc9"));pause_heading.size=Vector2(1280,50);pause_heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	styled_button("RESUME",Vector2(490,290),Vector2(300,52),_resume);styled_button("SETTINGS",Vector2(490,358),Vector2(300,48),_show_settings);styled_button("RETURN TO KEEP",Vector2(490,422),Vector2(300,48),_quit_run)

func _resume()->void:
	settings_open=false;menu.visible=false;hud.visible=true;get_tree().paused=false

func _quit_run()->void:
	get_tree().paused=false;get_tree().reload_current_scene()

func _victory()->void:
	game_started=false;await get_tree().create_timer(.8).timeout;menu.visible=true;hud.visible=false;clear_menu()
	var victory_heading:=label("WHISPERWOOD RESTORED",Vector2(0,130),42,Color("#f4d179"));victory_heading.size=Vector2(1280,60);victory_heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var saved:=label("THE KEEP GROWS STRONGER",Vector2(0,210),19,Color("#63d5ca"));saved.size=Vector2(1280,35);saved.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var reward:=label("+ 1 RELIC SHARD     + FORGE RESTORATION",Vector2(0,285),16,Color("#ddd4c3"));reward.size=Vector2(1280,35);reward.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var final_score:=label("FINAL SCORE   %06d"%score,Vector2(0,350),24,Color("#f4ca71"));final_score.size=Vector2(1280,40);final_score.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	styled_button("PLAY AGAIN",Vector2(490,465),Vector2(300,52),_quit_run)

func _on_health(current:float,maximum:float)->void:
	health_bar.max_value=maximum;health_bar.value=current
func _on_ability(current:float,maximum:float)->void:
	ability_bar.max_value=maximum;ability_bar.value=maximum-current

func _on_impact(strength:float)->void:
	camera_shake=max(camera_shake,strength)
