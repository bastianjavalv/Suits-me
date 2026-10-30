class_name AccessoryBuilder
extends RefCounted
## Generadores de calzado, tocados, peinados, joyería, guantes, bolsos, cinturones, gafas y
## complementos de mano. Mismo formato de piezas que GarmentBuilder.

const HS := Mannequin.HEAD_SCALE

var segments := 40


func _init(p_segments: int = 40) -> void:
	segments = p_segments


func build(item: Dictionary) -> Array:
	var model: Dictionary = item.get("modelo", {})
	var p: Dictionary = model.get("params", {})
	match str(model.get("generador", "")):
		"calzado":
			return shoes(p)
		"tocado":
			return hat(p)
		"peinado":
			return hair(p)
		"joyeria":
			return jewelry(p)
		"guantes":
			return gloves(p)
		"bolso":
			return bag(p)
		"cinturon":
			return belt(p)
		"gafas":
			return glasses(p)
		"complemento":
			return hand_item(p)
		"maquillaje":
			return []
	push_warning("Generador desconocido: %s" % model.get("generador"))
	return []


static func _part(joint: String, mesh: Mesh, role: String, extra: Dictionary = {}) -> Dictionary:
	return GarmentBuilder._part(joint, mesh, role, extra)


## Radio de la cabeza (coordenadas de la articulación "cabeza", ya escaladas).
static func head_radius(y: float) -> Vector2:
	return MeshKit.sample_profile(Mannequin.HEAD_PROFILE, y / HS) * HS


static func _g(x: float, mu: float, s: float) -> float:
	return Mannequin._gauss(x, mu, s)


static func rounded_box(size: Vector3, sharpness: float = 6.0, segs: int = 20) -> ArrayMesh:
	var h := size.y * 0.5
	return MeshKit.lathe({"segments": segs, "rings": 10, "y_bottom": -h, "y_top": h,
		"radius": func(th: float, y: float, _t: float) -> Vector2:
			var k := pow(maxf(0.0, 1.0 - pow(absf(y) / h, sharpness)), 1.0 / sharpness)
			var c := absf(cos(th))
			var s := absf(sin(th))
			var r := pow(pow(c, sharpness) + pow(s, sharpness), -1.0 / sharpness)
			return Vector2(size.x * 0.5 * r * k, size.z * 0.5 * r * k)})


# ---------------------------------------------------------------------------
# Calzado
# ---------------------------------------------------------------------------

func shoes(p: Dictionary) -> Array:
	var kind := str(p.get("tipo", "zapato_tacon"))
	var heel := float(p.get("tacon", 0.06))
	var toe := str(p.get("punta", "almendra"))
	var shaft := float(p.get("cana", 0.0))
	var sole := float(p.get("suela", 0.008))
	var toe_len := 0.21 + (0.1 if kind == "poulaine" else 0.0) + (0.015 if toe == "afilada" else 0.0)
	var open_top := kind in ["zapato_tacon", "bailarina", "cuna", "plataforma", "mule"]
	var parts: Array = []
	for side: String in ["d", "i"]:
		var top_fn: Variant = toe_len
		if open_top:
			# Abertura del empeine: la parte superior se recorta desde el talón hasta los dedos.
			top_fn = func(th: float) -> float:
				return lerpf(toe_len, 0.07 if kind != "mule" else 0.1, pow(maxf(0.0, -cos(th)), 1.2))
		var shell := MeshKit.lathe({"segments": maxi(16, segments / 2), "rings": 18, "y_bottom": -0.065, "y_top": top_fn,
			"radius": func(_th: float, y: float, _t: float) -> Vector2:
				var u := clampf((y + 0.065) / (toe_len + 0.065), 0.0, 1.0)
				var w := 0.033 + 0.016 * sin(PI * minf(1.0, u * 1.25))
				var hgt := 0.037 + 0.011 * _g(u, 0.35, 0.2)
				var tip := 1.0 - smoothstep(0.82 if toe != "redonda" else 0.9, 1.0, u)
				if kind == "poulaine":
					tip = 1.0 - smoothstep(0.55, 1.0, u)
				if kind == "zapatilla":
					w += 0.006
					hgt += 0.006
				return Vector2(w * maxf(tip, 0.02), hgt * maxf(tip, 0.02)),
			"center": func(y: float) -> Vector2:
				var u := clampf((y + 0.065) / (toe_len + 0.065), 0.0, 1.0)
				return Vector2(0.0, 0.004 + 0.012 * u),
		})
		var rot := Vector3(90, 0, 0)
		parts.append(_part("tobillo_" + side, shell, "principal", {"posicion": Vector3(0, -0.041, 0.0), "rotacion": rot}))
		var sole_mesh := rounded_box(Vector3(0.082, sole + (0.03 if kind == "plataforma" else 0.0), toe_len + 0.07), 8.0)
		parts.append(_part("tobillo_" + side, sole_mesh, "suela",
			{"posicion": Vector3(0, -0.078 - sole * 0.5 - (0.015 if kind == "plataforma" else 0.0), (toe_len - 0.07) * 0.5)}))
		if kind == "cuna":
			var wedge := MeshKit.lathe({"segments": 12, "rings": 4, "y_bottom": -heel, "y_top": 0.0,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					return Vector2(0.03, 0.05 + 0.04 * (1.0 + y / maxf(heel, 0.01)))})
			parts.append(_part("tobillo_" + side, wedge, "suela", {"posicion": Vector3(0, -0.08, 0.0)}))
		elif heel > 0.012:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.016
			cyl.bottom_radius = 0.008 if heel > 0.06 else 0.014
			cyl.height = heel + 0.01
			cyl.radial_segments = 12
			parts.append(_part("tobillo_" + side, cyl, "suela", {"posicion": Vector3(0, -0.08 - heel * 0.5, -0.035),
				"rotacion": Vector3(-rad_to_deg(atan2(heel, 0.15)), 0, 0)}))
		if shaft > 0.0:
			var boot := MeshKit.lathe({"segments": maxi(14, segments / 2), "rings": 10, "y_bottom": -0.4, "y_top": -0.4 + shaft,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					return MeshKit.sample_profile(Mannequin.SHIN, y) + Vector2(0.012, 0.012)})
			parts.append(_part("rodilla_" + side, boot, "principal", {"contorno": 0.3, "largo": shaft}))
		if kind == "sandalia" or p.get("pulsera_tobillo", false):
			var strap := TorusMesh.new()
			strap.inner_radius = 0.034
			strap.outer_radius = 0.04
			parts.append(_part("tobillo_" + side, strap, "principal", {"posicion": Vector3(0, -0.01, 0.0)}))
	return parts


# ---------------------------------------------------------------------------
# Tocados
# ---------------------------------------------------------------------------

func hat(p: Dictionary) -> Array:
	var kind := str(p.get("tipo", "cloche"))
	var brim := float(p.get("ala", 0.0))
	var extra := float(p.get("holgura_pelo", 0.018))
	var parts: Array = []
	match kind:
		"cloche":
			var mesh := MeshKit.lathe({"segments": segments, "rings": 16,
				"y_bottom": func(th: float) -> float: return lerpf(0.118, 0.035, pow(maxf(0.0, -cos(th)), 0.7)),
				"y_top": 0.205 + extra,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					var cap := 1.0 - pow(smoothstep(0.185, 0.205 + extra, y), 2.2)
					return (head_radius(minf(y, 0.2)) + Vector2(extra, extra)) * maxf(cap, 0.02),
				"offset": func(th: float, y: float, _t: float) -> float:
					var edge := 1.0 - smoothstep(0.0, 0.03, y - lerpf(0.118, 0.035, pow(maxf(0.0, -cos(th)), 0.7)))
					return 0.004 + 0.016 * edge + 0.006 * _g(th, 0.0, 0.6),
				"center": func(_y: float) -> Vector2: return Vector2(0, 0.006)})
			parts.append(_part("cabeza", mesh, "principal", {"contorno": 0.55, "largo": 0.12}))
			parts.append(_band(0.115, 0.022, extra + 0.004, "secundario"))
		"pamela", "picture":
			var crown := MeshKit.lathe({"segments": segments, "rings": 10, "y_bottom": 0.14, "y_top": 0.27,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					var top := 1.0 - pow(smoothstep(0.24, 0.27, y), 3.0)
					return Vector2(0.088, 0.1) * maxf(top, 0.01)})
			parts.append(_part("cabeza", crown, "principal", {"rotacion": Vector3(-6, 0, 0)}))
			var r_out := 0.1 + maxf(brim, 0.12)
			var brim_mesh := MeshKit.lathe({"segments": segments, "rings": 8, "y_bottom": 0.0, "y_top": 1.0,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					var rr := lerpf(0.09, r_out, y)
					return Vector2(rr, rr * 1.08),
				"offset": func(th: float, y: float, _t: float) -> float: return 0.006 * sin(th * 5.0) * y * y})
			parts.append(_part("cabeza", brim_mesh, "principal", {"posicion": Vector3(0, 0.145, 0.0),
				"rotacion": Vector3(-8, 0, 0), "escala": Vector3(1.0, 0.03, 1.0)}))
			parts.append(_band(0.16, 0.03, 0.095 - head_radius(0.16).x, "secundario"))
			if str(p.get("adorno", "")) in ["flores", "plumas", "lazo"]:
				parts.append(_ornament(str(p["adorno"]), Vector3(0.07, 0.2, -0.04)))
		"casquete":
			var pill := MeshKit.lathe({"segments": segments, "rings": 8, "y_bottom": 0.0, "y_top": 0.065,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					return Vector2(0.075, 0.085) * (1.0 - pow(smoothstep(0.055, 0.065, y), 2.0))})
			parts.append(_part("cabeza", pill, "principal", {"posicion": Vector3(0, 0.17, -0.015), "rotacion": Vector3(-18, 0, 0)}))
		"hennin":
			var height := float(p.get("alto", 0.5))
			var cone := MeshKit.lathe({"segments": segments, "rings": 18, "y_bottom": 0.0, "y_top": height,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					var k := 1.0 - y / height
					return Vector2(0.07, 0.085) * maxf(k, 0.02)})
			parts.append(_part("cabeza", cone, "principal", {"posicion": Vector3(0, 0.15, -0.02), "rotacion": Vector3(-38, 0, 0)}))
			parts.append(_veil(0.22, -0.3, "velo"))
		"toca":
			var wimple := MeshKit.lathe({"segments": segments, "rings": 14,
				"y_bottom": -0.13,
				"y_top": func(th: float) -> float: return lerpf(0.035, 0.13, smoothstep(0.35, 0.9, absf(th))),
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					return head_radius(maxf(y, -0.03)).max(Vector2(0.062, 0.07)) + Vector2(0.012, 0.012),
				"center": func(_y: float) -> Vector2: return Vector2(0, 0.008)})
			parts.append(_part("cabeza", wimple, "principal", {"contorno": 0.5, "largo": 0.2}))
			parts.append(_veil(0.215, -0.22, "principal"))
		"turbante":
			var tur := MeshKit.lathe({"segments": segments, "rings": 14, "y_bottom": func(th: float) -> float: return lerpf(0.13, 0.07, pow(maxf(0.0, -cos(th)), 0.8)),
				"y_top": 0.245,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					return head_radius(minf(y, 0.205)) * (1.0 - pow(smoothstep(0.21, 0.245, y), 2.0)) + Vector2(0.03, 0.03) * (1.0 - smoothstep(0.205, 0.245, y)),
				"offset": func(th: float, y: float, _t: float) -> float: return 0.007 * sin(th * 6.0 + y * 40.0),
				"center": func(_y: float) -> Vector2: return Vector2(0, 0.006)})
			parts.append(_part("cabeza", tur, "principal", {"contorno": 0.6, "largo": 0.12}))
			parts.append(_part("cabeza", MeshKit.ellipsoid(Vector3(0.03, 0.026, 0.022), 12, 8), "principal", {"posicion": Vector3(0, 0.2, 0.085)}))
		"boina":
			parts.append(_part("cabeza", MeshKit.ellipsoid(Vector3(0.115, 0.03, 0.12), segments, 10), "principal",
				{"posicion": Vector3(0.025, 0.205, -0.01), "rotacion": Vector3(-6, 0, -14)}))
		"gorra":
			var cap := MeshKit.lathe({"segments": segments, "rings": 12, "y_bottom": 0.12, "y_top": 0.225,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					return head_radius(minf(y, 0.2)) * (1.0 - pow(smoothstep(0.2, 0.225, y), 2.0)) + Vector2(0.016, 0.016),
				"center": func(_y: float) -> Vector2: return Vector2(0, 0.006)})
			parts.append(_part("cabeza", cap, "principal"))
			var visor := MeshKit.lathe({"segments": 16, "rings": 4, "theta_start": -1.0, "theta_end": 1.0, "y_bottom": 0.0, "y_top": 1.0,
				"radius": func(_th: float, y: float, _t: float) -> Vector2: return Vector2.ONE * lerpf(0.085, 0.16, y)})
			parts.append(_part("cabeza", visor, "principal", {"posicion": Vector3(0, 0.125, 0.01), "escala": Vector3(1, 0.03, 1),
				"rotacion": Vector3(8, 0, 0)}))
		"diadema", "corona":
			var band := TorusMesh.new()
			band.inner_radius = 0.083
			band.outer_radius = 0.091 if kind == "diadema" else 0.093
			band.rings = segments
			parts.append(_part("cabeza", band, "metal" if kind == "corona" else "principal",
				{"posicion": Vector3(0, 0.165, 0.0), "rotacion": Vector3(-14 if kind == "diadema" else -4, 0, 0),
				"escala": Vector3(1.0, 1.0, 1.12)}))
		"panuelo":
			var scarf := MeshKit.lathe({"segments": segments, "rings": 14,
				"y_bottom": func(th: float) -> float: return lerpf(0.13, -0.01, smoothstep(0.6, 1.6, absf(th))),
				"y_top": 0.215,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					return head_radius(clampf(y, -0.02, 0.2)) * (1.0 - pow(smoothstep(0.2, 0.215, y), 2.0)) + Vector2(0.018, 0.018),
				"center": func(_y: float) -> Vector2: return Vector2(0, 0.006)})
			parts.append(_part("cabeza", scarf, "principal", {"contorno": 0.55, "largo": 0.2}))
			parts.append(_part("cabeza", MeshKit.ellipsoid(Vector3(0.025, 0.02, 0.02), 10, 6), "principal", {"posicion": Vector3(0, -0.03, 0.06)}))
	return parts


func _band(y: float, width: float, ease: float, role: String) -> Dictionary:
	var mesh := MeshKit.lathe({"segments": segments, "rings": 2, "y_bottom": y - width * 0.5, "y_top": y + width * 0.5,
		"radius": func(_th: float, yy: float, _t: float) -> Vector2: return head_radius(yy) + Vector2(ease, ease),
		"center": func(_y: float) -> Vector2: return Vector2(0, 0.006)})
	return _part("cabeza", mesh, role)


func _veil(top: float, bottom: float, role: String) -> Dictionary:
	var mesh := MeshKit.lathe({"segments": segments, "rings": 14, "theta_start": 1.25, "theta_end": TAU - 1.25,
		"y_bottom": bottom, "y_top": top,
		"radius": func(_th: float, y: float, _t: float) -> Vector2:
			if y > 0.0:
				return head_radius(minf(y, 0.2)) + Vector2(0.03, 0.03)
			return Vector2(0.1, 0.11).lerp(Vector2(0.22, 0.17), smoothstep(0.0, bottom, y)),
		"offset": func(th: float, y: float, _t: float) -> float: return 0.008 * sin(th * 9.0) * smoothstep(0.1, bottom, y)})
	return _part("cabeza", mesh, role, {"vaiven": true, "cintura_local": 0.1, "contorno": 0.8, "largo": top - bottom})


func _ornament(kind: String, pos: Vector3) -> Dictionary:
	var meshes: Array = []
	var xf: Array = []
	if kind == "plumas":
		for i in 3:
			meshes.append(MeshKit.ellipsoid(Vector3(0.012, 0.11, 0.004), 10, 8))
			xf.append(Transform3D(Basis(Vector3.BACK, -0.5 - 0.25 * i), pos + Vector3(0.02 * i, 0.03, -0.01 * i)))
	else:
		for i in 5:
			meshes.append(MeshKit.ellipsoid(Vector3(0.022, 0.018, 0.022), 10, 6))
			xf.append(Transform3D(Basis.IDENTITY, pos + Vector3(0.03 * cos(i * 1.3), 0.008 * i, 0.03 * sin(i * 1.3))))
	return _part("cabeza", MeshKit.merge(meshes, xf), "secundario")


# ---------------------------------------------------------------------------
# Peinados
# ---------------------------------------------------------------------------

func hair(p: Dictionary) -> Array:
	var style := str(p.get("estilo", "bob"))
	var vol := float(p.get("volumen", 0.5))
	var fringe := bool(p.get("flequillo", false))
	var parts: Array = []
	var thick := 0.01 + 0.02 * vol
	var back_bottom: float = {"bob": 0.0, "ondas": 0.02, "pixie": 0.05, "recogido": 0.045, "mono_bajo": 0.04,
		"melena_larga": 0.0, "liso_largo": 0.0, "coleta": 0.05, "cardado": 0.0, "victory_rolls": -0.02,
		"voluminoso": -0.04, "trenzas": 0.04, "ondas_largas": -0.03}.get(style, 0.02)
	if style in ["recogido", "mono_bajo", "coleta", "trenzas", "pixie", "ondas"]:
		thick = 0.007 + 0.006 * vol
	if style == "voluminoso":
		thick = 0.025 + 0.05 * vol
	var shell := MeshKit.lathe({"segments": segments, "rings": 18,
		"y_bottom": func(th: float) -> float:
			var face := 1.0 - smoothstep(0.55, 1.05, absf(th))
			var hairline := 0.13 if fringe else 0.158
			return lerpf(back_bottom, hairline, face),
		"y_top": 0.2165 * HS + thick,
		"radius": func(_th: float, y: float, _t: float) -> Vector2:
			var base := head_radius(clampf(y, 0.0, 0.2))
			var cap := 1.0 - pow(smoothstep(0.19, 0.2165 * HS + thick, y), 2.2)
			var lift := 1.0 + (0.6 * vol * smoothstep(0.08, 0.19, y) if style == "cardado" else 0.0)
			return (base + Vector2(thick, thick) * lift) * maxf(cap, 0.03),
		"offset": func(th: float, y: float, _t: float) -> float:
			var o := 0.0
			if style == "ondas" or style == "ondas_largas":
				o += 0.004 * sin(y * 95.0 + th * 2.0)
			elif style == "voluminoso":
				o += 0.012 * vol * sin(th * 11.0 + y * 37.0) * sin(y * 23.0)
			elif style == "bob":
				o += 0.006 * smoothstep(0.06, 0.0, y)
			return o,
		"center": func(_y: float) -> Vector2: return Vector2(0, 0.004)})
	parts.append(_part("cabeza", shell, "cabello", {"contorno": 0.6, "largo": 0.25}))
	match style:
		"recogido":
			parts.append(_part("cabeza", MeshKit.ellipsoid(Vector3(0.085, 0.045, 0.092), segments, 10), "cabello",
				{"posicion": Vector3(0, 0.185, 0.005)}))
			parts.append(_part("cabeza", MeshKit.ellipsoid(Vector3(0.042, 0.034, 0.042), 16, 10), "cabello",
				{"posicion": Vector3(0, 0.235, -0.025)}))
		"mono_bajo":
			parts.append(_part("cabeza", MeshKit.ellipsoid(Vector3(0.05, 0.035, 0.038), 16, 10), "cabello",
				{"posicion": Vector3(0, 0.035, -0.09)}))
		"cardado":
			parts.append(_part("cabeza", MeshKit.ellipsoid(Vector3(0.078, 0.07 + 0.06 * vol, 0.085), segments, 12), "cabello",
				{"posicion": Vector3(0, 0.2, -0.012)}))
		"victory_rolls":
			for s: float in [-1.0, 1.0]:
				var roll := TorusMesh.new()
				roll.inner_radius = 0.012
				roll.outer_radius = 0.038
				parts.append(_part("cabeza", roll, "cabello", {"posicion": Vector3(0.045 * s, 0.195, 0.035),
					"rotacion": Vector3(0, 90, 70 * s)}))
		"coleta":
			var tail := GarmentBuilder.tube_path([Vector3(0, 0.17, -0.085), Vector3(0, 0.12, -0.12), Vector3(0, 0.0, -0.13),
				Vector3(0, -0.12, -0.115)], 0.025, 10)
			parts.append(_part("cabeza", tail, "cabello"))
		"trenzas":
			for s: float in [-1.0, 1.0]:
				var meshes: Array = []
				var xf: Array = []
				for i in 14:
					meshes.append(MeshKit.ellipsoid(Vector3(0.016, 0.022, 0.014), 10, 6))
					var y := 0.07 - i * 0.026
					xf.append(Transform3D(Basis(Vector3.BACK, 0.35 * (1 if i % 2 == 0 else -1)),
						Vector3(0.078 * s + 0.004 * i * s, y, 0.02 + 0.004 * i)))
				parts.append(_part("cabeza", MeshKit.merge(meshes, xf), "cabello"))
		"melena_larga", "liso_largo", "ondas_largas", "voluminoso":
			var bottom: float = {"melena_larga": -0.3, "liso_largo": -0.34, "ondas_largas": -0.12, "voluminoso": -0.16}[style]
			var fall := MeshKit.lathe({"segments": segments, "rings": 16, "theta_start": 1.15, "theta_end": TAU - 1.15,
				"y_bottom": bottom, "y_top": 0.14,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					if y > 0.02:
						return head_radius(y) + Vector2(thick, thick)
					var k := smoothstep(0.02, bottom, y)
					var r := Vector2(0.08, 0.085).lerp(Vector2(0.17, 0.13), k)
					return r + Vector2(thick, thick) * (1.0 + (1.5 * vol if style == "voluminoso" else 0.0)),
				"offset": func(th: float, y: float, _t: float) -> float:
					return 0.004 * sin(y * 70.0 + th * 3.0) if style != "liso_largo" else 0.0015 * sin(th * 23.0)})
			parts.append(_part("cabeza", fall, "cabello", {"vaiven": true, "cintura_local": 0.05}))
	return parts


# ---------------------------------------------------------------------------
# Joyería, guantes, bolsos, cinturones, gafas y complementos de mano
# ---------------------------------------------------------------------------

func jewelry(p: Dictionary) -> Array:
	var kind := str(p.get("tipo", "collar_perlas"))
	var parts: Array = []
	match kind:
		"collar_perlas", "sautoir":
			var loops := int(p.get("vueltas", 1))
			var drop := float(p.get("caida", 0.06 if kind == "collar_perlas" else 0.36))
			var bead := float(p.get("tamano", 0.0055))
			for loop in loops:
				var d := drop + loop * 0.05
				var count := int(40 + d * 260)
				var meshes: Array = []
				var xf: Array = []
				# Perlas de pocos polígonos: a 5 mm de diámetro la diferencia no se aprecia.
				var sphere := MeshKit.ellipsoid(Vector3(bead, bead, bead), 6, 4)
				for i in count:
					var th := -PI + TAU * i / count
					var y := 1.452 - d * pow(0.5 + 0.5 * cos(th), 1.6)
					# Los collares cuelgan por encima de la ropa: más holgura cuanto más bajan.
					var ease := 0.014 + 0.03 * smoothstep(1.44, 1.34, y)
					var r := GarmentBuilder.body_radius(y) + Vector2(ease, ease)
					var rel := Mannequin.torso_relief(th, y)
					meshes.append(sphere)
					xf.append(Transform3D(Basis.IDENTITY, Vector3((r.x + rel) * sin(th), y, (r.y + rel) * cos(th) + 0.004)))
				parts.append(_part("tronco", MeshKit.merge(meshes, xf), "perla", GarmentBuilder._trunk_extra({})))
		"gargantilla":
			var choker := TorusMesh.new()
			choker.inner_radius = 0.049
			choker.outer_radius = 0.06
			choker.rings = segments
			parts.append(_part("cuello", choker, "principal" if p.get("tela", false) else "metal",
				{"posicion": Vector3(0, 0.03, 0.002), "escala": Vector3(1, 1.8, 1.02)}))
		"cadena":
			var pts: Array = []
			for i in 33:
				var th := -PI + TAU * i / 32.0
				var y := 1.45 - 0.07 * pow(0.5 + 0.5 * cos(th), 1.5)
				var r := GarmentBuilder.body_radius(y) + Vector2(0.012, 0.012)
				pts.append(Vector3(r.x * sin(th), y, r.y * cos(th) + Mannequin.torso_relief(th, y)))
			parts.append(_part("tronco", GarmentBuilder.tube_path(pts, 0.0035, 6), "metal", GarmentBuilder._trunk_extra({})))
		"pendientes", "aros":
			for s: float in [-1.0, 1.0]:
				if kind == "aros":
					var hoop := TorusMesh.new()
					hoop.inner_radius = 0.022
					hoop.outer_radius = 0.026
					parts.append(_part("cabeza", hoop, "metal", {"posicion": Vector3(0.072 * s, 0.045, -0.002), "rotacion": Vector3(0, 0, 90)}))
				else:
					var drop := MeshKit.merge([MeshKit.ellipsoid(Vector3(0.006, 0.006, 0.006), 8, 6),
						MeshKit.ellipsoid(Vector3(0.008, 0.012, 0.008), 10, 8)],
						[Transform3D(Basis.IDENTITY, Vector3.ZERO), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0))])
					parts.append(_part("cabeza", drop, str(p.get("material", "perla")), {"posicion": Vector3(0.072 * s, 0.07, -0.002)}))
		"broche":
			parts.append(_part("tronco", MeshKit.ellipsoid(Vector3(0.018, 0.022, 0.006), 12, 8), "metal",
				GarmentBuilder._trunk_extra({"posicion": Vector3(0.07, 1.36 - 0.95, 0.135)})))
		"pulseras":
			for s: String in ["d", "i"]:
				var bangle := TorusMesh.new()
				bangle.inner_radius = 0.026
				bangle.outer_radius = 0.032
				parts.append(_part("muneca_" + s, bangle, "metal", {"posicion": Vector3(0, 0.01, 0)}))
	return parts


func gloves(p: Dictionary) -> Array:
	var length := str(p.get("largo", "muneca"))
	var top: float = {"muneca": -0.2, "codo": 0.02, "opera": 0.02}.get(length, -0.2)
	var parts: Array = []
	for side: String in ["d", "i"]:
		var fore := MeshKit.lathe({"segments": maxi(12, segments / 2), "rings": 10, "y_bottom": -0.255, "y_top": top,
			"radius": func(_th: float, y: float, _t: float) -> Vector2:
				return MeshKit.sample_profile(Mannequin.FOREARM, y) + Vector2(0.004, 0.004)})
		parts.append(_part("codo_" + side, fore, "principal"))
		var hand := MeshKit.lathe({"segments": 16, "rings": 12, "y_bottom": -0.178, "y_top": 0.005,
			"radius": func(_th: float, y: float, _t: float) -> Vector2:
				var k := clampf(-y / 0.175, 0.0, 1.0)
				var w := 0.025 + 0.016 * sin(PI * minf(1.0, k * 1.35)) - 0.012 * smoothstep(0.75, 1.0, k)
				return Vector2(w, w * 0.45 + 0.003)})
		parts.append(_part("muneca_" + side, hand, "principal", {"rotacion": Vector3(-6, 0, 0)}))
		if length == "opera":
			var upper := MeshKit.lathe({"segments": maxi(12, segments / 2), "rings": 8, "y_bottom": -0.29, "y_top": -0.14,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					return MeshKit.sample_profile(Mannequin.UPPER_ARM, y) + Vector2(0.005, 0.005)})
			parts.append(_part("hombro_" + side, upper, "principal"))
	return parts


func bag(p: Dictionary) -> Array:
	var kind := str(p.get("tipo", "bolso_mano"))
	var parts: Array = []
	match kind:
		"clutch":
			parts.append(_part("muneca_d", rounded_box(Vector3(0.24, 0.12, 0.035)), "principal",
				{"posicion": Vector3(0.0, -0.09, 0.04), "rotacion": Vector3(0, 90, 70)}))
		"bolso_mano", "caja":
			var size := Vector3(0.24, 0.17, 0.09) if kind == "bolso_mano" else Vector3(0.2, 0.14, 0.1)
			var body := rounded_box(size, 7.0 if kind == "bolso_mano" else 14.0)
			parts.append(_part("codo_d", body, "principal", {"posicion": Vector3(-0.07, -0.17, 0.02), "rotacion": Vector3(0, 90, 0)}))
			var handle_pts: Array = []
			for i in 13:
				var a := PI * i / 12.0
				handle_pts.append(Vector3(-0.07, -0.085 + 0.08 * sin(a), 0.02 + 0.09 * cos(a)))
			parts.append(_part("codo_d", GarmentBuilder.tube_path(handle_pts, 0.006, 6), "principal"))
		"baguette":
			parts.append(_part("hombro_d", rounded_box(Vector3(0.26, 0.11, 0.05)), "principal",
				{"posicion": Vector3(0.03, -0.2, 0.0), "rotacion": Vector3(0, 90, -8)}))
		"bandolera", "limosnera":
			var pouch := MeshKit.ellipsoid(Vector3(0.07, 0.085, 0.03), 16, 10) if kind == "limosnera" else rounded_box(Vector3(0.2, 0.15, 0.06))
			var pos := Vector3(-0.19, 0.9, 0.05) if kind == "bandolera" else Vector3(-0.12, 0.83, 0.11)
			parts.append(_part("tronco", pouch, "principal", GarmentBuilder._trunk_extra({"posicion": pos - Mannequin.rest_position("tronco")})))
			if kind == "bandolera":
				var pts: Array = []
				for i in 11:
					var t := i / 10.0
					var y := lerpf(1.45, 0.98, t)
					var x := lerpf(0.1, -0.17, t)
					var r := GarmentBuilder.body_radius(y)
					var th := asin(clampf(x / (r.x + 0.03), -1.0, 1.0))
					pts.append(Vector3(x, y, (r.y + 0.03) * cos(th) + Mannequin.torso_relief(th, y)))
				parts.append(_part("tronco", GarmentBuilder.tube_path(pts, 0.006, 6), "principal", GarmentBuilder._trunk_extra({})))
		"mochila":
			parts.append(_part("tronco", rounded_box(Vector3(0.24, 0.27, 0.11), 5.0), "principal",
				GarmentBuilder._trunk_extra({"posicion": Vector3(0, 1.16, -0.16) - Mannequin.rest_position("tronco")})))
		"malla":
			parts.append(_part("muneca_d", MeshKit.ellipsoid(Vector3(0.06, 0.08, 0.02), 14, 10), "principal",
				{"posicion": Vector3(0.0, -0.2, 0.03)}))
	return parts


func belt(p: Dictionary) -> Array:
	var y := float(p.get("altura", 1.04))
	var width := float(p.get("ancho", 0.03))
	var ease := float(p.get("holgura", 0.03))
	var parts: Array = [GarmentBuilder.new({"segmentos_radiales": segments})._belt_band(y, ease, width, "principal")]
	if p.get("hebilla", true):
		var r := GarmentBuilder.body_radius(y)
		parts.append(_part("tronco", rounded_box(Vector3(0.045, width + 0.012, 0.008), 10.0), "metal",
			GarmentBuilder._trunk_extra({"posicion": Vector3(0, y, r.y + ease + Mannequin.torso_relief(0.0, y) + 0.004) - Mannequin.rest_position("tronco")})))
	if str(p.get("tipo", "")) == "cenidor":
		var pts := [Vector3(0.0, y, 0.12), Vector3(0.01, y - 0.15, 0.135), Vector3(0.0, y - 0.35, 0.14), Vector3(0.0, y - 0.48, 0.15)]
		parts.append(_part("tronco", GarmentBuilder.tube_path(pts, 0.008, 6), "principal", GarmentBuilder._trunk_extra({})))
	return parts


func glasses(p: Dictionary) -> Array:
	var kind := str(p.get("tipo", "redondas"))
	var r: float = {"redondas": 0.022, "ojo_de_gato": 0.024, "ovaladas": 0.018, "grandes": 0.03, "aviador": 0.026}.get(kind, 0.022)
	var squash: Vector2 = {"redondas": Vector2(1, 1), "ojo_de_gato": Vector2(1.25, 0.8), "ovaladas": Vector2(1.3, 0.62),
		"grandes": Vector2(1.1, 1.0), "aviador": Vector2(1.05, 0.95)}.get(kind, Vector2.ONE)
	var parts: Array = []
	var z := 0.098
	var y := 0.1
	for s: float in [-1.0, 1.0]:
		var rim := TorusMesh.new()
		rim.inner_radius = r
		rim.outer_radius = r + 0.0035
		rim.rings = 24
		var tilt := 12.0 * s if kind == "ojo_de_gato" else 0.0
		parts.append(_part("cabeza", rim, "principal", {"posicion": Vector3(0.032 * s, y, z), "rotacion": Vector3(90, 0, tilt),
			"escala": Vector3(squash.x, 1, squash.y)}))
		var lens := CylinderMesh.new()
		lens.top_radius = r
		lens.bottom_radius = r
		lens.height = 0.002
		lens.radial_segments = 20
		parts.append(_part("cabeza", lens, "lente", {"posicion": Vector3(0.032 * s, y, z), "rotacion": Vector3(90, 0, tilt),
			"escala": Vector3(squash.x, 1, squash.y)}))
		var arm := GarmentBuilder.tube_path([Vector3((0.032 + r * squash.x) * s, y, z), Vector3(0.071 * s, y + 0.004, 0.02),
			Vector3(0.068 * s, y - 0.01, -0.03)], 0.0022, 5)
		parts.append(_part("cabeza", arm, "principal"))
	parts.append(_part("cabeza", GarmentBuilder.tube_path([Vector3(-0.012, y + 0.006, z + 0.004), Vector3(0, y + 0.01, z + 0.006),
		Vector3(0.012, y + 0.006, z + 0.004)], 0.0022, 5), "principal"))
	return parts


func hand_item(p: Dictionary) -> Array:
	var kind := str(p.get("tipo", "abanico"))
	var parts: Array = []
	match kind:
		"abanico":
			var fan := MeshKit.lathe({"segments": 32, "rings": 6, "theta_start": -1.1, "theta_end": 1.1, "y_bottom": 0.0, "y_top": 1.0,
				"radius": func(_th: float, y: float, _t: float) -> Vector2: return Vector2.ONE * lerpf(0.03, 0.2, y)})
			parts.append(_part("muneca_i", fan, "principal", {"posicion": Vector3(0.0, -0.11, 0.05), "escala": Vector3(1, 0.02, 1),
				"rotacion": Vector3(70, 0, 0)}))
		"sombrilla":
			var canopy := MeshKit.lathe({"segments": 32, "rings": 8, "y_bottom": 0.0, "y_top": 0.16,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					var k := 1.0 - y / 0.16
					return Vector2.ONE * 0.4 * sqrt(maxf(k, 0.0)),
				"offset": func(th: float, y: float, _t: float) -> float: return 0.012 * absf(sin(th * 4.0)) * (1.0 - y / 0.16)})
			var stick := CylinderMesh.new()
			stick.top_radius = 0.006
			stick.bottom_radius = 0.006
			stick.height = 0.85
			parts.append(_part("muneca_d", canopy, "principal", {"posicion": Vector3(0.05, 0.62, -0.25), "rotacion": Vector3(-30, 0, 20)}))
			parts.append(_part("muneca_d", stick, "metal", {"posicion": Vector3(0.02, 0.3, -0.12), "rotacion": Vector3(-30, 0, 20)}))
		"ramo":
			var meshes: Array = []
			var xf: Array = []
			for i in 9:
				meshes.append(MeshKit.ellipsoid(Vector3(0.028, 0.024, 0.028), 10, 6))
				xf.append(Transform3D(Basis.IDENTITY, Vector3(0.045 * cos(i * 2.4), 0.02 * (i % 3), 0.045 * sin(i * 2.4))))
			parts.append(_part("muneca_d", MeshKit.merge(meshes, xf), "principal", {"posicion": Vector3(0.02, -0.06, 0.12)}))
	return parts
