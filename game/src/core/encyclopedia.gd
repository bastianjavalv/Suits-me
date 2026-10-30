class_name Encyclopedia
extends RefCounted
## Enciclopedia histórica local. Cada afirmación lleva su estado de verificación y sus fuentes.
## Las prendas enlazan sus fichas por identificador ('tipologias').

var entries: Dictionary = {}  ## id -> ficha de tipología
var sources: Dictionary = {}  ## id -> fuente
var by_era: Dictionary = {}   ## era -> Array[String]
var order: Array[String] = []
var errors: Array[String] = []

const SOURCE_TYPES: Array[String] = ["museo", "archivo", "institucional", "publicacion", "libro", "marca", "enciclopedia"]
const SOURCE_METHODS: Array[String] = ["busqueda_web", "lectura_directa", "bibliografia"]
const CLAIM_FIELDS: Array[String] = ["hechos", "materiales", "tecnicas", "silueta", "uso", "influencia", "curiosidades"]


func load_sources(path: String) -> void:
	var doc := JsonUtil.load_object(path, errors)
	for s in doc.get("fuentes", []):
		var problems := _validate_source(s)
		var id := str(s.get("id", "?")) if typeof(s) == TYPE_DICTIONARY else "?"
		if sources.has(id):
			problems.append("fuente duplicada")
		if problems.is_empty():
			sources[id] = s
		else:
			for p in problems:
				errors.append("%s [%s]: %s" % [path, id, p])


func load_entries(paths: Array) -> void:
	for path in paths:
		var doc := JsonUtil.load_object(path, errors)
		for e in doc.get("entradas", []):
			if typeof(e) != TYPE_DICTIONARY:
				errors.append("%s: hay una entrada que no es un objeto" % path)
				continue
			var problems := validate_entry(e)
			var id := str(e.get("id", "?"))
			if entries.has(id):
				problems.append("ficha duplicada")
			if problems.is_empty():
				entries[id] = e
				order.append(id)
				var era := str(e["era"])
				if not by_era.has(era):
					by_era[era] = []
				by_era[era].append(id)
			else:
				for p in problems:
					errors.append("%s [%s]: %s" % [path, id, p])


func _validate_source(s: Variant) -> Array[String]:
	var p: Array[String] = []
	if typeof(s) != TYPE_DICTIONARY:
		return ["la fuente no es un objeto"]
	if not Defs.is_valid_id(str(s.get("id", ""))):
		p.append("id no válido")
	for k in ["titulo", "autor", "consultado"]:
		if str(s.get(k, "")).strip_edges().is_empty():
			p.append("falta '%s'" % k)
	if not SOURCE_TYPES.has(str(s.get("tipo", ""))):
		p.append("'tipo' debe ser uno de %s" % ", ".join(SOURCE_TYPES))
	if not SOURCE_METHODS.has(str(s.get("metodo", ""))):
		p.append("'metodo' debe ser uno de %s" % ", ".join(SOURCE_METHODS))
	var url := str(s.get("url", ""))
	if not url.is_empty() and not url.begins_with("https://"):
		p.append("la URL debe empezar por https://")
	return p


func validate_entry(e: Dictionary) -> Array[String]:
	var p: Array[String] = []
	if not Defs.is_valid_id(str(e.get("id", ""))):
		p.append("id no válido")
	for k in ["nombre", "era", "periodo", "region", "resumen"]:
		if str(e.get(k, "")).strip_edges().is_empty():
			p.append("falta '%s'" % k)
	if typeof(e.get("revision_humana")) != TYPE_BOOL:
		p.append("falta 'revision_humana' (true/false)")
	if typeof(e.get("hechos")) != TYPE_ARRAY or e["hechos"].is_empty():
		p.append("'hechos' debe tener al menos una afirmación")
	for field in CLAIM_FIELDS:
		if not e.has(field):
			continue
		if typeof(e[field]) != TYPE_ARRAY:
			p.append("'%s' debe ser una lista de afirmaciones" % field)
			continue
		for claim in e[field]:
			p.append_array(_validate_claim(claim, field))
	for ref in e.get("piezas_referencia", []):
		if typeof(ref) != TYPE_DICTIONARY or str(ref.get("titulo", "")).is_empty() \
				or typeof(ref.get("fuentes")) != TYPE_ARRAY or ref["fuentes"].is_empty():
			p.append("cada pieza de referencia necesita 'titulo' y 'fuentes'")
	return p


func _validate_claim(claim: Variant, field: String) -> Array[String]:
	if typeof(claim) != TYPE_DICTIONARY:
		return ["%s: cada afirmación debe ser un objeto {texto, estado, fuentes}" % field]
	var p: Array[String] = []
	if str(claim.get("texto", "")).strip_edges().is_empty():
		p.append("%s: afirmación sin texto" % field)
	var state := str(claim.get("estado", ""))
	if not Defs.CLAIM_STATES.has(state):
		p.append("%s: estado no válido '%s'" % [field, state])
	var refs: Variant = claim.get("fuentes", [])
	if typeof(refs) != TYPE_ARRAY:
		p.append("%s: 'fuentes' debe ser una lista" % field)
	elif state != "interpretacion" and refs.is_empty():
		p.append("%s: una afirmación '%s' necesita al menos una fuente" % [field, state])
	return p


## Comprueba que todas las fuentes citadas existen. Se llama tras cargar fuentes y fichas.
func check_references() -> void:
	for id in order:
		for src in cited_sources(entries[id]):
			if not sources.has(src):
				errors.append("[%s]: cita una fuente inexistente: %s" % [id, src])


func cited_sources(e: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for field in CLAIM_FIELDS:
		for claim in e.get(field, []):
			if typeof(claim) == TYPE_DICTIONARY:
				for s in claim.get("fuentes", []):
					if not out.has(str(s)):
						out.append(str(s))
	for ref in e.get("piezas_referencia", []):
		for s in ref.get("fuentes", []):
			if not out.has(str(s)):
				out.append(str(s))
	return out


func has_entry(id: String) -> bool:
	return entries.has(id)


func get_entry(id: String) -> Dictionary:
	return entries.get(id, {})


## Compone la "Historia de la prenda": datos de la prenda + fichas enlazadas + fuentes citadas.
func sheet_for_item(item: Dictionary) -> Dictionary:
	var linked: Array = []
	var cited: Array[String] = []
	for tid in item.get("tipologias", []):
		if entries.has(tid):
			linked.append(entries[tid])
			for s in cited_sources(entries[tid]):
				if not cited.has(s):
					cited.append(s)
	var attribution: Dictionary = item["ficha"].get("atribucion", {})
	for s in attribution.get("fuentes", []):
		if not cited.has(str(s)):
			cited.append(str(s))
	var source_list: Array = []
	for s in cited:
		if sources.has(s):
			source_list.append(sources[s])
	return {"prenda": item, "fichas": linked, "fuentes": source_list,
		"pendiente_revision": linked.any(func(e): return not e.get("revision_humana", false))}


func search(text: String) -> Array[String]:
	var q := text.strip_edges().to_lower()
	var out: Array[String] = []
	for id in order:
		var e: Dictionary = entries[id]
		if q.is_empty() or ("%s %s %s" % [e["nombre"], e["resumen"], e.get("periodo", "")]).to_lower().contains(q):
			out.append(id)
	return out
