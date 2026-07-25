extends Node3D

var health := 38.0
var body: MeshInstance3D
var accent: Color = Color("#b97842")

func setup(kind := 0) -> void:
	accent = Color("#a67843") if kind == 0 else Color("#597574")

func _ready() -> void:
	add_to_group("damageable")
	var wood := StandardMaterial3D.new(); wood.albedo_color = accent; wood.roughness = .88
	var dark := StandardMaterial3D.new(); dark.albedo_color = accent.darkened(.5); dark.roughness = .8
	body = MeshInstance3D.new()
	var crate := BoxMesh.new(); crate.size = Vector3(.92,.82,.92)
	body.mesh = crate; body.material_override = wood; body.position.y = .42; add_child(body)
	for y in [.12,.68]:
		var band := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = Vector3(1.0,.09,1.0)
		band.mesh = mesh; band.material_override = dark; band.position.y = y; add_child(band)
	var shape := BoxShape3D.new(); shape.size = Vector3(.92,.82,.92)
	var blocker := StaticBody3D.new(); var col := CollisionShape3D.new(); col.shape = shape; col.position.y=.42
	blocker.add_child(col); add_child(blocker)

func take_damage(amount:float,_push:Vector3)->void:
	health-=amount
	var tw:=create_tween();tw.tween_property(body,"scale",Vector3(1.15,.75,1.15),.05);tw.tween_property(body,"scale",Vector3.ONE,.1)
	if health<=0:
		remove_from_group("damageable")
		if get_parent().has_method("breakable_destroyed"):get_parent().call("breakable_destroyed",global_position)
		var death:=create_tween().set_parallel();death.tween_property(self,"scale",Vector3(1.5,.05,1.5),.2);death.tween_property(self,"rotation:y",rotation.y+1.5,.2)
		death.chain().tween_callback(queue_free)
