class_name Catalog
extends RefCounted
## Catálogo de prendas cargado desde res://data/prendas/*.json, con validación e índices.

var items: Dictionary = {}          ## id -> Dictionary (prenda)
var order: Array[String] = []       ## ids en orden de carga (estable)
var by_category: Dictionary = {}    ## categoría -> Array[String]
var by_era: Dictionary = {}         ## era -> Array[String]
var color_family: Dictionary = {}   ## id -> familia de color principal
var search_text: Dictionary = {}    ## id -> texto en minúsculas para búsqueda
var errors: Array[String] = []

var known_eras: Dictionary = {}     ## era -> true (vacío = no se comprueba)
var known_fabrics: Dictionary = {}  ## tejido -> true (vacío = no se comprueba)


func load_files(paths: Array) -> void:
	for path in paths:
		var doc := JsonUtil.load_object(path, errors)
		if doc.is_empty():
			continue
		var list: Variant = doc.get("prendas", [])
		if typeof(list) != TYPE_ARRAY:
			errors.append("%s: 'prendas' debe ser una lista" % path)
			continue
		for entry in list:
			if typeof(entry) != TYPE_DICTIONARY:
				errors.append("%s: hay una prenda que no es un objeto" % path)
				continue
			add_item(entry, path)


## Valida y agrega una prenda. Devuelve false si la prenda tiene errores.
func add_item(item: Dictionary, origin: String = "") -> bool:
	var problems := validate_item(item)
	var id := str(item.get("id", "?"))
	if items.has(id):
		problems.append("id duplicado")
	if not problems.is_empty():
		for p in problems:
			errors.append("%s [%s]: %s" % [origin, id, p])
		return false
	items[id] = item
	order.append(id)
	var cat: String = item["categoria"]
	var era: String = item["era"]
	if not by_category.has(cat):
		by_category[cat] = []
	by_category[cat].append(id)
	if not by_era.has(era):
		by_era[era] = []
	by_era[era].append(id)
	color_family[id] = ColorTools.family_of(Color.html(item["color"]))
	search_text[id] = ("%s %s %s" % [item["nombre"], " ".join(item.get("estilos", [])),
		" ".join(item.get("influencias", []))]).to_lower()
	return true


func validate_item(item: Dictionary) -> Array[String]:
	var p: Array[String] = []
	var id: Variant = item.get("id")
	if typeof(id) != TYPE_STRING or not Defs.is_valid_id(id):
		p.append("id ausente o con caracteres no permitidos (usa a-z, 0-9 y _)")
	if str(item.get("nombre", "")).strip_edges().is_empty():
		p.append("falta 'nombre'")
	if not Defs.CATEGORIES.has(str(item.get("categoria", ""))):
		p.append("categoría desconocida: %s" % item.get("categoria"))
	var era := str(item.get("era", ""))
	if era.is_empty() or (not known_eras.is_empty() and not known_eras.has(era)):
		p.append("era desconocida: %s" % era)
	if not Defs.is_hex_color(item.get("color")):
		p.append("'color' debe ser #RRGGBB")
	if item.has("color_secundario") and not Defs.is_hex_color(item["color_secundario"]):
		p.append("'color_secundario' debe ser #RRGGBB")
	var fabric := str(item.get("tejido", ""))
	if fabric.is_empty() or (not known_fabrics.is_empty() and not known_fabrics.has(fabric)):
		p.append("tejido desconocido: %s" % fabric)
	if not _is_string_list(item.get("estilos"), false):
		p.append("'estilos' debe ser una lista de textos no vacía")
	var seasons: Variant = item.get("temporadas")
	if not _is_string_list(seasons, false):
		p.append("'temporadas' debe ser una lista no vacía")
	else:
		for s in seasons:
			if not Defs.SEASONS.has(s):
				p.append("temporada desconocida: %s" % s)
	var price: Variant = item.get("precio")
	if typeof(price) != TYPE_DICTIONARY or not Defs.CURRENCIES.has(str(price.get("moneda", ""))) \
			or not (typeof(price.get("valor")) in [TYPE_INT, TYPE_FLOAT]) or float(price.get("valor")) < 0:
		p.append("'precio' debe ser {moneda: monedas|gemas, valor >= 0}")
	if not _is_string_list(item.get("tipologias"), false):
		p.append("'tipologias' debe enlazar al menos una ficha de la enciclopedia")
	if item.has("influencias") and not _is_string_list(item["influencias"], true):
		p.append("'influencias' debe ser una lista de textos")
	var sheet: Variant = item.get("ficha")
	if typeof(sheet) != TYPE_DICTIONARY:
		p.append("falta la 'ficha' de la prenda")
	else:
		for key in ["descripcion", "materiales_modelo", "silueta", "uso"]:
			if str(sheet.get(key, "")).strip_edges().is_empty():
				p.append("ficha: falta '%s'" % key)
		if not Defs.PIECE_TYPES.has(str(sheet.get("tipo_pieza", ""))):
			p.append("ficha: 'tipo_pieza' no válido")
		var attribution: Variant = sheet.get("atribucion")
		if typeof(attribution) != TYPE_DICTIONARY or not Defs.ATTRIBUTION_STATES.has(str(attribution.get("estado", ""))):
			p.append("ficha: 'atribucion.estado' no válido")
		elif attribution["estado"] == "documentada" and _is_empty_list(attribution.get("fuentes")):
			p.append("ficha: una atribución documentada necesita 'fuentes'")
	var model: Variant = item.get("modelo")
	if typeof(model) != TYPE_DICTIONARY or str(model.get("generador", "")).is_empty() \
			or typeof(model.get("params", {})) != TYPE_DICTIONARY:
		p.append("'modelo' debe tener 'generador' y 'params'")
	return p


func has_item(id: String) -> bool:
	return items.has(id)


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func price_of(id: String) -> Dictionary:
	var item := get_item(id)
	if item.is_empty():
		return {}
	return {"moneda": str(item["precio"]["moneda"]), "valor": int(item["precio"]["valor"])}


func size() -> int:
	return items.size()


static func _is_string_list(value: Variant, allow_empty: bool) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	if value.is_empty() and not allow_empty:
		return false
	for v in value:
		if typeof(v) != TYPE_STRING or str(v).strip_edges().is_empty():
			return false
	return true


static func _is_empty_list(value: Variant) -> bool:
	return typeof(value) != TYPE_ARRAY or value.is_empty()
