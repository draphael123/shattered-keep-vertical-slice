extends Node3D

const ENEMY = preload("res://scripts/enemy.gd")
var health := 260.0
var spawn_timer := 1.6
var active := true
var core: MeshInstance3D

func _ready() -> void:
	add_to_group("damageable")
	add_to_group("gate")
	_build_gate()

func material(color: Color, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = 0.58
	if energy > 0:
		m.emission_enabled = true; m.emission = emission; m.emission_energy_multiplier = energy
	return m

func _build_gate() -> void:
	var stone := material(Color("#263b3d"))
	var rune := material(Color("#4ee1d5"), Color("#4ee1d5"), 3.2)
	for i in 4:
		var pillar := MeshInstance3D.new()
		var box := BoxMesh.new(); box.size = Vector3(0.45, 2.3, 0.45)
		pillar.mesh = box; pillar.material_override = stone
		pillar.position = Vector3(cos(i*PI/2.0)*0.8, 1.05, sin(i*PI/2.0)*0.8)
		pillar.rotation.z = cos(i*PI/2.0)*0.22; pillar.rotation.x = sin(i*PI/2.0)*0.22
		add_child(pillar)
	core = MeshInstance3D.new()
	var sphere := SphereMesh.new(); sphere.radius = 0.52; sphere.height = 1.04
	core.mesh = sphere; core.material_override = rune; core.position.y = 1.0; add_child(core)

func _process(delta: float) -> void:
	if not active: return
	core.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec()*0.006)*0.12)
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = 3.4
		var enemy := CharacterBody3D.new()
		enemy.set_script(ENEMY)
		get_parent().add_child(enemy)
		enemy.global_position = global_position + Vector3(randf_range(-0.7,0.7),0,randf_range(-0.7,0.7))

func take_damage(amount: float, _push: Vector3) -> void:
	if not active: return
	health -= amount
	var tween := create_tween()
	tween.tween_property(core, "scale", Vector3.ONE*1.45, 0.06)
	tween.tween_property(core, "scale", Vector3.ONE, 0.13)
	if health <= 0:
		active = false
		remove_from_group("damageable")
		remove_from_group("gate")
		var death := create_tween().set_parallel()
		death.tween_property(self, "scale", Vector3.ZERO, 0.38).set_trans(Tween.TRANS_BACK)
		death.tween_property(self, "rotation:y", rotation.y + 2.5, 0.38)
		death.chain().tween_callback(queue_free)
