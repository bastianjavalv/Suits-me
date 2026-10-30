class_name GarmentBuilder
extends RefCounted
## Genera las piezas 3D de las prendas a partir de su campo "modelo": {"generador", "params"}.
## Cada pieza es un diccionario {articulacion, malla, rol, posicion, rotacion, escala, vaiven,
## contorno, largo, cintura_local}. Las piezas del tronco se generan en coordenadas absolutas de
## reposo y se desplazan con `posicion`; las de brazos y piernas, en coordenadas de la articulación.

const WAIST := {"natural": 1.04, "alta": 1.09, "imperio": 1.17, "baja": 0.92, "cadera": 0.88}
const HEM := {"suelo": 0.015, "tobillo": 0.09, "media_pierna": 0.27, "bajo_rodilla": 0.37, "rodilla": 0.45,
	"sobre_rodilla": 0.53, "mini": 0.62, "micro": 0.70}
const TOP_BOTTOM := {"cintura": 1.03, "cadera": 0.88, "corto": 1.13, "muslo": 0.72}
const COAT_BOTTOM := {"cintura": 1.0, "cadera": 0.86, "muslo": 0.66, "rodilla": 0.46, "media_pierna": 0.28,
	"tobillo": 0.09, "suelo": 0.02}
const NECK_DEPTH := {"redondo": 0.05, "v": 0.15, "cuadrado": 0.11, "barco": 0.03, "alto": 0.0,
	"palabra_de_honor": 0.0, "tirantes": 0.0, "corazon": 0.0, "halter": 0.0, "solapa": 0.17, "espalda_baja": 0.05}
const SHOULDER_Y := 1.455

var segments := 40
var rings_per_m := 36.0
## Altura del tacón del calzado puesto: los bajos «hasta el suelo» la compensan.
var heel := 0.0


func _init(quality: Dictionary = {}) -> void:
	segments = int(quality.get("segmentos_radiales", 40))
	rings_per_m = float(quality.get("anillos_por_metro", 36.0))


func _rings(height: float) -> int:
	return clampi(ceili(absf(height) * rings_per_m), 6, 90)


static func _g(x: float, mu: float, sigma: float) -> float:
	return Mannequin._gauss(x, mu, sigma)


static func _part(joint: String, mesh: Mesh, role: String, extra: Dictionary = {}) -> Dictionary:
	var d := {"articulacion": joint, "malla": mesh, "rol": role, "posicion": Vector3.ZERO,
		"rotacion": Vector3.ZERO, "escala": Vector3.ONE, "vaiven": false, "contorno": 0.9, "largo": 0.5,
		"cintura_local": 0.0}
	d.merge(extra, true)
	return d


static func _trunk_extra(extra: Dictionary) -> Dictionary:
	extra["posicion"] = -Mannequin.rest_position("tronco")
	return extra


static func body_radius(y: float) -> Vector2:
	return MeshKit.sample_profile(Mannequin.TORSO_PROFILE, y)


static func circumference(r: Vector2) -> float:
	return TAU * sqrt((r.x * r.x + r.y * r.y) * 0.5)


## Espacio que ocupan las piernas a la altura y (para que faldas largas no las atraviesen).
static func leg_clearance(y: float) -> Vector2:
	if y > 0.86:
		return Vector2.ZERO
	var r: Vector2
	if y > 0.475:
		r = MeshKit.sample_profile(Mannequin.THIGH, y - 0.86)
	else:
		r = MeshKit.sample_profile(Mannequin.SHIN, y - 0.475)
	return Vector2(0.085 + r.x + 0.012, r.y + 0.018)


static func neckline_y(kind: String, depth: float, th: float) -> float:
	var a := absf(th)
	match kind:
		"v", "solapa":
			return SHOULDER_Y - depth * maxf(0.0, 1.0 - a / 0.62)
		"cuadrado":
			return SHOULDER_Y - depth * (1.0 - smoothstep(0.42, 0.58, a))
		"barco":
			return SHOULDER_Y - 0.012 - depth * _g(th, 0.0, 0.9)
		"alto":
			return 1.52
		"palabra_de_honor", "tirantes":
			return 1.30 + 0.012 * cos(2.0 * th)
		"corazon":
			return 1.30 - 0.03 * _g(th, 0.0, 0.1) + 0.012 * (_g(a, 0.28, 0.12))
		"halter":
			return lerpf(1.25, 1.45, 1.0 - smoothstep(0.35, 0.8, a))
		"espalda_baja":
			return SHOULDER_Y - depth * _g(th, 0.0, 0.5) - 0.32 * _g(a, PI, 0.55)
	return SHOULDER_Y - depth * _g(th, 0.0, 0.5)


# ---------------------------------------------------------------------------
# Generadores
# ---------------------------------------------------------------------------

func build(item: Dictionary) -> Array:
	var model: Dictionary = item.get("modelo", {})
	var p: Dictionary = model.get("params", {})
	match str(model.get("generador", "")):
		"vestido":
			return dress(p)
		"parte_superior":
			return top(p)
		"falda":
			return [skirt(p, 1)]
		"pantalon":
			return trousers(p)
		"abrigo":
			return coat(p)
		"capa":
			return [cape(p)]
	return AccessoryBuilder.new(segments).build(item)


func dress(p: Dictionary) -> Array:
	var parts: Array = []
	var waist: float = WAIST.get(str(p.get("cintura", "natural")), 1.04)
	var bodice_p: Dictionary = p.get("corpino", {})
	var skirt_p: Dictionary = p.get("falda", {}).duplicate()
	skirt_p["cintura_y"] = waist
	parts.append(bodice(bodice_p, 0, waist - 0.02))
	parts.append(skirt(skirt_p, 0))
	parts.append_array(sleeves(p.get("mangas", {}), 0))
	if str(bodice_p.get("escote", "")) == "tirantes":
		parts.append_array(straps(0.004))
	return parts


func top(p: Dictionary) -> Array:
	var bottom: float = TOP_BOTTOM.get(str(p.get("largo", "cintura")), 1.03)
	var parts: Array = [bodice(p, 0, bottom)]
	parts.append_array(sleeves(p.get("mangas", {}), 0))
	if str(p.get("escote", "")) == "tirantes":
		parts.append_array(straps(0.004))
	if str(p.get("cuello", "")) == "lazo":
		parts.append(_bow(Vector3(0.0, 1.43, 0.115), 0.05, "secundario"))
	return parts


func bodice(p: Dictionary, layer: int, bottom_y: float) -> Dictionary:
	var ease := 0.005 + 0.012 * layer + float(p.get("holgura", 0.0))
	var neck := str(p.get("escote", "redondo"))
	var depth := float(p.get("profundidad_escote", NECK_DEPTH.get(neck, 0.05)))
	var straight := str(p.get("silueta", "")) == "recta"
	var pouch := float(p.get("blusado", 0.0))
	var peplum := float(p.get("peplum", 0.0))
	var point := float(p.get("pico", 0.0))
	var waist := 1.04
	var top_fn := func(th: float) -> float: return neckline_y(neck, depth, th)
	var bottom_fn := func(th: float) -> float: return bottom_y - point * _g(th, 0.0, 0.32)
	var radius_fn := func(_th: float, y: float, _t: float) -> Vector2:
		var r := body_radius(y)
		if straight and y < 1.3:
			r = Vector2(maxf(r.x, 0.162), maxf(r.y, 0.108))
		var legs := leg_clearance(y)
		return Vector2(maxf(r.x, legs.x), maxf(r.y, legs.y))
	var offset_fn := func(th: float, y: float, _t: float) -> float:
		var relief := Mannequin.torso_relief(th, y)
		var o := ease + (relief * 0.4 if straight else relief)
		o += pouch * _g(y, bottom_y + 0.13, 0.06) * pow(maxf(0.0, cos(th)), 1.5)
		if peplum > 0.0 and y < waist:
			o += peplum * smoothstep(0.0, 0.12, waist - y)
		return o
	var top := 1.52 if neck == "alto" else SHOULDER_Y
	var mesh := MeshKit.lathe({"segments": segments, "rings": _rings(top - bottom_y), "y_bottom": bottom_fn,
		"y_top": top_fn, "radius": radius_fn, "offset": offset_fn})
	return _part("tronco", mesh, "principal", _trunk_extra({"contorno": circumference(body_radius(1.1)),
		"largo": top - bottom_y}))


func skirt(p: Dictionary, layer: int) -> Dictionary:
	var waist: float = float(p.get("cintura_y", WAIST.get(str(p.get("cintura", "natural")), 1.04)))
	var hem: float = HEM.get(str(p.get("largo", "rodilla")), 0.45)
	if str(p.get("largo", "")) == "suelo":
		hem -= heel
	var shape := str(p.get("forma", "a"))
	var default_flare := {"recta": 0.0, "lapiz": 0.0, "a": 0.12, "campana": 0.2, "circular": 0.32, "globo": 0.14,
		"bies": 0.09, "sirena": 0.16, "trapecio": 0.16}
	var flare := float(p.get("vuelo", default_flare.get(shape, 0.12)))
	var folds := int(p.get("pliegues", 10))
	var fold_depth := float(p.get("profundidad_pliegues", 0.012))
	var pleat := str(p.get("tipo_pliegue", "suave"))
	var train := float(p.get("cola", 0.0))
	var hem_style := str(p.get("bajo", "recto"))
	var ease := 0.008 + 0.014 * layer + float(p.get("holgura", 0.0))
	var span := maxf(waist - hem, 0.05)
	var hip := body_radius(0.9) + Vector2(ease + 0.01, ease + 0.018)
	var waist_r := body_radius(waist) + Vector2(ease, ease)
	var bottom_fn := func(th: float) -> float:
		var b := hem - train * pow(maxf(0.0, -cos(th)), 2.0)
		if hem_style == "picos":
			b -= 0.07 * pow(absf(sin(2.0 * th)), 3.0)
		elif hem_style == "asimetrico":
			b -= 0.12 * (0.5 + 0.5 * sin(th))
		elif hem_style == "alto_bajo":
			b -= 0.16 * pow(maxf(0.0, -cos(th)), 1.5)
		return maxf(b, 0.012 - heel)
	var radius_fn := func(_th: float, y: float, _t: float) -> Vector2:
		var s := clampf((waist - y) / span, 0.0, 1.0)
		var base: Vector2
		match shape:
			"recta":
				base = hip if y < 0.92 else waist_r.lerp(hip, smoothstep(waist, 0.92, y))
			"lapiz":
				base = hip.lerp(hip * Vector2(0.86, 0.9), smoothstep(0.8, hem, y)) if y < 0.9 else waist_r.lerp(hip, smoothstep(waist, 0.9, y))
			"campana":
				base = waist_r + Vector2.ONE * flare * (1.0 - pow(1.0 - s, 2.2))
			"circular":
				base = waist_r + Vector2(1.0, 0.92) * flare * (1.0 - pow(1.0 - s, 3.0))
			"globo":
				base = waist_r + Vector2.ONE * flare * sin(PI * minf(1.0, s * 1.1)) + Vector2.ONE * 0.03 * s
			"bies":
				base = hip.lerp(hip + Vector2.ONE * flare, smoothstep(0.35, 1.0, s)) if y < 0.9 else waist_r.lerp(hip, smoothstep(waist, 0.9, y))
			"sirena":
				base = hip.lerp(hip + Vector2.ONE * flare, smoothstep(0.65, 1.0, s)) if y < 0.9 else waist_r.lerp(hip, smoothstep(waist, 0.9, y))
			"trapecio":
				base = waist_r.lerp(hip + Vector2.ONE * flare, s)
			_:
				base = waist_r.lerp(hip + Vector2.ONE * flare, s)
		var body := body_radius(y) + Vector2(ease, ease) if y > 0.8 else Vector2.ZERO
		var legs := leg_clearance(y)
		return Vector2(maxf(base.x, maxf(body.x, legs.x)), maxf(base.y, maxf(body.y, legs.y)))
	var offset_fn := func(th: float, y: float, _t: float) -> float:
		var s := clampf((waist - y) / span, 0.0, 1.0)
		var o := Mannequin.torso_relief(th, y) * (1.0 - smoothstep(0.0, 0.35, s))
		var phase := th * folds
		match pleat:
			"tabla":
				o += fold_depth * pow(s, 0.6) * (absf(fposmod(phase / TAU, 1.0) - 0.5) * 4.0 - 1.0)
			"acordeon":
				o += fold_depth * 0.6 * (absf(fposmod(phase * 3.0 / TAU, 1.0) - 0.5) * 4.0 - 1.0)
			_:
				o += fold_depth * pow(s, 1.4) * sin(phase + 0.6 * sin(th * 3.0))
		o += train * pow(maxf(0.0, -cos(th)), 2.0) * s * s * 0.6
		return o
	var mesh := MeshKit.lathe({"segments": segments, "rings": _rings(span + train), "y_bottom": bottom_fn,
		"y_top": waist, "radius": radius_fn, "offset": offset_fn})
	return _part("tronco", mesh, "principal", _trunk_extra({"vaiven": true, "cintura_local": waist,
		"contorno": circumference(hip), "largo": span}))


func sleeves(p: Dictionary, layer: int) -> Array:
	var kind := str(p.get("tipo", "ninguna"))
	if kind == "ninguna" or p.is_empty():
		return []
	var vol := float(p.get("volumen", 0.5))
	var ease := 0.006 + 0.01 * layer + float(p.get("holgura", 0.0))
	var pads := float(p.get("hombreras", 0.0))
	var upper_len: float = {"casquillo": 0.07, "corta": 0.15, "abullonada": 0.14}.get(kind, 0.29)
	var fore_len: float = {"tres_cuartos": 0.14, "larga": 0.255, "jamon": 0.255, "campana": 0.255,
		"colgante": 0.25 + 0.45 * vol, "abullonada_larga": 0.255}.get(kind, 0.0)
	var parts: Array = []
	for side: String in ["d", "i"]:
		var s := -1.0 if side == "d" else 1.0
		var upper := MeshKit.lathe({"segments": maxi(12, segments / 2), "rings": _rings(upper_len + 0.05),
			"y_bottom": -upper_len, "y_top": 0.05,
			"radius": func(_th: float, y: float, _t: float) -> Vector2:
				var r := MeshKit.sample_profile(Mannequin.UPPER_ARM, minf(y, 0.0))
				if y > 0.0:
					r = Vector2(0.052, 0.052)
				var u := clampf(-y / upper_len, 0.0, 1.0)
				var extra := ease
				if kind == "abullonada" or kind == "abullonada_larga":
					extra += vol * 0.055 * sin(PI * clampf(-y / 0.14, 0.0, 1.0))
				elif kind == "jamon":
					extra += vol * 0.11 * pow(1.0 - u, 1.4)
				return r + Vector2(extra, extra),
			"offset": func(th: float, y: float, _t: float) -> float:
				return 0.004 * sin(th * 7.0) * clampf(-y / 0.1, 0.0, 1.0) if kind in ["abullonada", "jamon"] else 0.0,
		})
		parts.append(_part("hombro_" + side, upper, "principal", {"contorno": 0.3, "largo": upper_len}))
		if pads > 0.0:
			var pad := MeshKit.ellipsoid(Vector3(0.06 + 0.035 * pads, 0.022 + 0.015 * pads, 0.058), 16, 8)
			parts.append(_part("hombro_" + side, pad, "principal", {"posicion": Vector3(0.012 * s, 0.045, 0.0)}))
		if fore_len > 0.0:
			var fore := MeshKit.lathe({"segments": maxi(12, segments / 2), "rings": _rings(fore_len + 0.03),
				"y_bottom": -fore_len, "y_top": 0.03,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					var r := MeshKit.sample_profile(Mannequin.FOREARM, maxf(y, -0.25))
					var u := clampf(-y / fore_len, 0.0, 1.0)
					var extra := ease
					if kind == "campana":
						extra += vol * 0.09 * u * u
					elif kind == "colgante":
						extra += 0.025 + vol * 0.17 * pow(u, 1.3)
					elif kind == "abullonada_larga":
						extra += vol * 0.03 * sin(PI * u)
					return r + Vector2(extra, extra),
				"offset": func(th: float, y: float, _t: float) -> float:
					var u := clampf(-y / fore_len, 0.0, 1.0)
					return 0.012 * u * sin(th * 7.0) if kind in ["colgante", "campana"] else 0.0,
			})
			parts.append(_part("codo_" + side, fore, "principal", {"contorno": 0.22, "largo": fore_len,
				"vaiven": kind == "colgante", "cintura_local": 0.0}))
	return parts


func straps(width: float) -> Array:
	var parts: Array = []
	for s: float in [-1.0, 1.0]:
		var pts := [Vector3(0.085 * s, 1.30, 0.118), Vector3(0.098 * s, 1.40, 0.075), Vector3(0.105 * s, 1.462, 0.0),
			Vector3(0.098 * s, 1.40, -0.07), Vector3(0.088 * s, 1.30, -0.1)]
		parts.append(_part("tronco", tube_path(pts, width, 6), "principal", _trunk_extra({})))
	return parts


func trousers(p: Dictionary) -> Array:
	var waist: float = WAIST.get(str(p.get("cintura", "natural")), 1.04)
	var cut := str(p.get("corte", "recto"))
	var length := str(p.get("largo", "tobillo"))
	var ease := 0.006 + float(p.get("holgura", 0.0))
	var parts: Array = []
	var pelvis := MeshKit.lathe({"segments": segments, "rings": _rings(waist - 0.79), "y_bottom": 0.785, "y_top": waist,
		"profile": Mannequin.TORSO_PROFILE,
		"offset": func(th: float, y: float, _t: float) -> float: return Mannequin.torso_relief(th, y) + ease + (0.012 if cut in ["ancho", "holgado"] else 0.0),
	})
	parts.append(_part("tronco", pelvis, "principal", _trunk_extra({"contorno": 0.95, "largo": waist - 0.79})))
	var shin_len: float = {"tobillo": 0.39, "suelo": 0.43, "capri": 0.24, "rodilla": 0.0, "corto": 0.0}.get(length, 0.39)
	var thigh_len: float = 0.15 if length == "corto" else 0.385
	for side: String in ["d", "i"]:
		var thigh := MeshKit.lathe({"segments": maxi(12, segments / 2), "rings": _rings(thigh_len), "y_bottom": -thigh_len,
			"y_top": 0.06,
			"radius": func(_th: float, y: float, _t: float) -> Vector2:
				var r := MeshKit.sample_profile(Mannequin.THIGH, y)
				var u := clampf(-y / 0.385, 0.0, 1.0)
				var extra := ease + 0.004
				match cut:
					"ancho":
						extra += 0.03 + 0.03 * u
					"holgado":
						extra += 0.035
					"leggings", "pitillo":
						extra = 0.003
				return r + Vector2(extra, extra),
		})
		parts.append(_part("cadera_" + side, thigh, "principal", {"contorno": 0.5, "largo": thigh_len}))
		if shin_len > 0.0:
			var shin := MeshKit.lathe({"segments": maxi(12, segments / 2), "rings": _rings(shin_len), "y_bottom": -shin_len,
				"y_top": 0.04,
				"radius": func(_th: float, y: float, _t: float) -> Vector2:
					var r := MeshKit.sample_profile(Mannequin.SHIN, maxf(y, -0.4))
					var u := clampf(-y / shin_len, 0.0, 1.0)
					match cut:
						"pitillo", "leggings":
							return r + Vector2(0.004, 0.004)
						"ancho":
							return Vector2(0.075 + 0.045 * u, 0.075 + 0.045 * u)
						"campana":
							return r.lerp(Vector2(0.115, 0.115), smoothstep(0.35, 1.0, u)) + Vector2(ease, ease)
						"holgado":
							return Vector2(0.085, 0.085)
					return Vector2(maxf(r.x + ease, 0.064), maxf(r.y + ease, 0.064)),
			})
			parts.append(_part("rodilla_" + side, shin, "principal", {"contorno": 0.42, "largo": shin_len}))
	return parts


func coat(p: Dictionary) -> Array:
	var kind := str(p.get("tipo", "chaqueta"))
	var bottom: float = COAT_BOTTOM.get(str(p.get("largo", "cadera")), 0.86)
	if str(p.get("largo", "")) == "suelo":
		bottom -= heel
	var gap := float(p.get("abertura", 0.16))
	var flare := float(p.get("vuelo", 0.03))
	var ease := 0.02 + float(p.get("holgura", 0.0))
	var neck := str(p.get("escote", "solapa"))
	var depth := float(p.get("profundidad_escote", NECK_DEPTH.get(neck, 0.17)))
	var peplum := float(p.get("peplum", 0.0))
	var hip := body_radius(0.9) + Vector2(ease + 0.01, ease + 0.02)
	var span := maxf(SHOULDER_Y - bottom, 0.1)
	var opts := {"segments": segments, "rings": _rings(span), "y_bottom": bottom,
		"y_top": func(th: float) -> float: return neckline_y(neck, depth, th),
		"radius": func(_th: float, y: float, _t: float) -> Vector2:
			var r := body_radius(y) + Vector2(ease, ease)
			if y < 0.95:
				r = Vector2(maxf(r.x, hip.x), maxf(r.y, hip.y)) + Vector2.ONE * flare * smoothstep(0.95, bottom, y)
			var legs := leg_clearance(y) + Vector2(0.01, 0.01)
			return Vector2(maxf(r.x, legs.x), maxf(r.y, legs.y)),
		"offset": func(th: float, y: float, _t: float) -> float:
			var o := Mannequin.torso_relief(th, y) * 0.8
			if peplum > 0.0 and y < 1.04:
				o += peplum * smoothstep(0.0, 0.1, 1.04 - y)
			return o,
	}
	if gap > 0.0:
		opts["gap"] = gap
	var parts: Array = []
	var mesh := MeshKit.lathe(opts)
	parts.append(_part("tronco", mesh, "principal", _trunk_extra({"contorno": circumference(hip), "largo": span,
		"vaiven": bottom < 0.6, "cintura_local": 1.04})))
	if kind != "chaleco":
		var sp: Dictionary = p.get("mangas", {"tipo": "larga"}).duplicate()
		sp["holgura"] = float(sp.get("holgura", 0.0)) + 0.012
		sp["hombreras"] = float(p.get("hombreras", sp.get("hombreras", 0.0)))
		parts.append_array(sleeves(sp, 1))
	if neck == "solapa":
		parts.append_array(lapels(ease, depth))
	var buttons := int(p.get("botones", 0))
	if buttons > 0:
		parts.append(buttons_row(buttons, 1.24 - 0.1, maxf(bottom + 0.08, 0.98), gap, ease + 0.02))
	if p.get("cinturon", false):
		parts.append(_belt_band(1.04, ease + 0.012, 0.035, "secundario"))
	return parts


func cape(p: Dictionary) -> Dictionary:
	var bottom: float = COAT_BOTTOM.get(str(p.get("largo", "rodilla")), 0.46)
	var flare := float(p.get("vuelo", 0.12))
	var gap := float(p.get("abertura", 0.0))
	var span := 1.47 - bottom
	var opts := {"segments": segments, "rings": _rings(span), "y_bottom": bottom, "y_top": 1.47,
		"radius": func(_th: float, y: float, _t: float) -> Vector2:
			if y > 1.44:
				return Vector2(0.07, 0.065).lerp(Vector2(0.2, 0.13), smoothstep(1.47, 1.44, y))
			var s := clampf((1.44 - y) / maxf(1.44 - bottom, 0.1), 0.0, 1.0)
			var base := Vector2(0.235, 0.15).lerp(Vector2(0.26, 0.17), smoothstep(1.44, 1.36, y))
			var legs := leg_clearance(y) + Vector2(0.03, 0.03)
			base += Vector2(1.0, 0.85) * flare * s
			return Vector2(maxf(base.x, legs.x), maxf(base.y, legs.y)),
		"offset": func(th: float, y: float, _t: float) -> float:
			var s := clampf((1.4 - y) / maxf(1.4 - bottom, 0.1), 0.0, 1.0)
			return 0.012 * s * sin(th * 9.0),
	}
	if gap > 0.0:
		opts["gap"] = gap
	return _part("tronco", MeshKit.lathe(opts), "principal", _trunk_extra({"vaiven": true, "cintura_local": 1.4,
		"contorno": 1.4, "largo": span}))


func lapels(ease: float, depth: float) -> Array:
	var parts: Array = []
	for s: float in [-1.0, 1.0]:
		var top := Vector3(0.07 * s, SHOULDER_Y - 0.005, 0.07 + ease)
		var tip := Vector3(0.0, SHOULDER_Y - depth, 0.115 + ease)
		var outer := Vector3(0.135 * s, 1.355, 0.105 + ease)
		var notch := Vector3(0.115 * s, 1.415, 0.09 + ease)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n: Vector3 = (outer - tip).cross(top - tip).normalized() * s
		for v in [tip, outer, notch, tip, notch, top]:
			st.set_normal(n)
			st.set_uv(Vector2(v.x, v.y))
			st.set_uv2(Vector2(0.5, 0.5))
			st.add_vertex(v + n * 0.002)
		st.generate_tangents()
		parts.append(_part("tronco", st.commit(), "principal", _trunk_extra({})))
	return parts


func buttons_row(count: int, top_y: float, bottom_y: float, gap: float, ease: float) -> Dictionary:
	var meshes: Array = []
	var xforms: Array = []
	var th := gap * 0.5 + 0.05 if gap > 0.0 else 0.0
	for i in count:
		var y := lerpf(top_y, bottom_y, float(i) / maxf(count - 1, 1))
		var r := body_radius(y) + Vector2(ease, ease)
		var pos := Vector3(r.x * sin(th), y, r.y * cos(th) + Mannequin.torso_relief(th, y) + 0.004)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.0085
		cyl.bottom_radius = 0.0085
		cyl.height = 0.004
		cyl.radial_segments = 12
		cyl.rings = 1
		meshes.append(cyl)
		xforms.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), pos))
	return _part("tronco", MeshKit.merge(meshes, xforms), "boton", _trunk_extra({}))


func _belt_band(y: float, ease: float, width: float, role: String) -> Dictionary:
	var mesh := MeshKit.lathe({"segments": segments, "rings": 3, "y_bottom": y - width * 0.5, "y_top": y + width * 0.5,
		"profile": Mannequin.TORSO_PROFILE,
		"offset": func(th: float, yy: float, _t: float) -> float: return Mannequin.torso_relief(th, yy) + ease})
	return _part("tronco", mesh, role, _trunk_extra({}))


func _bow(center: Vector3, size: float, role: String) -> Dictionary:
	var a := MeshKit.ellipsoid(Vector3(size * 0.5, size * 0.28, size * 0.12), 12, 8)
	var k := MeshKit.ellipsoid(Vector3(size * 0.14, size * 0.16, size * 0.12), 10, 6)
	var mesh := MeshKit.merge([a, a, k], [
		Transform3D(Basis(Vector3.BACK, 0.35), center + Vector3(-size * 0.42, 0, 0)),
		Transform3D(Basis(Vector3.BACK, -0.35), center + Vector3(size * 0.42, 0, 0)),
		Transform3D(Basis.IDENTITY, center),
	])
	return _part("tronco", mesh, role, _trunk_extra({}))


## Tubo a lo largo de una polilínea (tirantes, asas, cadenas).
static func tube_path(points: Array, radius: float, sides: int = 6) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for i in points.size():
		var a: Vector3 = points[maxi(i - 1, 0)]
		var b: Vector3 = points[mini(i + 1, points.size() - 1)]
		var tangent := (b - a).normalized()
		var side := tangent.cross(Vector3.UP)
		if side.length_squared() < 0.001:
			side = tangent.cross(Vector3.RIGHT)
		side = side.normalized()
		var up := side.cross(tangent).normalized()
		var ring: Array = []
		for k in sides + 1:
			var ang := TAU * k / sides
			ring.append(points[i] + (side * cos(ang) + up * sin(ang)) * radius)
		rings.append(ring)
	for i in points.size() - 1:
		for k in sides:
			var quad := [rings[i][k], rings[i + 1][k], rings[i][k + 1], rings[i][k + 1], rings[i + 1][k], rings[i + 1][k + 1]]
			for v in quad:
				st.set_uv(Vector2(float(k) / sides, float(i)))
				st.set_uv2(Vector2(0.5, 0.5))
				st.add_vertex(v)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()
