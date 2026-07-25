extends Node3D

signal stepped(index:int)
var rune_index:=0
var hero:CharacterBody3D
var lit:=false
var locked:=false
var disc:MeshInstance3D
var color:=Color("#5a7776")

func setup(index:int)->void:rune_index=index

func _ready()->void:
	hero=get_tree().get_first_node_in_group("hero")
	disc=MeshInstance3D.new();var mesh:=CylinderMesh.new();mesh.top_radius=.72;mesh.bottom_radius=.72;mesh.height=.07;disc.mesh=mesh;disc.position.y=.05;add_child(disc);_paint(color)
	var mark:=Label3D.new();mark.text=str(rune_index+1);mark.font_size=48;mark.position=Vector3(0,.12,0);mark.rotation_degrees.x=-90;mark.modulate=Color("#d9e3dc");add_child(mark)

func _paint(c:Color)->void:
	var mat:=StandardMaterial3D.new();mat.albedo_color=c
	if c.g>.6:mat.emission_enabled=true;mat.emission=c;mat.emission_energy_multiplier=2.3
	disc.material_override=mat

func _process(_delta:float)->void:
	if not locked and is_instance_valid(hero) and hero.global_position.distance_to(global_position)<.72:
		locked=true;stepped.emit(rune_index)
	elif locked and is_instance_valid(hero) and hero.global_position.distance_to(global_position)>1.1:locked=false

func set_lit(value:bool)->void:
	lit=value;_paint(Color("#69ddd0") if lit else color)
