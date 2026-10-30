class_name Evaluator
extends RefCounted
## Evaluación local y transparente de un conjunto frente a un desafío. Reglas fijas y públicas:
##   Coherencia temática  40 pts  (época 70 %, estilo 30 %)
##   Armonía cromática    25 pts  (esquema de color; paleta sugerida si el desafío la tiene)
##   Completitud          15 pts  (categorías obligatorias 10 + sugeridas 5)
##   Creatividad          20 pts  (complementos 10 + originalidad frente a tus entregas anteriores 10)
## Estrellas: 60, 75 y 90 puntos.

const MAX_POINTS := {"tema": 40, "color": 25, "completo": 15, "creatividad": 20}
const STAR_THRESHOLDS: Array[int] = [60, 75, 90]
const NOTICE := "Evaluación local sin conexión: la calcula el juego con reglas fijas y públicas. " + \
	"No es una votación de otros jugadores."
## Categorías que no cuentan para la armonía cromática (colores naturales de pelo y piel).
const COLOR_EXCLUDED: Array[String] = ["peinado", "maquillaje"]


static func stars_for(total: int) -> int:
	var stars := 0
	for t in STAR_THRESHOLDS:
		if total >= t:
			stars += 1
	return stars


static func has_main_garment(slots: Dictionary) -> bool:
	return slots.has("vestido") or (slots.has("parte_superior") and slots.has("parte_inferior"))


## `slots`: categoría -> id. `previous`: lista de entregas anteriores ({prendas: {...}}).
static func evaluate(challenge: Dictionary, slots: Dictionary, catalog: Catalog, era_names: Dictionary,
		previous: Array = []) -> Dictionary:
	var items: Array[Dictionary] = []
	for slot in Defs.CATEGORIES:
		if slots.has(slot) and catalog.has_item(slots[slot]):
			items.append(catalog.get_item(slots[slot]))
	var criteria: Array = []
	criteria.append(_theme(challenge, items, era_names))
	criteria.append(_color(challenge, items))
	criteria.append(_completeness(challenge, slots, catalog))
	criteria.append(_creativity(slots, previous))
	var total := 0
	for c in criteria:
		total += int(c["puntos"])
	return {"total": total, "estrellas": stars_for(total), "criterios": criteria, "aviso": NOTICE}


static func _theme(challenge: Dictionary, items: Array[Dictionary], era_names: Dictionary) -> Dictionary:
	var detail: Array[String] = []
	var valid_eras: Array = challenge.get("eras_validas", [])
	var tags: Array = challenge.get("etiquetas_tema", [])
	if items.is_empty():
		return _criterion("tema", "Coherencia temática", 0, ["El conjunto está vacío."])
	var era_ok := 0
	var style_ok := 0
	var anachronisms: Array[String] = []
	for it in items:
		if valid_eras.is_empty() or valid_eras.has(it["era"]):
			era_ok += 1
		else:
			anachronisms.append("%s (%s)" % [it["nombre"], era_names.get(it["era"], it["era"])])
		if tags.is_empty() or _intersects(it.get("estilos", []), tags):
			style_ok += 1
	var n := float(items.size())
	var points := roundi(MAX_POINTS["tema"] * (0.7 * era_ok / n + 0.3 * style_ok / n))
	if valid_eras.is_empty():
		detail.append("Desafío libre: se admite cualquier época.")
	else:
		detail.append("%d de %d prendas pertenecen a la época pedida." % [era_ok, items.size()])
		if not anachronisms.is_empty():
			detail.append("Fuera de época: %s." % ", ".join(anachronisms))
	if not tags.is_empty():
		detail.append("%d de %d prendas encajan con el estilo «%s»." % [style_ok, items.size(), ", ".join(tags)])
	# Normas del desafío (por ejemplo, una ley suntuaria): cada prenda que las incumple resta 8 puntos.
	var banned: Dictionary = challenge.get("requisitos", {}).get("prohibidos", {})
	var banned_fabrics: Array = banned.get("tejidos", [])
	var banned_colors: Array = banned.get("colores", [])
	for it in items:
		var reasons: Array[String] = []
		if banned_fabrics.has(it.get("tejido", "")):
			reasons.append("tejido no permitido")
		if banned_colors.has(it.get("familia_color", ColorTools.family_of(Color.html(it["color"])))):
			reasons.append("color no permitido")
		if not reasons.is_empty():
			points -= 8
			detail.append("Incumple la norma del desafío: %s (%s)." % [it["nombre"], ", ".join(reasons)])
	return _criterion("tema", "Coherencia temática", points, detail)


static func _color(challenge: Dictionary, items: Array[Dictionary]) -> Dictionary:
	var colors: Array[Color] = []
	for it in items:
		if not COLOR_EXCLUDED.has(it["categoria"]):
			colors.append(Color.html(it["color"]))
	if colors.is_empty():
		return _criterion("color", "Armonía cromática", 0, ["No hay prendas con color que evaluar."])
	var analysis := ColorTools.analyze(colors)
	var detail: Array[String] = ["Esquema: %s." % analysis["esquema"]]
	detail.append_array(analysis["detalle"])
	var score: float = analysis["puntuacion"]
	var palette: Array[Color] = []
	for hex in challenge.get("paleta", []):
		palette.append(Color.html(hex))
	if not palette.is_empty():
		var match := ColorTools.palette_match(colors, palette)
		detail.append("%d %% de los colores se acercan a la paleta sugerida." % roundi(match * 100.0))
		score = 0.6 * score + 0.4 * match
	return _criterion("color", "Armonía cromática", roundi(MAX_POINTS["color"] * score), detail)


static func _completeness(challenge: Dictionary, slots: Dictionary, catalog_ref: Catalog = null) -> Dictionary:
	var req: Dictionary = challenge.get("requisitos", {})
	var mandatory: Array = req.get("obligatorias", ["prenda_principal", "calzado"])
	var suggested: Array = req.get("sugeridas", [])
	var detail: Array[String] = []
	var ok_m := 0
	for c in mandatory:
		if _slot_filled(c, slots):
			ok_m += 1
		else:
			detail.append("Falta: %s." % _slot_label(c))
	var ok_s := 0
	for c in suggested:
		if _slot_filled(c, slots):
			ok_s += 1
	var min_eras := int(req.get("min_eras", 0))
	if min_eras > 0:
		var seen := {}
		for id in slots.values():
			if catalog_ref != null and catalog_ref.has_item(id):
				seen[catalog_ref.get_item(id)["era"]] = true
		mandatory = mandatory.duplicate()
		mandatory.append("min_eras")
		if seen.size() >= min_eras:
			ok_m += 1
		else:
			detail.append("Faltan épocas: hay %d de %d distintas." % [seen.size(), min_eras])
	var points := 0.0
	points += 10.0 * (float(ok_m) / mandatory.size() if not mandatory.is_empty() else 1.0)
	points += 5.0 * (float(ok_s) / suggested.size() if not suggested.is_empty() else 1.0)
	if ok_m == mandatory.size():
		detail.insert(0, "Todas las categorías obligatorias están cubiertas.")
	if not suggested.is_empty():
		detail.append("Sugeridas: %d de %d." % [ok_s, suggested.size()])
	return _criterion("completo", "Completitud", roundi(points), detail)


static func _creativity(slots: Dictionary, previous: Array) -> Dictionary:
	var detail: Array[String] = []
	var accessories := 0
	for s in Defs.ACCESSORY_SLOTS:
		if slots.has(s):
			accessories += 1
	var acc_points := 10.0 * minf(1.0, accessories / 3.0)
	detail.append("Complementos de %d tipos distintos (máximo puntuable: 3)." % accessories)
	var ids := slots.values()
	var max_sim := 0.0
	for p in previous:
		max_sim = maxf(max_sim, Outfit.jaccard(ids, p.get("prendas", {}).values()))
	var novelty := 1.0 - max_sim
	if previous.is_empty():
		detail.append("Primera entrega para este desafío.")
	else:
		detail.append("Se parece en un %d %% a tu entrega anterior más parecida." % roundi(max_sim * 100.0))
	return _criterion("creatividad", "Creatividad", roundi(acc_points + 10.0 * novelty), detail)


static func _slot_filled(category: String, slots: Dictionary) -> bool:
	if category == "prenda_principal":
		return has_main_garment(slots)
	return slots.has(category)


static func _slot_label(category: String) -> String:
	if category == "prenda_principal":
		return "un vestido, o una parte de arriba y otra de abajo"
	return str(Defs.CATEGORY_NAMES.get(category, category)).to_lower()


static func _intersects(a: Array, b: Array) -> bool:
	for x in a:
		if b.has(x):
			return true
	return false


static func _criterion(id: String, name: String, points: int, detail: Array[String]) -> Dictionary:
	return {"id": id, "nombre": name, "puntos": clampi(points, 0, MAX_POINTS[id]), "max": MAX_POINTS[id],
		"detalle": detail}
