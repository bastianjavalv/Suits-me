class_name ChallengeBook
extends RefCounted
## Desafíos de moda y progreso local. Se pueden presentar varias alternativas por desafío;
## se conserva la mejor puntuación y las últimas entregas.

signal changed

const MAX_SUBMISSIONS := 10
const TYPES: Array[String] = ["recreacion_historica", "creativo", "libre"]

var challenges: Dictionary = {}  ## id -> definición
var order: Array[String] = []
var progress: Dictionary = {}    ## id -> {mejor, estrellas, entregas: [{t, prendas, total, estrellas}]}
var errors: Array[String] = []
var known_eras: Dictionary = {}
var known_stages: Dictionary = {}


func load_file(path: String) -> void:
	var doc := JsonUtil.load_object(path, errors)
	for c in doc.get("desafios", []):
		if typeof(c) != TYPE_DICTIONARY:
			errors.append("%s: hay un desafío que no es un objeto" % path)
			continue
		var problems := validate(c)
		var id := str(c.get("id", "?"))
		if challenges.has(id):
			problems.append("desafío duplicado")
		if problems.is_empty():
			challenges[id] = c
			order.append(id)
		else:
			for p in problems:
				errors.append("%s [%s]: %s" % [path, id, p])


func validate(c: Dictionary) -> Array[String]:
	var p: Array[String] = []
	if not Defs.is_valid_id(str(c.get("id", ""))):
		p.append("id no válido")
	for k in ["titulo", "descripcion"]:
		if str(c.get(k, "")).strip_edges().is_empty():
			p.append("falta '%s'" % k)
	if not TYPES.has(str(c.get("tipo", ""))):
		p.append("'tipo' debe ser uno de %s" % ", ".join(TYPES))
	var era := str(c.get("era", ""))
	if not known_eras.is_empty() and not era.is_empty() and not known_eras.has(era):
		p.append("era desconocida: %s" % era)
	for e in c.get("eras_validas", []):
		if not known_eras.is_empty() and not known_eras.has(e):
			p.append("era válida desconocida: %s" % e)
	var stage := str(c.get("escenario", ""))
	if not known_stages.is_empty() and not stage.is_empty() and not known_stages.has(stage):
		p.append("escenario desconocido: %s" % stage)
	var req: Variant = c.get("requisitos", {})
	if typeof(req) != TYPE_DICTIONARY:
		p.append("'requisitos' debe ser un objeto")
	else:
		for key in ["obligatorias", "sugeridas"]:
			for cat in req.get(key, []):
				if cat != "prenda_principal" and not Defs.CATEGORIES.has(cat):
					p.append("categoría desconocida en requisitos: %s" % cat)
	for hex in c.get("paleta", []):
		if not Defs.is_hex_color(hex):
			p.append("color de paleta no válido: %s" % hex)
	return p


func for_era(era: String) -> Array[String]:
	var out: Array[String] = []
	for id in order:
		if challenges[id].get("era", "") == era:
			out.append(id)
	return out


func submissions(id: String) -> Array:
	return progress.get(id, {}).get("entregas", [])


## Evalúa y registra una entrega. Devuelve la evaluación con "nuevo_record".
func submit(id: String, slots: Dictionary, catalog: Catalog, era_names: Dictionary, now: float) -> Dictionary:
	if not challenges.has(id):
		return {}
	var result := Evaluator.evaluate(challenges[id], slots, catalog, era_names, submissions(id))
	var p: Dictionary = progress.get(id, {"mejor": 0, "estrellas": 0, "entregas": []})
	var entries: Array = p["entregas"]
	entries.append({"t": now, "prendas": slots.duplicate(), "total": result["total"], "estrellas": result["estrellas"]})
	if entries.size() > MAX_SUBMISSIONS:
		entries = entries.slice(entries.size() - MAX_SUBMISSIONS)
	result["nuevo_record"] = int(result["total"]) > int(p["mejor"])
	p["mejor"] = maxi(int(p["mejor"]), int(result["total"]))
	p["estrellas"] = maxi(int(p["estrellas"]), int(result["estrellas"]))
	p["entregas"] = entries
	progress[id] = p
	changed.emit()
	return result


func best(id: String) -> int:
	return int(progress.get(id, {}).get("mejor", 0))


func stars(id: String) -> int:
	return int(progress.get(id, {}).get("estrellas", 0))


func era_summary(era: String) -> Dictionary:
	var ids := for_era(era)
	var done := 0
	var total_stars := 0
	for id in ids:
		if stars(id) > 0:
			done += 1
		total_stars += stars(id)
	return {"desafios": ids.size(), "completados": done, "estrellas": total_stars, "max_estrellas": ids.size() * 3}


func to_dict() -> Dictionary:
	return progress.duplicate(true)


func load_dict(d: Dictionary) -> void:
	progress = d.duplicate(true)
	changed.emit()
