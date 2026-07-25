extends Node3D

const HERO = preload("res://scripts/hero.gd")
const SPAWNER = preload("res://scripts/spawner.gd")
var hero: CharacterBody3D
var health_bar: ProgressBar
var objective: Label

func _ready() -> void:
	_build_environment()
	_build_arena()
	_spawn_encounter()
	_build_ui()

func material(color: Color, emission := Color.BLACK, energy := 0.0, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color; m.roughness = 0.72; m.metallic = metallic
	if energy > 0:
		m.emission_enabled = true; m.emission = emission; m.emission_energy_multiplier = energy
	return m

func box_part(name: String, size: Vector3, pos: Vector3, mat: Material, collision := false) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = name
	var mesh := BoxMesh.new(); mesh.size = size; node.mesh = mesh; node.material_override = mat; node.position = pos; add_child(node)
	if collision:
		var body := StaticBody3D.new(); var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = size
		shape.shape = box; body.position = pos; body.add_child(shape); add_child(body)
	return node

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#061014")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#6f9292")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 1.15
	environment.fog_enabled = true
	environment.fog_light_color = Color("#17383d")
	environment.fog_density = 0.018
	env.environment = environment; add_child(env)
	var moon := DirectionalLight3D.new(); moon.light_color = Color("#8fc9c7"); moon.light_energy = 1.15; moon.rotation_degrees = Vector3(-58,-32,0); moon.shadow_enabled = true; add_child(moon)
	var camera := Camera3D.new(); camera.position = Vector3(0,16.5,15.5); camera.rotation_degrees = Vector3(-47,0,0); camera.fov = 41; camera.current = true; add_child(camera)

func _build_arena() -> void:
	var floor_mat := material(Color("#1c3032"))
	var grout := material(Color("#101e21"))
	var wall_mat := material(Color("#2c4040"))
	box_part("Floor", Vector3(28,0.35,19), Vector3(0,-0.2,0), floor_mat, true)
	for x in range(-12,13,2):
		for z in range(-8,9,2):
			box_part("Tile", Vector3(1.82,0.08,1.82), Vector3(x,0.02,z), material(Color("#20383a") if (x+z)%4==0 else Color("#1b3133")))
	box_part("NorthWall", Vector3(28,3.2,0.8), Vector3(0,1.4,-9.2), wall_mat, true)
	box_part("SouthWall", Vector3(28,2.0,0.8), Vector3(0,0.8,9.2), wall_mat, true)
	box_part("WestWall", Vector3(0.8,3.0,19), Vector3(-13.6,1.3,0), wall_mat, true)
	box_part("EastWall", Vector3(0.8,3.0,19), Vector3(13.6,1.3,0), wall_mat, true)
	for pos in [Vector3(-10,0,-6),Vector3(10,0,-6),Vector3(-10,0,6),Vector3(10,0,6)]:
		var base := box_part("Pillar",Vector3(1.1,2.4,1.1),pos+Vector3(0,1.2,0),wall_mat,true)
		var fire := OmniLight3D.new(); fire.position=pos+Vector3(0,3.0,0); fire.light_color=Color("#ff923f");fire.light_energy=3.1;fire.omni_range=7.0;add_child(fire)
		var flame := GPUParticles3D.new(); flame.position=pos+Vector3(0,2.75,0); flame.amount=38; flame.lifetime=0.8
		var process := ParticleProcessMaterial.new(); process.direction=Vector3.UP;process.spread=22;process.initial_velocity_min=1.2;process.initial_velocity_max=2.4;process.gravity=Vector3(0,0.5,0);process.color=Color("#ff8b35")
		var quad := QuadMesh.new();quad.size=Vector2(0.18,0.18);flame.process_material=process;flame.draw_pass_1=quad;add_child(flame)

func _spawn_encounter() -> void:
	hero = CharacterBody3D.new(); hero.set_script(HERO); add_child(hero); hero.position=Vector3(0,0,6)
	hero.connect("health_changed", _on_health_changed)
	for pos in [Vector3(-8,0,-5),Vector3(8,0,-5),Vector3(0,0,-3)]:
		var gate := Node3D.new(); gate.set_script(SPAWNER); add_child(gate); gate.position=pos

func _build_ui() -> void:
	var layer := CanvasLayer.new(); add_child(layer)
	var title := Label.new(); title.text="THE SHATTERED KEEP";title.position=Vector2(34,25);title.add_theme_font_size_override("font_size",20);title.modulate=Color("#e7ddc8");layer.add_child(title)
	var subtitle := Label.new();subtitle.text="MOONCRYPT // COMBAT BUILD 01";subtitle.position=Vector2(35,52);subtitle.add_theme_font_size_override("font_size",11);subtitle.modulate=Color("#6bcfc8");layer.add_child(subtitle)
	health_bar=ProgressBar.new();health_bar.position=Vector2(34,88);health_bar.size=Vector2(310,18);health_bar.max_value=135;health_bar.value=135;health_bar.show_percentage=false;layer.add_child(health_bar)
	objective=Label.new();objective.text="DESTROY THE THREE MONSTER GATES";objective.position=Vector2(875,36);objective.size=Vector2(365,40);objective.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;objective.add_theme_font_size_override("font_size",15);layer.add_child(objective)
	var controls := Label.new();controls.text="WASD  MOVE     LMB / SPACE  ATTACK     Q  SHIELD BURST     SHIFT  DASH";controls.position=Vector2(350,675);controls.modulate=Color("#9cb2ae");controls.add_theme_font_size_override("font_size",12);layer.add_child(controls)

func _process(_delta: float) -> void:
	var gates := get_tree().get_nodes_in_group("damageable").filter(func(n): return n.get_script() == SPAWNER)
	if objective:
		objective.text = "DESTROY THE MONSTER GATES  //  %d REMAIN" % gates.size()
		if gates.is_empty(): objective.text = "THE BOSS DOOR IS OPEN"

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value=maximum;health_bar.value=current
