class_name StageBuilder
extends RefCounted
## Construye el escenario de cada época (res://data/escenarios.json): entorno, iluminación de
## estudio (clave, relleno y contraluz), suelo y decorado procedural según su "motivo".

const SUELO := preload("res://shaders/suelo.gdshader")

var fabrics: FabricLibrary
var shadow_quality := true


func _init(p_fabrics: FabricLibrary = null) -> void:
	fabrics = p_fabrics if p_fabrics != null else FabricLibrary.new({})


func build(stage: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Escenario_%s" % stage.get("id", "")
	var col: Dictionary = stage.get("colores", {})
	var floor_c := Color.html(str(col.get("suelo", "#555555")))
	var wall_c := Color.html(str(col.get("pared", "#777777")))
	var accent := Color.html(str(col.get("acento", "#C9A961")))
	var detail := Color.html(str(col.get("detalle", "#EEEEEE")))
	_environment(root, stage.get("luz", {}), wall_c)
	_lights(root, stage.get("luz", {}))
	match str(stage.get("motivo", "atelier")):
		"arcos":
			_floor(root, floor_c, floor_c.darkened(0.25), 1, 1.6, 0.85)
			_wall(root, wall_c, "liso")
			for x in [-1.6, 0.0, 1.6]:
				_gothic_arch(root, Vector3(x, 0, -2.2), wall_c.darkened(0.2))
			_panel(root, Vector3(-0.8, 1.55, -2.12), Vector2(1.1, 1.9), accent, detail, "damasco", "brocado")
			_panel(root, Vector3(0.8, 1.55, -2.12), Vector2(1.1, 1.9), accent, detail, "damasco", "brocado")
		"modernista":
			_floor(root, floor_c, floor_c.darkened(0.2), 2, 3.0, 0.5)
			_wall(root, wall_c, "damasco", accent.lerp(wall_c, 0.7), 5.0)
			_box(root, Vector3(0, 0.45, -2.15), Vector3(6.0, 0.9, 0.08), floor_c.darkened(0.1), 0.45)
			_mirror(root, Vector3(1.35, 1.55, -2.08), detail)
		"deco":
			_floor(root, floor_c, floor_c.lightened(0.08), 2, 3.0, 0.3)
			_wall(root, wall_c, "deco", accent.darkened(0.35), 9.0)
			for k in 3:
				_box(root, Vector3(0, 1.4 + 0.35 * k, -2.18 + 0.02 * k), Vector3(2.6 - 0.6 * k, 0.12, 0.05), accent, 0.3, 0.9)
		"escalera":
			_floor(root, floor_c, floor_c, 4, 1.0, 0.08)
			_wall(root, wall_c, "liso")
			for k in 7:
				var a := deg_to_rad(-40.0 + k * 7.0)
				_box(root, Vector3(1.6 + 1.6 * sin(a), 0.09 + 0.18 * k, -1.6 + 1.6 * cos(a) - 1.4), Vector3(1.4, 0.18, 0.42),
					detail.lightened(0.85), 0.4).rotation.y = a
		"paneles":
			_floor(root, floor_c, floor_c.darkened(0.15), 2, 3.0, 0.6)
			_panel(root, Vector3(-1.5, 1.4, -2.15), Vector2(3.0, 2.8), floor_c.lightened(0.15), floor_c, "rayas", "lino")
			_panel(root, Vector3(1.5, 1.4, -2.15), Vector2(3.0, 2.8), wall_c, detail, "liso", "lino")
			for x in [0.6, 1.5, 2.4]:
				_box(root, Vector3(x, 1.4, -2.1), Vector3(0.06, 2.4, 0.04), detail, 0.5)
		"atomico":
			_floor(root, floor_c, accent.lightened(0.3), 3, 2.0, 0.35)
			_wall(root, wall_c, "liso")
			_starburst(root, Vector3(-1.2, 1.9, -2.1), detail)
			_starburst(root, Vector3(1.4, 1.5, -2.1), accent.darkened(0.2))
		"capsula":
			_floor(root, floor_c, floor_c, 4, 1.0, 0.15)
			_curved_wall(root, wall_c)
			_disc(root, Vector3(0, 1.5, -2.05), 1.0, accent, detail, "op_art")
			for x in [-2.0, 2.0]:
				_disc(root, Vector3(x, 1.7, -1.7), 0.35, Color(0.12, 0.14, 0.18), Color(0.12, 0.14, 0.18), "liso")
		"memphis":
			_floor(root, floor_c, floor_c, 4, 1.0, 0.1)
			_wall(root, wall_c, "liso")
			_box(root, Vector3(-1.6, 0.6, -1.8), Vector3(0.6, 1.2, 0.6), accent, 0.4)
			_box(root, Vector3(1.7, 0.35, -1.6), Vector3(0.9, 0.7, 0.5), detail, 0.4).rotation.y = 0.4
			_neon(root, Vector3(-1.2, 2.2, -2.1), 1.6, accent)
			_neon(root, Vector3(1.1, 1.6, -2.1), 1.2, detail)
		"ciclorama":
			_cyclorama(root, wall_c)
			for x in [-2.2, 2.2]:
				_softbox(root, Vector3(x, 1.6, -0.4))
		_:
			_floor(root, floor_c, floor_c.darkened(0.2), 2, 2.5, 0.55)
			_wall(root, wall_c, "liso")
			_mirror(root, Vector3(-1.5, 1.2, -2.05), accent)
	return root


func _environment(root: Node3D, luz: Dictionary, bg: Color) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg.darkened(0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.html(str(luz.get("ambiente", "#404040")))
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.04
	we.environment = env
	root.add_child(we)


func _lights(root: Node3D, luz: Dictionary) -> void:
	var color := Color.html(str(luz.get("color", "#FFFFFF")))
	var energy := float(luz.get("intensidad", 1.0))
	var key := DirectionalLight3D.new()
	key.name = "LuzClave"
	key.light_color = color
	key.light_energy = 1.05 * energy
	key.rotation_degrees = Vector3(-38, 32, 0)
	key.shadow_enabled = shadow_quality
	key.directional_shadow_max_distance = 8.0
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "LuzRelleno"
	fill.light_color = Color.html(str(luz.get("relleno", "#A0B0C8")))
	fill.light_energy = 0.32 * energy
	fill.rotation_degrees = Vector3(-12, -128, 0)
	root.add_child(fill)
	var rim := OmniLight3D.new()
	rim.name = "Contraluz"
	rim.light_color = color
	rim.light_energy = 1.4 * energy
	rim.omni_range = 4.0
	rim.position = Vector3(-0.8, 2.3, -1.4)
	root.add_child(rim)
	if luz.get("foco", false):
		var spot := SpotLight3D.new()
		spot.name = "Foco"
		spot.light_energy = 2.2 * energy
		spot.spot_angle = 22.0
		spot.spot_range = 7.0
		spot.position = Vector3(0, 4.2, 1.2)
		spot.rotation_degrees = Vector3(-72, 0, 0)
		spot.shadow_enabled = shadow_quality
		root.add_child(spot)


func _mat(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _floor(root: Node3D, a: Color, b: Color, mode: int, scale: float, rough: float) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Suelo"
	var pm := PlaneMesh.new()
	pm.size = Vector2(9, 7)
	mi.mesh = pm
	mi.position.z = 0.6
	var m := ShaderMaterial.new()
	m.shader = SUELO
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("modo", mode)
	m.set_shader_parameter("escala", scale)
	m.set_shader_parameter("rugosidad", rough)
	mi.material_override = m
	root.add_child(mi)


func _wall(root: Node3D, c: Color, pattern: String, c2: Color = Color.BLACK, pattern_scale: float = 4.0) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Pared"
	var qm := QuadMesh.new()
	qm.size = Vector2(9, 4.5)
	mi.mesh = qm
	mi.position = Vector3(0, 2.25, -2.2)
	if pattern == "liso":
		mi.material_override = _mat(c, 0.85)
	else:
		var m := fabrics.fabric_material("algodon", c, c2, pattern)
		m.set_shader_parameter("escala_estampado", pattern_scale)
		m.set_shader_parameter("ligamento_modo", -1)
		m.set_shader_parameter("costura_intensidad", 0.0)
		mi.material_override = m
	root.add_child(mi)


func _panel(root: Node3D, pos: Vector3, size: Vector2, c: Color, c2: Color, pattern: String, fabric: String) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.position = pos
	var m := fabrics.fabric_material(fabric, c, c2, pattern)
	m.set_shader_parameter("costura_intensidad", 0.0)
	mi.material_override = m
	root.add_child(mi)


func _box(root: Node3D, pos: Vector3, size: Vector3, c: Color, rough: float, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c, rough, metal)
	root.add_child(mi)
	return mi


func _gothic_arch(root: Node3D, base: Vector3, c: Color) -> void:
	for s in [-1.0, 1.0]:
		_box(root, base + Vector3(0.55 * s, 1.2, 0.05), Vector3(0.22, 2.4, 0.22), c, 0.9)
		var rib := _box(root, base + Vector3(0.3 * s, 2.72, 0.05), Vector3(0.18, 0.75, 0.2), c, 0.9)
		rib.rotation.z = -0.62 * s


func _mirror(root: Node3D, pos: Vector3, frame_c: Color) -> void:
	var frame := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	frame.mesh = tm
	frame.position = pos
	frame.rotation_degrees = Vector3(90, 0, 0)
	frame.scale = Vector3(1, 1, 1.5)
	frame.material_override = _mat(Color(1.0, 0.8, 0.42), 0.3, 1.0)
	root.add_child(frame)
	var glass := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.43
	dm.bottom_radius = 0.43
	dm.height = 0.01
	glass.mesh = dm
	glass.position = pos + Vector3(0, 0, -0.01)
	glass.rotation_degrees = Vector3(90, 0, 0)
	glass.scale = Vector3(1, 1, 1.5)
	glass.material_override = _mat(Color(0.75, 0.8, 0.85), 0.04, 1.0)
	root.add_child(glass)


func _starburst(root: Node3D, center: Vector3, c: Color) -> void:
	for k in 12:
		var ray := _box(root, center, Vector3(0.02, 0.6 if k % 2 == 0 else 0.38, 0.02), c, 0.3, 0.8)
		ray.rotation.z = TAU * k / 12.0
	var core := MeshInstance3D.new()
	core.mesh = SphereMesh.new()
	core.scale = Vector3.ONE * 0.12
	core.position = center
	core.material_override = _mat(c, 0.25, 0.9)
	root.add_child(core)


func _disc(root: Node3D, pos: Vector3, radius: float, c: Color, c2: Color, pattern: String) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 48
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	if pattern == "liso":
		mi.material_override = _mat(c, 0.2)
	else:
		var m := fabrics.fabric_material("plastico", c2, c, pattern)
		m.set_shader_parameter("escala_estampado", 6.0)
		m.set_shader_parameter("costura_intensidad", 0.0)
		mi.material_override = m
	root.add_child(mi)


func _curved_wall(root: Node3D, c: Color) -> void:
	var mesh := MeshKit.lathe({"segments": 40, "rings": 4, "theta_start": PI * 0.62, "theta_end": PI * 1.38,
		"y_bottom": 0.0, "y_top": 3.6, "radius": func(_th: float, _y: float, _t: float) -> Vector2: return Vector2(3.0, 2.6),
		"inward": true})
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.z = 0.4
	mi.material_override = _mat(c, 0.15)
	root.add_child(mi)


func _neon(root: Node3D, pos: Vector3, length: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.025
	cap.height = length
	mi.mesh = cap
	mi.position = pos
	mi.rotation_degrees = Vector3(0, 0, 90)
	var m := _mat(c, 0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	mi.material_override = m
	root.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 0.8
	light.omni_range = 2.2
	light.position = pos + Vector3(0, 0, 0.3)
	root.add_child(light)


func _cyclorama(root: Node3D, c: Color) -> void:
	# Perfil (z, y): suelo plano, curva de 1,2 m de radio y pared vertical, sin esquinas.
	var profile: Array[Vector2] = [Vector2(3.0, 0.0), Vector2(-1.0, 0.0)]
	for i in range(1, 17):
		var a := PI * 0.5 * i / 16.0
		profile.append(Vector2(-1.0 - 1.2 * sin(a), 1.2 - 1.2 * cos(a)))
	profile.append(Vector2(-2.2, 4.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var a2: Vector2 = profile[i]
		var b2: Vector2 = profile[i + 1]
		for v in [Vector3(-4.5, a2.y, a2.x), Vector3(-4.5, b2.y, b2.x), Vector3(4.5, a2.y, a2.x),
				Vector3(4.5, a2.y, a2.x), Vector3(-4.5, b2.y, b2.x), Vector3(4.5, b2.y, b2.x)]:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Ciclorama"
	mi.mesh = st.commit()
	var m := _mat(c, 0.9)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	root.add_child(mi)


func _softbox(root: Node3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.7, 1.0)
	mi.mesh = qm
	mi.position = pos
	mi.look_at_from_position(pos, Vector3(0, 1.2, 0), Vector3.UP)
	var m := _mat(Color.WHITE, 0.5)
	m.emission_enabled = true
	m.emission = Color(1, 0.98, 0.95)
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	root.add_child(mi)
	var light := OmniLight3D.new()
	light.light_energy = 0.9
	light.omni_range = 4.0
	light.position = pos + (Vector3(0, 1.2, 0) - pos).normalized() * 0.3
	root.add_child(light)
