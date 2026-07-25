extends Node3D

var pickup_type := 0
var hero: CharacterBody3D
var mesh_node: MeshInstance3D

func setup(kind:int)->void: pickup_type=kind

func _ready()->void:
	hero=get_tree().get_first_node_in_group("hero")
	mesh_node=MeshInstance3D.new()
	if pickup_type==0:
		var mesh:=SphereMesh.new();mesh.radius=.24;mesh.height=.48;mesh_node.mesh=mesh
	else:
		var mesh:=CylinderMesh.new();mesh.top_radius=.2;mesh.bottom_radius=.2;mesh.height=.08;mesh_node.mesh=mesh
	var mat:=StandardMaterial3D.new();var color:=Color("#e84f49") if pickup_type==0 else Color("#f2cb5f")
	mat.albedo_color=color;mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=2.2
	mesh_node.material_override=mat;mesh_node.position.y=.45;add_child(mesh_node)

func _process(delta:float)->void:
	mesh_node.rotation.y+=delta*2.8;mesh_node.position.y=.45+sin(Time.get_ticks_msec()*.005)*.08
	if is_instance_valid(hero) and hero.global_position.distance_to(global_position)<.85:
		if pickup_type==0:hero.call("heal",25.0)
		elif get_parent().has_method("collect_treasure"):get_parent().call("collect_treasure",500)
		queue_free()
