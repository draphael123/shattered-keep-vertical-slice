extends CharacterBody3D

var enemy_type:=0
var health:=60.0
var speed:=3.2
var damage:=13.0
var hero:CharacterBody3D
var attack_timer:=0.0
var attack_cooldown:=0.0
var body:MeshInstance3D
var tell:MeshInstance3D
var tell_ring:MeshInstance3D
var dead:=false
var elite:=false
var visual_root:Node3D
var walk_time:=0.0
var windup_duration:=0.5
var attack_range:=1.8
var windup_target:=Vector3.ZERO

func setup(kind:int,is_elite:=false)->void:
	enemy_type=kind;elite=is_elite
	match kind:
		1: health=44;speed=4.8;damage=9
		2: health=105;speed=2.25;damage=22
		3: health=520;speed=2.0;damage=28;elite=true
	if elite:health*=1.4;damage*=1.2

func material(color:Color,emission:=Color.BLACK,energy:=0.0)->StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.72
	if color.a<1.0:m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	if energy>0:m.emission_enabled=true;m.emission=emission;m.emission_energy_multiplier=energy
	return m

func add_part(mesh:PrimitiveMesh,mat:Material,pos:Vector3,rot:=Vector3.ZERO)->MeshInstance3D:
	var n:=MeshInstance3D.new();n.mesh=mesh;n.material_override=mat;n.position=pos;n.rotation=rot;(visual_root if is_instance_valid(visual_root) else self).add_child(n);return n

func _ready()->void:
	add_to_group("damageable");hero=get_tree().get_first_node_in_group("hero");_build()

func _build()->void:
	visual_root=Node3D.new();add_child(visual_root)
	var colors=[Color("#aab9ad"),Color("#6ea64e"),Color("#855d9e"),Color("#71384b")]
	var accents=[Color("#53ddcf"),Color("#d8ec77"),Color("#ba75f5"),Color("#ff594d")]
	var c:Color=colors[enemy_type];var glow:=material(accents[enemy_type],accents[enemy_type],2.8)
	match enemy_type:
		1:
			var torso:=SphereMesh.new();torso.radius=.4;torso.height=.7;body=add_part(torso,material(c.darkened(.35)),Vector3(0,.82,0))
			var head:=SphereMesh.new();head.radius=.34;head.height=.55;add_part(head,material(c),Vector3(0,1.4,-.08))
			for x in [-.23,.23]:
				var ear:=PrismMesh.new();ear.size=Vector3(.22,.4,.18);add_part(ear,material(c),Vector3(x,1.65,0))
		2:
			var torso:=BoxMesh.new();torso.size=Vector3(1.05,1.25,.65);body=add_part(torso,material(c.darkened(.45)),Vector3(0,1.0,0))
			var head:=SphereMesh.new();head.radius=.38;head.height=.7;add_part(head,material(c),Vector3(0,1.85,0))
			var club:=CylinderMesh.new();club.top_radius=.17;club.bottom_radius=.29;club.height=1.6;add_part(club,material(Color("#57412d")),Vector3(.72,1.0,-.1),Vector3(0,0,-.35))
		3:
			scale=Vector3.ONE*1.65
			var torso:=CapsuleMesh.new();torso.radius=.55;torso.height=1.5;body=add_part(torso,material(c.darkened(.35)),Vector3(0,1.1,0))
			var crown:=TorusMesh.new();crown.inner_radius=.34;crown.outer_radius=.48;add_part(crown,glow,Vector3(0,2.12,0))
			var skull:=SphereMesh.new();skull.radius=.38;skull.height=.7;add_part(skull,material(Color("#cabca5")),Vector3(0,1.9,0))
		_:
			var torso:=BoxMesh.new();torso.size=Vector3(.72,.95,.42);body=add_part(torso,material(c.darkened(.7)),Vector3(0,1.05,0))
			var skull:=SphereMesh.new();skull.radius=.28;skull.height=.52;add_part(skull,material(c),Vector3(0,1.8,0))
			for x in [-.38,.38]:
				var arm:=CapsuleMesh.new();arm.radius=.07;arm.height=.85;add_part(arm,material(c),Vector3(x,1.05,0),Vector3(0,0,x*.9))
	var eye:=BoxMesh.new();eye.size=Vector3(.3,.07,.08);add_part(eye,glow,Vector3(0,1.75 if enemy_type!=1 else 1.43,-.3))
	var shape:=CapsuleShape3D.new();shape.radius=.48;shape.height=1.5
	var col:=CollisionShape3D.new();col.shape=shape;col.position.y=.75;add_child(col)
	tell=MeshInstance3D.new();var tm:=CylinderMesh.new();tm.top_radius=1.5;tm.bottom_radius=1.5;tm.height=.025
	attack_range=[1.75,1.55,2.15,2.9][enemy_type];windup_duration=[.46,.3,.8,1.15][enemy_type]
	tm.top_radius=attack_range;tm.bottom_radius=attack_range
	var tell_colors=[Color("#ff4938aa"),Color("#ffd34faa"),Color("#ff7138aa"),Color("#ff3028b8")]
	tell.mesh=tm;tell.material_override=material(tell_colors[enemy_type],tell_colors[enemy_type],2.0);tell.position.y=.04;tell.visible=false;add_child(tell)
	tell_ring=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=attack_range-.11;ring.outer_radius=attack_range
	tell_ring.mesh=ring;tell_ring.material_override=material(tell_colors[enemy_type],tell_colors[enemy_type],4.0);tell_ring.position.y=.07;tell_ring.visible=false;add_child(tell_ring)

func _begin_attack()->void:
	attack_timer=windup_duration;windup_target=hero.global_position
	tell.visible=true;tell_ring.visible=true;tell.scale=Vector3(.25,1,.25);tell_ring.scale=Vector3.ONE
	var alert:=Label3D.new();alert.text="!";alert.font_size=54;alert.outline_size=12;alert.modulate=Color("#fff0a3");alert.position=Vector3(0,2.5,0);add_child(alert)
	var pop:=create_tween().set_parallel();alert.scale=Vector3.ZERO;pop.tween_property(alert,"scale",Vector3.ONE,.12).set_trans(Tween.TRANS_BACK);pop.tween_property(alert,"position:y",2.85,windup_duration)
	pop.chain().tween_property(alert,"modulate:a",0.0,.1);pop.chain().tween_callback(alert.queue_free)

func _strike()->void:
	tell.visible=false;tell_ring.visible=false;visual_root.rotation.x=.38
	var snap:=create_tween().set_parallel();snap.tween_property(visual_root,"rotation:x",0.0,.18).set_trans(Tween.TRANS_BACK);snap.tween_property(visual_root,"scale",Vector3.ONE,.18).set_trans(Tween.TRANS_BACK)
	var hit_range:=attack_range+.15
	if hero.global_position.distance_to(global_position)<hit_range:hero.call("take_damage",damage,(hero.global_position-global_position).normalized()*8)
	var shock:=MeshInstance3D.new();var rm:=TorusMesh.new();rm.inner_radius=.3;rm.outer_radius=.42
	shock.mesh=rm;shock.material_override=material(Color("#ff7a43aa"),Color("#ff5038"),4.0);shock.position.y=.1;add_child(shock)
	var burst:=create_tween().set_parallel();burst.tween_property(shock,"scale",Vector3.ONE*attack_range*2.2,.28);burst.tween_property(shock,"transparency",1.0,.28)
	burst.chain().tween_callback(shock.queue_free);attack_cooldown=1.0 if enemy_type!=3 else 1.45

func _physics_process(delta:float)->void:
	if dead or not is_instance_valid(hero):return
	attack_cooldown-=delta
	var off:=hero.global_position-global_position;var dist:=off.length()
	if attack_timer>0:
		attack_timer-=delta
		var progress:float=clamp(1.0-attack_timer/windup_duration,0.0,1.0)
		tell.scale=Vector3(lerp(.25,1.0,progress),1,lerp(.25,1.0,progress))
		var ring_scale:float=lerp(1.0,.12,progress)
		tell_ring.scale=Vector3(ring_scale,1,ring_scale)
		tell.transparency=.25+sin(progress*PI*6.0)*.12
		visual_root.rotation.x=-sin(progress*PI*.5)*(.26 if enemy_type<2 else .42)
		visual_root.scale=Vector3(1.0+progress*.08,1.0-progress*.12,1.0+progress*.08)
		if attack_timer<=0:_strike()
	elif dist<attack_range-.1 and attack_cooldown<=0:_begin_attack()
	elif dist>1.35:
		velocity=off.normalized()*speed;rotation.y=atan2(-off.x,-off.z);move_and_slide()
		walk_time+=delta*speed*2.4;visual_root.position.y=abs(sin(walk_time))*.09;visual_root.rotation.z=sin(walk_time)*.065;visual_root.rotation.x=sin(walk_time*.5)*.035
		visual_root.scale=Vector3(1.0-sin(walk_time)*.025,1.0+sin(walk_time)*.035,1.0-sin(walk_time)*.025)

func take_damage(amount:float,push:Vector3)->void:
	if dead:return
	health-=amount;velocity+=push
	var number:=Label3D.new();number.text=str(int(amount));number.font_size=38;number.modulate=Color("#fff0b0");number.outline_size=8;number.position=Vector3(0,2.2,0);add_child(number)
	var float_up:=create_tween().set_parallel();float_up.tween_property(number,"position:y",3.0,.42);float_up.tween_property(number,"modulate:a",0.0,.42);float_up.chain().tween_callback(number.queue_free)
	var tw:=create_tween();tw.tween_property(body,"scale",Vector3(1.25,.72,1.25),.05);tw.tween_property(body,"scale",Vector3.ONE,.1)
	if health<=0:
		dead=true;remove_from_group("damageable")
		if get_parent().has_method("enemy_defeated"):get_parent().call("enemy_defeated",enemy_type)
		var death:=create_tween().set_parallel();death.tween_property(self,"scale",Vector3(1.35,.04,1.35),.22);death.tween_property(self,"rotation:y",rotation.y+2,.22)
		death.chain().tween_callback(queue_free)
