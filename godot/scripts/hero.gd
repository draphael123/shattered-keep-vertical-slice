extends CharacterBody3D

signal health_changed(current: float, maximum: float)

var health := 135.0
var max_health := 135.0
var speed := 6.4
var attack_cooldown := 0.0
var ability_cooldown := 0.0
var dash_cooldown := 0.0
var invulnerable := 0.0
var facing := Vector3(0, 0, -1)
var weapon_pivot: Node3D
var body_material: StandardMaterial3D
var hit_flash := 0.0

func _ready() -> void:
	add_to_group("hero")
	_build_ironwarden()

func mat(color: Color, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.68
	m.metallic = 0.15
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m

func mesh_part(mesh: PrimitiveMesh, material: Material, pos: Vector3, parent: Node = self) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = pos
	parent.add_child(part)
	return part

func _build_ironwarden() -> void:
	body_material = mat(Color("#536c78"))
	var shadow := Decal.new()
	var torso := CapsuleMesh.new(); torso.radius = 0.42; torso.height = 1.25
	mesh_part(torso, body_material, Vector3(0, 0.98, 0))
	var cape := BoxMesh.new(); cape.size = Vector3(0.78, 1.05, 0.12)
	var cape_node := mesh_part(cape, mat(Color("#253a43")), Vector3(0, 0.98, 0.32))
	cape_node.rotation.x = -0.14
	var head := SphereMesh.new(); head.radius = 0.29; head.height = 0.58
	mesh_part(head, mat(Color("#bda986")), Vector3(0, 1.87, 0))
	var helm := CylinderMesh.new(); helm.top_radius = 0.28; helm.bottom_radius = 0.33; helm.height = 0.28
	mesh_part(helm, mat(Color("#9cadad")), Vector3(0, 2.08, 0))
	weapon_pivot = Node3D.new(); weapon_pivot.position = Vector3(0.48, 1.15, 0); add_child(weapon_pivot)
	var blade := BoxMesh.new(); blade.size = Vector3(0.12, 1.35, 0.08)
	var blade_node := mesh_part(blade, mat(Color("#d9e2dd"), Color("#bceee7"), 0.25), Vector3(0, 0.46, -0.34), weapon_pivot)
	blade_node.rotation.x = 0.45
	var shield := CylinderMesh.new(); shield.top_radius = 0.48; shield.bottom_radius = 0.48; shield.height = 0.12
	var shield_node := mesh_part(shield, mat(Color("#45616c"), Color("#63d5ca"), 0.35), Vector3(-0.52, 1.08, -0.08))
	shield_node.rotation.z = PI / 2.0
	var shape := CapsuleShape3D.new(); shape.radius = 0.42; shape.height = 1.45
	var collider := CollisionShape3D.new(); collider.shape = shape; collider.position.y = 0.75; add_child(collider)

func _physics_process(delta: float) -> void:
	attack_cooldown -= delta
	ability_cooldown -= delta
	dash_cooldown -= delta
	invulnerable -= delta
	hit_flash -= delta
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector3(input.x, 0, input.y)
	if direction.length() > 0.1:
		direction = direction.normalized()
		facing = direction
		rotation.y = atan2(-facing.x, -facing.z)
	velocity = direction * speed
	move_and_slide()
	global_position.x = clamp(global_position.x, -12.5, 12.5)
	global_position.z = clamp(global_position.z, -8.0, 8.0)
	if Input.is_action_just_pressed("attack"):
		_attack()
	if Input.is_action_just_pressed("ability"):
		_shield_burst()
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0.0:
		velocity = facing * 18.0
		move_and_slide()
		dash_cooldown = 1.0
		invulnerable = 0.32

func _attack() -> void:
	if attack_cooldown > 0.0: return
	attack_cooldown = 0.42
	var tween := create_tween()
	weapon_pivot.rotation.z = -0.85
	tween.tween_property(weapon_pivot, "rotation:z", 1.1, 0.13).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(weapon_pivot, "rotation:z", 0.0, 0.18).set_trans(Tween.TRANS_BACK)
	await get_tree().create_timer(0.09).timeout
	for target in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(target): continue
		var offset: Vector3 = target.global_position - global_position
		if offset.length() < 2.35 and facing.dot(offset.normalized()) > 0.15:
			target.call("take_damage", 34.0, facing * 7.5)

func _shield_burst() -> void:
	if ability_cooldown > 0.0: return
	ability_cooldown = 4.5
	for target in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(target): continue
		var offset: Vector3 = target.global_position - global_position
		if offset.length() < 3.7:
			target.call("take_damage", 24.0, offset.normalized() * 13.0)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new(); ring_mesh.inner_radius = 0.94; ring_mesh.outer_radius = 1.08
	ring.mesh = ring_mesh; ring.material_override = mat(Color("#8bf3e8"), Color("#8bf3e8"), 3.0)
	ring.position.y = 0.12; add_child(ring)
	var tween := create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(4, 4, 4), 0.35)
	tween.tween_property(ring, "transparency", 1.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)

func take_damage(amount: float, push: Vector3) -> void:
	if invulnerable > 0.0: return
	health = max(0.0, health - amount)
	velocity += push
	invulnerable = 0.42
	hit_flash = 0.15
	health_changed.emit(health, max_health)
	if health <= 0.0:
		global_position = Vector3(0, 0, 6)
		health = max_health
		health_changed.emit(health, max_health)
