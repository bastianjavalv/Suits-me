class_name Mannequin
extends Node3D
## Maniquí de exhibición procedural de estilo museístico: figura femenina de 1,77 m con proporciones
## anatómicas realistas (unas 7,7 cabezas), articulado para poses. El frente mira a +Z, así que su
## lado derecho queda en -X.
##
## Las prendas se acoplan a las articulaciones ("tronco", "cuello", "cabeza", "hombro_d/i",
## "codo_d/i", "muneca_d/i", "cadera_d/i", "rodilla_d/i", "tobillo_d/i").

const HEIGHT := 1.77
const HEAD_SCALE := 0.93
const TRUNK_PIVOT := Vector3(0.0, 0.95, 0.0)

## Perfil del tronco: Vector3(altura, radio X, radio Z) en metros (contornos aproximados:
## cadera 95 cm, cintura 72 cm, busto 89 cm).
const TORSO_PROFILE := [
	Vector3(0.775, 0.060, 0.050), Vector3(0.800, 0.135, 0.092), Vector3(0.840, 0.163, 0.106),
	Vector3(0.900, 0.174, 0.110), Vector3(0.970, 0.158, 0.105), Vector3(1.040, 0.130, 0.094),
	Vector3(1.100, 0.134, 0.097), Vector3(1.170, 0.148, 0.103), Vector3(1.240, 0.155, 0.105),
	Vector3(1.310, 0.160, 0.103), Vector3(1.360, 0.162, 0.096), Vector3(1.390, 0.152, 0.089),
	Vector3(1.420, 0.128, 0.078), Vector3(1.445, 0.095, 0.064), Vector3(1.465, 0.062, 0.054),
	Vector3(1.472, 0.056, 0.052),
]
const NECK_PROFILE := [Vector3(-0.02, 0.058, 0.054), Vector3(0.04, 0.049, 0.047), Vector3(0.10, 0.044, 0.045)]
const HEAD_PROFILE := [
	Vector3(-0.030, 0.030, 0.034), Vector3(-0.005, 0.052, 0.066), Vector3(0.040, 0.064, 0.082),
	Vector3(0.080, 0.071, 0.088), Vector3(0.110, 0.074, 0.090), Vector3(0.150, 0.074, 0.089),
	Vector3(0.180, 0.067, 0.080), Vector3(0.200, 0.050, 0.061), Vector3(0.212, 0.026, 0.032),
	Vector3(0.2165, 0.002, 0.002),
]
## Brazos y piernas: perfiles locales a lo largo de -Y desde la articulación.
const UPPER_ARM := [Vector3(-0.290, 0.036, 0.038), Vector3(-0.150, 0.044, 0.046), Vector3(-0.040, 0.048, 0.050), Vector3(0.010, 0.046, 0.047)]
const FOREARM := [Vector3(-0.250, 0.024, 0.020), Vector3(-0.180, 0.028, 0.025), Vector3(-0.060, 0.037, 0.034), Vector3(0.015, 0.035, 0.034)]
const THIGH := [Vector3(-0.385, 0.049, 0.051), Vector3(-0.230, 0.068, 0.070), Vector3(-0.090, 0.084, 0.086), Vector3(0.040, 0.088, 0.090)]
const SHIN := [Vector3(-0.400, 0.028, 0.030), Vector3(-0.260, 0.038, 0.040), Vector3(-0.110, 0.051, 0.056), Vector3(0.015, 0.048, 0.050)]

const ARM_LENGTH := [0.29, 0.25]
const LEG_LENGTH := [0.385, 0.40]

const JOINT_LAYOUT := {
	# nombre: [padre, posición absoluta en reposo]
	"tronco": ["", Vector3(0.0, 0.95, 0.0)],
	"cuello": ["tronco", Vector3(0.0, 1.455, 0.0)],
	"cabeza": ["cuello", Vector3(0.0, 1.555, 0.008)],
	"hombro_d": ["tronco", Vector3(-0.168, 1.385, -0.004)],
	"hombro_i": ["tronco", Vector3(0.168, 1.385, -0.004)],
	"codo_d": ["hombro_d", Vector3(-0.168, 1.095, -0.004)],
	"codo_i": ["hombro_i", Vector3(0.168, 1.095, -0.004)],
	"muneca_d": ["codo_d", Vector3(-0.168, 0.845, -0.004)],
	"muneca_i": ["codo_i", Vector3(0.168, 0.845, -0.004)],
	"cadera_d": ["tronco", Vector3(-0.085, 0.86, 0.0)],
	"cadera_i": ["tronco", Vector3(0.085, 0.86, 0.0)],
	"rodilla_d": ["cadera_d", Vector3(-0.085, 0.475, 0.0)],
	"rodilla_i": ["cadera_i", Vector3(0.085, 0.475, 0.0)],
	"tobillo_d": ["rodilla_d", Vector3(-0.085, 0.075, 0.0)],
	"tobillo_i": ["rodilla_i", Vector3(0.085, 0.075, 0.0)],
}

## Pose de reposo: brazos ligeramente separados del cuerpo para no atravesar faldas.
const REST_POSE := {
	"hombro_d": Vector3(0, 0, -7), "hombro_i": Vector3(0, 0, 7),
	"codo_d": Vector3(-8, 0, 0), "codo_i": Vector3(-8, 0, 0),
}

var joints: Dictionary = {}
var root: Node3D
var body_material: Material
var head_material: Material
var segments := 40
var heel := 0.0
var _pose: Dictionary = {}
var _tween: Tween


func build(p_segments: int = 40, p_body: Material = null, p_head: Material = null) -> void:
	segments = p_segments
	body_material = p_body if p_body != null else default_material()
	head_material = p_head if p_head != null else body_material
	for c in get_children():
		c.queue_free()
	joints.clear()
	root = Node3D.new()
	root.name = "Raiz"
	add_child(root)
	for name in JOINT_LAYOUT:
		var parent_name: String = JOINT_LAYOUT[name][0]
		var n := Node3D.new()
		n.name = name
		var parent: Node3D = root if parent_name.is_empty() else joints[parent_name]
		n.position = JOINT_LAYOUT[name][1] - rest_position(parent_name)
		parent.add_child(n)
		joints[name] = n
	_build_body()
	apply_pose({}, 0.0)


static func rest_position(joint_name: String) -> Vector3:
	return Vector3.ZERO if joint_name.is_empty() else JOINT_LAYOUT[joint_name][1]


static func default_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.91, 0.885, 0.84)
	m.roughness = 0.62
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.5
	return m


func joint(name: String) -> Node3D:
	return joints.get(name)


## Coloca una malla en el espacio de una articulación usando coordenadas absolutas de reposo.
func attach(joint_name: String, mesh: Mesh, material: Material, local_offset: Vector3 = Vector3.ZERO,
		node_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = local_offset
	if not node_name.is_empty():
		mi.name = node_name
	joints[joint_name].add_child(mi)
	return mi


func _build_body() -> void:
	var rings := maxi(16, segments)
	var trunk := MeshKit.lathe({
		"profile": TORSO_PROFILE, "y_bottom": 0.775, "y_top": 1.47, "segments": segments, "rings": rings,
		"offset": func(th: float, y: float, _t: float) -> float: return torso_relief(th, y),
	})
	attach("tronco", trunk, body_material, -rest_position("tronco"), "Torso")
	var neck := MeshKit.lathe({"profile": NECK_PROFILE, "y_bottom": -0.02, "y_top": 0.10,
		"segments": segments, "rings": 6})
	attach("cuello", neck, body_material, Vector3.ZERO, "Cuello")
	var head := MeshKit.lathe({
		"profile": HEAD_PROFILE, "y_bottom": -0.03, "y_top": 0.2165, "segments": segments, "rings": rings,
		"offset": func(th: float, y: float, _t: float) -> float: return head_relief(th, y),
		"center": func(_y: float) -> Vector2: return Vector2(0.0, 0.006),
	})
	attach("cabeza", head, head_material, Vector3.ZERO, "Cabeza").scale = Vector3.ONE * HEAD_SCALE
	for side in ["d", "i"]:
		var s := -1.0 if side == "d" else 1.0
		attach("hombro_" + side, _limb(UPPER_ARM, 0.01, -0.29), body_material, Vector3.ZERO, "Brazo")
		# Deltoides: casquete redondeado que une el brazo con el hombro.
		attach("hombro_" + side, MeshKit.ellipsoid(Vector3(0.046, 0.048, 0.046), 16, 10), body_material,
			Vector3(-0.004 * s, -0.004, 0.0), "Hombro")
		attach("codo_" + side, _limb(FOREARM, 0.015, -0.25), body_material, Vector3.ZERO, "Antebrazo")
		attach("codo_" + side, MeshKit.ellipsoid(Vector3(0.035, 0.035, 0.035), 14, 8), body_material, Vector3.ZERO, "Articulacion")
		attach("muneca_" + side, _hand(s), body_material, Vector3.ZERO, "Mano")
		attach("muneca_" + side, MeshKit.ellipsoid(Vector3(0.024, 0.022, 0.02), 12, 6), body_material, Vector3.ZERO, "Articulacion")
		attach("cadera_" + side, _limb(THIGH, 0.04, -0.385), body_material, Vector3.ZERO, "Muslo")
		attach("rodilla_" + side, _limb(SHIN, 0.015, -0.40), body_material, Vector3.ZERO, "Pierna")
		attach("rodilla_" + side, MeshKit.ellipsoid(Vector3(0.047, 0.047, 0.05), 14, 8), body_material, Vector3.ZERO, "Articulacion")
		attach("tobillo_" + side, _foot(), body_material, Vector3.ZERO, "Pie")


func _limb(profile: Array, top: float, bottom: float) -> ArrayMesh:
	return MeshKit.lathe({"profile": profile, "y_bottom": bottom, "y_top": top,
		"segments": maxi(12, segments / 2), "rings": 12})


func _hand(side: float) -> ArrayMesh:
	# Mano estilizada de maniquí: palma y dedos juntos en una forma alargada, pulgar separado.
	var hand := MeshKit.lathe({"segments": 16, "rings": 12, "y_bottom": -0.175, "y_top": 0.0,
		"radius": func(_th: float, y: float, _t: float) -> Vector2:
			var k := clampf(-y / 0.175, 0.0, 1.0)
			var w := 0.022 + 0.016 * sin(PI * minf(1.0, k * 1.35)) - 0.012 * smoothstep(0.75, 1.0, k)
			return Vector2(w, w * 0.42),
		})
	var thumb := MeshKit.ellipsoid(Vector3(0.010, 0.030, 0.011), 10, 8)
	return MeshKit.merge([hand, thumb], [
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-6.0)), Vector3.ZERO),
		Transform3D(Basis(Vector3.BACK, deg_to_rad(-22.0 * side)), Vector3(-0.026 * side, -0.065, 0.014)),
	])


func _foot() -> ArrayMesh:
	var foot := MeshKit.ellipsoid(Vector3(0.040, 0.034, 0.118), 18, 10)
	var heel_ball := MeshKit.ellipsoid(Vector3(0.034, 0.036, 0.040), 14, 8)
	return MeshKit.merge([foot, heel_ball], [
		Transform3D(Basis.IDENTITY, Vector3(0.0, -0.041, 0.065)),
		Transform3D(Basis.IDENTITY, Vector3(0.0, -0.039, -0.005)),
	])


## Relieve del tronco: busto, glúteos y omóplatos (desplazamiento radial en metros).
static func torso_relief(th: float, y: float) -> float:
	var front := maxf(0.0, cos(th))
	var back := maxf(0.0, -cos(th))
	var bust := 0.034 * _gauss(y, 1.215, 0.05) * pow(front, 2.5) * (0.75 + 0.25 * cos(4.0 * th))
	var glutes := 0.026 * _gauss(y, 0.88, 0.055) * pow(back, 1.6)
	var pelvis_front := -0.006 * _gauss(y, 0.9, 0.05) * pow(front, 2.0)
	var blades := 0.006 * _gauss(y, 1.33, 0.05) * pow(back, 1.5)
	var belly := -0.004 * _gauss(y, 1.06, 0.04) * front
	return bust + glutes + pelvis_front + blades + belly


## Rasgos faciales estilizados de maniquí (nariz, cejas, labios, mentón, pómulos).
static func head_relief(th: float, y: float) -> float:
	var front := maxf(0.0, cos(th))
	var back := maxf(0.0, -cos(th))
	var nose := 0.017 * _gauss(th, 0.0, 0.11) * _band(y, 0.062, 0.108) * (0.4 + 0.6 * smoothstep(0.062, 0.1, y))
	var brow := 0.005 * _gauss(y, 0.125, 0.012) * _gauss(th, 0.0, 0.55)
	var sockets := -0.007 * _gauss(y, 0.108, 0.013) * (_gauss(th, 0.33, 0.14) + _gauss(th, -0.33, 0.14))
	var lips := 0.005 * _gauss(y, 0.042, 0.011) * _gauss(th, 0.0, 0.22)
	var chin := 0.007 * _gauss(y, 0.003, 0.016) * _gauss(th, 0.0, 0.3)
	var cheeks := 0.004 * _gauss(y, 0.083, 0.02) * (_gauss(th, 0.62, 0.2) + _gauss(th, -0.62, 0.2))
	var jaw := -0.022 * pow(back, 1.5) * (1.0 - smoothstep(0.02, 0.1, y))
	var temples := -0.004 * _gauss(y, 0.13, 0.03) * (_gauss(th, 1.2, 0.25) + _gauss(th, -1.2, 0.25))
	return (nose + brow + sockets + lips + chin + cheeks) * (0.3 + 0.7 * front) + jaw + temples


static func _gauss(x: float, mu: float, sigma: float) -> float:
	var d := (x - mu) / sigma
	return exp(-0.5 * d * d)


static func _band(x: float, a: float, b: float) -> float:
	return smoothstep(a - 0.01, a + 0.01, x) * (1.0 - smoothstep(b - 0.01, b + 0.01, x))


## Altura del tacón: eleva la figura y apunta el pie.
func set_heel_height(h: float) -> void:
	heel = clampf(h, 0.0, 0.14)
	root.position.y = heel
	_apply_feet()


func _apply_feet() -> void:
	var angle := rad_to_deg(atan2(heel, 0.15))
	for side in ["d", "i"]:
		var base: Vector3 = _pose.get("tobillo_" + side, Vector3.ZERO)
		joints["tobillo_" + side].rotation_degrees = base + Vector3(angle, 0, 0)


## Aplica una pose {articulación: Vector3 grados}. Las articulaciones omitidas vuelven al reposo.
func apply_pose(pose: Dictionary, duration: float = 0.6) -> void:
	_pose = REST_POSE.duplicate()
	for k in pose:
		_pose[k] = pose[k]
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0 or not is_inside_tree():
		for name in joints:
			joints[name].rotation_degrees = _pose.get(name, Vector3.ZERO)
		_apply_feet()
		return
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for name in joints:
		var target: Vector3 = _pose.get(name, Vector3.ZERO)
		if name.begins_with("tobillo_"):
			target += Vector3(rad_to_deg(atan2(heel, 0.15)), 0, 0)
		_tween.tween_property(joints[name], "rotation_degrees", target, duration)


static func pose_from_json(data: Dictionary) -> Dictionary:
	var out := {}
	for k in data.get("articulaciones", {}):
		var v: Array = data["articulaciones"][k]
		out[k] = Vector3(float(v[0]), float(v[1]), float(v[2]))
	return out
