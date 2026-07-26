extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal ability_changed(current: float, maximum: float)
signal impact(strength:float)

var hero_class := "Ironwarden"
var health := 150.0
var max_health := 150.0
var speed := 6.6
var attack_cooldown := 0.0
var ability_cooldown := 0.0
var max_ability_cooldown := 4.5
var dash_cooldown := 0.0
var invulnerable := 0.0
var facing := Vector3(0, 0, -1)
var weapon_pivot: Node3D
var body_material: StandardMaterial3D
var class_color := Color("#63d5ca")
var visual_root:Node3D
var torso_node:MeshInstance3D
var left_leg:MeshInstance3D
var right_leg:MeshInstance3D
var left_arm:MeshInstance3D
var motion_time:=0.0
var combo_step:=0
var combo_window:=0.0

func setup(selected: String) -> void:
	hero_class = selected
	match hero_class:
		"Ember Mage": max_health = 95; speed = 6.9; class_color = Color("#ff7045"); max_ability_cooldown = 4.0
		"Wildbow": max_health = 110; speed = 7.7; class_color = Color("#9bd65b"); max_ability_cooldown = 3.4
		"Dawn Cleric": max_health = 125; speed = 6.4; class_color = Color("#ffd77a"); max_ability_cooldown = 5.0
		_: max_health = 150; speed = 6.5; class_color = Color("#63d5ca"); max_ability_cooldown = 4.5
	health = max_health

func _ready() -> void:
	add_to_group("hero")
	_build_character()
	health_changed.emit(health, max_health)

func mat(color: Color, emission := Color.BLACK, energy := 0.0, metallic := 0.1) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color; m.roughness = 0.62; m.metallic = metallic
	if energy > 0.0:
		m.emission_enabled = true; m.emission = emission; m.emission_energy_multiplier = energy
	return m

func part(mesh: PrimitiveMesh, material: Material, pos: Vector3, parent: Node = self) -> MeshInstance3D:
	var n := MeshInstance3D.new(); n.mesh = mesh; n.material_override = material; n.position = pos; parent.add_child(n); return n

func _build_character() -> void:
	visual_root=Node3D.new();add_child(visual_root)
	body_material = mat(class_color.darkened(0.48))
	var torso := CapsuleMesh.new(); torso.radius = 0.43; torso.height = 1.28
	torso_node=part(torso, body_material, Vector3(0,1.02,0),visual_root)
	for x in [-.24,.24]:
		var leg_mesh:=CapsuleMesh.new();leg_mesh.radius=.12;leg_mesh.height=.72
		var leg:=part(leg_mesh,mat(class_color.darkened(.58)),Vector3(x,.35,0),visual_root)
		if x<0:left_leg=leg
		else:right_leg=leg
	var arm_mesh:=CapsuleMesh.new();arm_mesh.radius=.11;arm_mesh.height=.78
	left_arm=part(arm_mesh,mat(class_color.darkened(.35)),Vector3(-.5,1.12,0),visual_root);left_arm.rotation.z=-.18
	var mantle := CylinderMesh.new(); mantle.top_radius=.33; mantle.bottom_radius=.54; mantle.height=.32
	part(mantle, mat(class_color.darkened(.15)), Vector3(0,1.52,0),visual_root)
	var head := SphereMesh.new(); head.radius=.29; head.height=.58
	part(head, mat(Color("#d4b892")), Vector3(0,1.88,0),visual_root)
	var cape := BoxMesh.new(); cape.size=Vector3(.75,1.05,.1)
	var cape_n := part(cape, mat(class_color.darkened(.6)), Vector3(0,1.0,.36),visual_root); cape_n.rotation.x=-.16
	weapon_pivot=Node3D.new(); weapon_pivot.position=Vector3(.47,1.12,0); visual_root.add_child(weapon_pivot)
	match hero_class:
		"Ember Mage":
			var hat := CylinderMesh.new(); hat.top_radius=.05;hat.bottom_radius=.46;hat.height=.72
			part(hat,mat(Color("#4b2943")),Vector3(0,2.28,0),visual_root)
			var staff:=CylinderMesh.new();staff.top_radius=.055;staff.bottom_radius=.055;staff.height=1.65
			part(staff,mat(Color("#5d3928")),Vector3(0,.25,-.3),weapon_pivot)
			var orb:=SphereMesh.new();orb.radius=.2;orb.height=.4
			part(orb,mat(class_color,class_color,3.5),Vector3(0,1.08,-.3),weapon_pivot)
		"Wildbow":
			var hood:=SphereMesh.new();hood.radius=.36;hood.height=.67
			part(hood,mat(Color("#31462d")),Vector3(0,1.98,.04),visual_root)
			var bow:=TorusMesh.new();bow.inner_radius=.44;bow.outer_radius=.51
			var b:=part(bow,mat(Color("#9b673d")),Vector3(0,.24,-.3),weapon_pivot);b.scale.x=.5;b.rotation.x=PI/2
		"Dawn Cleric":
			var crown:=CylinderMesh.new();crown.top_radius=.31;crown.bottom_radius=.36;crown.height=.25
			part(crown,mat(Color("#d8b55c")),Vector3(0,2.13,0),visual_root)
			var mace:=CylinderMesh.new();mace.top_radius=.08;mace.bottom_radius=.08;mace.height=1.1
			part(mace,mat(Color("#ddd4b2")),Vector3(0,.2,-.3),weapon_pivot)
			var sun:=SphereMesh.new();sun.radius=.22;sun.height=.44
			part(sun,mat(class_color,class_color,2.5),Vector3(0,.8,-.3),weapon_pivot)
		_:
			var helm:=CylinderMesh.new();helm.top_radius=.27;helm.bottom_radius=.34;helm.height=.3
			part(helm,mat(Color("#9cadad")),Vector3(0,2.1,0),visual_root)
			var blade:=BoxMesh.new();blade.size=Vector3(.12,1.35,.08)
			var bn:=part(blade,mat(Color("#e6eee7"),class_color,.3),Vector3(0,.42,-.32),weapon_pivot);bn.rotation.x=.42
			var shield:=CylinderMesh.new();shield.top_radius=.48;shield.bottom_radius=.48;shield.height=.12
			var sn:=part(shield,mat(Color("#45616c"),class_color,.25),Vector3(-.55,1.08,-.08),visual_root);sn.rotation.z=PI/2
	var shape:=CapsuleShape3D.new();shape.radius=.43;shape.height=1.5
	var col:=CollisionShape3D.new();col.shape=shape;col.position.y=.75;add_child(col)

func _physics_process(delta: float) -> void:
	attack_cooldown -= delta; ability_cooldown -= delta; dash_cooldown -= delta; invulnerable -= delta
	combo_window-=delta
	if combo_window<=0:combo_step=0
	ability_changed.emit(max(ability_cooldown,0),max_ability_cooldown)
	var input:=Input.get_vector("move_left","move_right","move_up","move_down")
	var direction:=Vector3(input.x,0,input.y)
	if direction.length()>.1:
		direction=direction.normalized();facing=direction;rotation.y=atan2(-facing.x,-facing.z)
	velocity=direction*speed;move_and_slide()
	motion_time+=delta*(velocity.length()*.9+1.0)
	var moving:=direction.length()>.1
	visual_root.position.y=sin(motion_time*1.7)*(.055 if moving else .025)
	var stride:=sin(motion_time*2.4)*(.55 if moving else .04)
	left_leg.rotation.x=stride;right_leg.rotation.x=-stride;left_arm.rotation.x=-stride*.7
	torso_node.rotation.z=sin(motion_time*2.4)*(.035 if moving else .012)
	global_position.x=clamp(global_position.x,-11.6,11.6);global_position.z=clamp(global_position.z,-45.0,7.6)
	if Input.is_action_pressed("attack") and attack_cooldown<=0:_attack()
	if Input.is_action_just_pressed("ability"):_ability()
	if Input.is_action_just_pressed("dash") and dash_cooldown<=0:
		velocity=facing*19.0;move_and_slide();dash_cooldown=.85;invulnerable=.3
		_burst(class_color,.55)

func _attack() -> void:
	attack_cooldown = .36 if hero_class!="Wildbow" else .26
	var range_value:=2.4
	var damage:=32.0
	if hero_class=="Ember Mage": range_value=7.5;damage=25
	if hero_class=="Wildbow": range_value=9.0;damage=20
	if hero_class=="Dawn Cleric": damage=28
	combo_step=(combo_step%3)+1;combo_window=.72
	if combo_step==3:damage*=1.55;attack_cooldown+=.12
	var direction_sign:float=-1.0 if combo_step%2==0 else 1.0
	var tween:=create_tween();weapon_pivot.rotation.z=-.8*direction_sign
	tween.tween_property(weapon_pivot,"rotation:z",1.0*direction_sign,.1 if combo_step<3 else .16).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(weapon_pivot,"rotation:z",0.0,.14 if combo_step<3 else .2).set_trans(Tween.TRANS_BACK)
	if range_value>3:
		_projectile(damage,range_value)
	else:
		await get_tree().create_timer(.07).timeout
		_damage_cone(damage,range_value,.05)

func _projectile(damage: float, range_value: float) -> void:
	var bolt:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.14;mesh.height=.28
	bolt.mesh=mesh;bolt.material_override=mat(class_color,class_color,4.0);get_parent().add_child(bolt)
	bolt.global_position=global_position+Vector3(0,1.0,0)+facing*.8
	var end:=bolt.global_position+facing*range_value
	var travel:=create_tween();travel.tween_property(bolt,"global_position",end,.25)
	for target in get_tree().get_nodes_in_group("damageable"):
		if is_instance_valid(target):
			var offset:Vector3=target.global_position-global_position
			if offset.length()<range_value and facing.dot(offset.normalized())>.87:
				target.call("take_damage",damage,facing*6);break
	impact.emit(.35)
	travel.tween_callback(bolt.queue_free)

func _damage_cone(damage:float, reach:float, dot_limit:float)->void:
	for target in get_tree().get_nodes_in_group("damageable"):
		if is_instance_valid(target):
			var offset:Vector3=target.global_position-global_position
			if offset.length()<reach and facing.dot(offset.normalized())>dot_limit:target.call("take_damage",damage,facing*8)
	impact.emit(.5)

func _ability() -> void:
	if ability_cooldown>0:return
	ability_cooldown=max_ability_cooldown
	match hero_class:
		"Ember Mage":
			for target in get_tree().get_nodes_in_group("damageable"):
				if is_instance_valid(target) and target.global_position.distance_to(global_position)<5.0:
					target.call("take_damage",48,(target.global_position-global_position).normalized()*10)
			_burst(class_color,5.0)
		"Wildbow":
			for angle in [-.28,0,.28]:
				var direction:=facing.rotated(Vector3.UP,angle)
				for target in get_tree().get_nodes_in_group("damageable"):
					if is_instance_valid(target):
						var off:Vector3=target.global_position-global_position
						if off.length()<10 and direction.dot(off.normalized())>.94:target.call("take_damage",42,direction*7)
			_burst(class_color,3.2)
		"Dawn Cleric":
			health=min(max_health,health+42);health_changed.emit(health,max_health);_burst(class_color,3.8)
			for target in get_tree().get_nodes_in_group("damageable"):
				if is_instance_valid(target) and target.global_position.distance_to(global_position)<3.8:target.call("take_damage",30,(target.global_position-global_position).normalized()*8)
		_:
			_damage_cone(28,3.8,-1);invulnerable=.65;_burst(class_color,3.8)

func _burst(color:Color, size:float)->void:
	var ring:=MeshInstance3D.new();var rm:=TorusMesh.new();rm.inner_radius=.85;rm.outer_radius=1.02
	ring.mesh=rm;ring.material_override=mat(color,color,3.2);ring.position.y=.12;add_child(ring)
	var tw:=create_tween().set_parallel();tw.tween_property(ring,"scale",Vector3.ONE*size,.35);tw.tween_property(ring,"transparency",1.0,.35)
	tw.chain().tween_callback(ring.queue_free)

func take_damage(amount:float,push:Vector3)->void:
	if invulnerable>0:return
	health=max(0,health-amount);velocity+=push;invulnerable=.38;health_changed.emit(health,max_health)
	var tw:=create_tween();tw.tween_property(self,"scale",Vector3(1.15,.85,1.15),.06);tw.tween_property(self,"scale",Vector3.ONE,.12)
	if health<=0:
		global_position=Vector3(0,0,6);health=max_health;health_changed.emit(health,max_health)

func heal(amount:float)->void:
	health=min(max_health,health+amount);health_changed.emit(health,max_health);_burst(Color("#e84f49"),1.8)
