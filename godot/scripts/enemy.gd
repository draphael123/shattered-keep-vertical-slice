extends CharacterBody3D

var health := 70.0
var speed := 3.1
var hero: CharacterBody3D
var attack_timer := 0.0
var attack_cooldown := 0.0
var body: MeshInstance3D
var tell: MeshInstance3D
var dead := false

func _ready() -> void:
	add_to_group("damageable")
	hero = get_tree().get_first_node_in_group("hero")
	_build_skeleton()

func material(color: Color, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = 0.75
	if energy > 0:
		m.emission_enabled = true; m.emission = emission; m.emission_energy_multiplier = energy
	return m

func add_part(mesh: PrimitiveMesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new(); n.mesh = mesh; n.material_override = mat; n.position = pos; n.rotation = rot; add_child(n); return n

func _build_skeleton() -> void:
	var bone := material(Color("#afc2b8"))
	var dark := material(Color("#182a2d"))
	var glow := material(Color("#5de1d4"), Color("#5de1d4"), 2.0)
	var torso := BoxMesh.new(); torso.size = Vector3(0.72, 0.95, 0.42); body = add_part(torso, dark, Vector3(0, 1.05, 0))
	var skull := SphereMesh.new(); skull.radius = 0.28; skull.height = 0.52; add_part(skull, bone, Vector3(0, 1.8, 0))
	for x in [-0.42, 0.42]:
		var arm := CapsuleMesh.new(); arm.radius = 0.08; arm.height = 0.9
		add_part(arm, bone, Vector3(x, 1.05, 0), Vector3(0, 0, x * 0.9))
	for x in [-0.2, 0.2]:
		var leg := CapsuleMesh.new(); leg.radius = 0.09; leg.height = 0.92
		add_part(leg, bone, Vector3(x, 0.38, 0), Vector3(0, 0, x * 0.12))
	var eye := BoxMesh.new(); eye.size = Vector3(0.3, 0.06, 0.08); add_part(eye, glow, Vector3(0, 1.82, -0.25))
	var axe := BoxMesh.new(); axe.size = Vector3(0.12, 1.25, 0.1); add_part(axe, bone, Vector3(0.68, 1.05, -0.1), Vector3(0, 0, -0.55))
	var shape := CapsuleShape3D.new(); shape.radius = 0.45; shape.height = 1.5
	var col := CollisionShape3D.new(); col.shape = shape; col.position.y = 0.75; add_child(col)
	tell = MeshInstance3D.new()
	var tell_mesh := CylinderMesh.new(); tell_mesh.top_radius = 1.5; tell_mesh.bottom_radius = 1.5; tell_mesh.height = 0.025
	tell.mesh = tell_mesh; tell.material_override = material(Color(0.75,0.12,0.05,0.25), Color("#e84d2f"), 1.0)
	tell.position.y = 0.04; tell.visible = false; add_child(tell)

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(hero): return
	attack_cooldown -= delta
	var offset := hero.global_position - global_position
	var distance := offset.length()
	if attack_timer > 0:
		attack_timer -= delta
		tell.visible = true
		tell.scale = Vector3.ONE * (1.0 + (0.55 - attack_timer) * 0.45)
		if attack_timer <= 0:
			tell.visible = false
			if hero.global_position.distance_to(global_position) < 1.8:
				hero.call("take_damage", 15.0, offset.normalized() * 6.0)
			attack_cooldown = 0.8
	elif distance < 1.65 and attack_cooldown <= 0:
		attack_timer = 0.55
	elif distance > 1.35:
		velocity = offset.normalized() * speed
		rotation.y = atan2(-offset.x, -offset.z)
		move_and_slide()

func take_damage(amount: float, push: Vector3) -> void:
	if dead: return
	health -= amount
	velocity += push
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector3(1.22,0.75,1.22), 0.06)
	tween.tween_property(body, "scale", Vector3.ONE, 0.12)
	if health <= 0:
		dead = true
		remove_from_group("damageable")
		var death := create_tween().set_parallel()
		death.tween_property(self, "scale", Vector3(1.4,0.05,1.4), 0.24)
		death.tween_property(self, "rotation:y", rotation.y + 1.8, 0.24)
		death.chain().tween_callback(queue_free)
