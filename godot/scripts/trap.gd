extends Node3D

var hero:CharacterBody3D
var timer:=0.0
var active_time:=0.0
var plate:MeshInstance3D

func _ready()->void:
	hero=get_tree().get_first_node_in_group("hero")
	plate=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(1.65,.08,1.65);plate.mesh=mesh;plate.position.y=.05;add_child(plate)
	_set_color(Color("#3a2926"))

func _set_color(color:Color)->void:
	var mat:=StandardMaterial3D.new();mat.albedo_color=color
	if color.r>.5:mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=1.4
	plate.material_override=mat

func _process(delta:float)->void:
	timer+=delta
	var phase:=fmod(timer,2.25)
	if phase>1.45 and active_time<=0:
		active_time=.5;_set_color(Color("#d64b32"))
		var spikes:=create_tween();spikes.tween_property(plate,"position:y",.28,.08);spikes.tween_property(plate,"position:y",.05,.3)
	active_time-=delta
	if active_time>0 and is_instance_valid(hero) and hero.global_position.distance_to(global_position)<1.0:
		hero.call("take_damage",18.0,(hero.global_position-global_position).normalized()*5);active_time=-.5
	if phase<1.35:_set_color(Color("#3a2926"))
