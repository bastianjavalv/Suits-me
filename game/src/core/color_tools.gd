class_name ColorTools
extends RefCounted
## Familias de color y análisis de armonía cromática (reglas explícitas y explicables).


static func is_neutral(c: Color) -> bool:
	return c.s < 0.18 or c.v < 0.2 or (c.v > 0.92 and c.s < 0.25)


static func family_of(c: Color) -> String:
	var h := c.h * 360.0
	if c.v < 0.18:
		return "negro"
	if c.s < 0.12:
		return "blanco" if c.v > 0.85 else "gris"
	if h >= 20.0 and h < 55.0 and c.s < 0.38 and c.v > 0.6:
		return "beige"
	if h < 45.0 and c.v < 0.6 and c.s >= 0.3:
		return "marron"
	if (h >= 345.0 or h < 15.0) and c.s < 0.5 and c.v > 0.75:
		return "rosa"
	if h >= 345.0 or h < 15.0:
		return "rojo"
	if h < 40.0:
		return "naranja"
	if h < 70.0:
		return "amarillo"
	if h < 170.0:
		return "verde"
	if h < 250.0:
		return "azul"
	if h < 290.0:
		return "morado"
	return "rosa"


static func hue_distance(a: float, b: float) -> float:
	var d := absf(a - b)
	return minf(d, 360.0 - d)


## Arco mínimo (en grados) que contiene todos los tonos.
static func hue_span(hues: Array[float]) -> float:
	if hues.size() < 2:
		return 0.0
	var sorted: Array[float] = hues.duplicate()
	sorted.sort()
	var max_gap: float = 360.0 - sorted[-1] + sorted[0]
	for i in range(1, sorted.size()):
		max_gap = maxf(max_gap, sorted[i] - sorted[i - 1])
	return 360.0 - max_gap


## Agrupa tonos a menos de `threshold` grados entre sí. Devuelve los centros de cada grupo.
static func cluster_hues(hues: Array[float], threshold: float = 25.0) -> Array[float]:
	var sorted := hues.duplicate()
	sorted.sort()
	var clusters: Array = []
	for h in sorted:
		var placed := false
		for cl in clusters:
			if hue_distance(cl[-1], h) < threshold:
				cl.append(h)
				placed = true
				break
		if not placed:
			clusters.append([h])
	# Unir el primero y el último si se tocan a través de 0/360 grados.
	if clusters.size() > 1 and hue_distance(clusters[0][0], clusters[-1][-1]) < threshold:
		var last: Array = clusters.pop_back()
		clusters[0] = last + clusters[0]
	var centers: Array[float] = []
	for cl in clusters:
		var x := 0.0
		var y := 0.0
		for h in cl:
			x += cos(deg_to_rad(h))
			y += sin(deg_to_rad(h))
		centers.append(fposmod(rad_to_deg(atan2(y, x)), 360.0))
	return centers


## Devuelve {"esquema", "puntuacion" (0..1), "detalle": Array[String], "neutros", "cromaticos"}.
static func analyze(colors: Array[Color]) -> Dictionary:
	var neutrals := 0
	var hues: Array[float] = []
	var vivid := 0
	for c in colors:
		if is_neutral(c):
			neutrals += 1
		else:
			hues.append(c.h * 360.0)
			if c.s > 0.75 and c.v > 0.75:
				vivid += 1
	var detail: Array[String] = []
	var scheme := ""
	var score := 0.0
	if hues.is_empty():
		scheme = "neutro"
		score = 0.9 if neutrals > 0 else 0.0
		detail.append("Paleta neutra: blancos, negros, grises o crudos combinan entre sí.")
	else:
		var centers := cluster_hues(hues)
		var span := hue_span(hues)
		if centers.size() == 1:
			scheme = "monocromático"
			score = 1.0
			detail.append("Un solo tono en distintas intensidades.")
		elif span <= 75.0:
			scheme = "análogo"
			score = 0.95
			detail.append("Tonos vecinos en el círculo cromático (separación máxima %d°)." % roundi(span))
		elif centers.size() == 2:
			var d := hue_distance(centers[0], centers[1])
			if d >= 150.0:
				scheme = "complementario"
				score = 0.9
				detail.append("Dos tonos opuestos en el círculo cromático (%d°): contraste equilibrado." % roundi(d))
			else:
				scheme = "contraste libre"
				score = 0.6
				detail.append("Dos tonos a %d°: ni vecinos ni opuestos." % roundi(d))
		elif centers.size() == 3:
			if _is_triadic(centers):
				scheme = "triádico"
				score = 0.85
				detail.append("Tres tonos repartidos de forma regular (unos 120° entre sí).")
			elif _is_split_complementary(centers):
				scheme = "complementario dividido"
				score = 0.85
				detail.append("Un tono base y los dos vecinos de su opuesto.")
			else:
				scheme = "tres tonos libres"
				score = 0.5
				detail.append("Tres tonos sin una relación cromática clásica.")
		else:
			scheme = "multicolor"
			score = 0.45
			detail.append("%d familias de tono distintas: el conjunto puede resultar recargado." % centers.size())
		if vivid >= 3:
			score -= 0.1
			detail.append("Tres o más colores muy saturados compiten entre sí (-10 %).")
		if neutrals > 0 and centers.size() <= 2:
			score += 0.05
			detail.append("Los neutros equilibran el conjunto (+5 %).")
	return {"esquema": scheme, "puntuacion": clampf(score, 0.0, 1.0), "detalle": detail,
		"neutros": neutrals, "cromaticos": hues.size()}


static func _is_triadic(c: Array[float]) -> bool:
	var s := c.duplicate()
	s.sort()
	var gaps := [s[1] - s[0], s[2] - s[1], 360.0 - s[2] + s[0]]
	for g in gaps:
		if absf(g - 120.0) > 25.0:
			return false
	return true


static func _is_split_complementary(c: Array[float]) -> bool:
	for i in range(3):
		var others: Array[float] = []
		for j in range(3):
			if j != i:
				others.append(c[j])
		var ok := true
		for o in others:
			var d := hue_distance(c[i], o)
			if d < 125.0 or d > 175.0:
				ok = false
		if ok and hue_distance(others[0], others[1]) <= 90.0:
			return true
	return false


## Conversión sRGB -> CIELAB (D65) para comparar colores de forma perceptual.
static func to_lab(c: Color) -> Vector3:
	var lin := Vector3(_linear(c.r), _linear(c.g), _linear(c.b))
	var x := (lin.x * 0.4124 + lin.y * 0.3576 + lin.z * 0.1805) / 0.95047
	var y := (lin.x * 0.2126 + lin.y * 0.7152 + lin.z * 0.0722)
	var z := (lin.x * 0.0193 + lin.y * 0.1192 + lin.z * 0.9505) / 1.08883
	var fx := _f(x)
	var fy := _f(y)
	var fz := _f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func delta_e(a: Color, b: Color) -> float:
	return to_lab(a).distance_to(to_lab(b))


## Fracción de colores del conjunto que están cerca (ΔE < 25) de algún color de la paleta.
static func palette_match(colors: Array[Color], palette: Array[Color]) -> float:
	if colors.is_empty() or palette.is_empty():
		return 0.0
	var close := 0
	for c in colors:
		for p in palette:
			if delta_e(c, p) < 25.0:
				close += 1
				break
	return float(close) / float(colors.size())


static func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
