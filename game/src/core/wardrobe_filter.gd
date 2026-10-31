class_name WardrobeFilter
extends RefCounted
## Búsqueda del armario por categoría, época, color, estilo, temporada, diseñador o influencia,
## precio, favoritas y texto. Las listas vacías no filtran.

static func default_spec() -> Dictionary:
	return {
		"categoria": "", "eras": [], "colores": [], "estilos": [], "temporadas": [], "influencias": [],
		"moneda": "", "precio_min": -1, "precio_max": -1, "solo_favoritas": false, "solo_adquiridas": false,
		"texto": "", "orden": "era",
	}


static func apply(catalog: Catalog, inventory: Inventory, spec: Dictionary, era_order: Dictionary = {}) -> Array[String]:
	var s := default_spec()
	s.merge(spec, true)
	var text := str(s["texto"]).strip_edges().to_lower()
	var pool: Array = catalog.by_category.get(s["categoria"], []) if not str(s["categoria"]).is_empty() else catalog.order
	var out: Array[String] = []
	for id in pool:
		var it := catalog.get_item(id)
		if not s["eras"].is_empty() and not s["eras"].has(it["era"]):
			continue
		if not s["colores"].is_empty() and not s["colores"].has(it.get("familia_color", catalog.color_family[id])):
			continue
		if not s["estilos"].is_empty() and not _any_in(it["estilos"], s["estilos"]):
			continue
		if not s["temporadas"].is_empty() and not _any_in(it["temporadas"], s["temporadas"]):
			continue
		if not s["influencias"].is_empty() and not _any_in(it.get("influencias", []), s["influencias"]):
			continue
		var price: Dictionary = it["precio"]
		if not str(s["moneda"]).is_empty() and price["moneda"] != s["moneda"]:
			continue
		if int(s["precio_min"]) >= 0 and int(price["valor"]) < int(s["precio_min"]):
			continue
		if int(s["precio_max"]) >= 0 and int(price["valor"]) > int(s["precio_max"]):
			continue
		if s["solo_favoritas"] and not inventory.is_favorite(id):
			continue
		if s["solo_adquiridas"] and not inventory.owns(id):
			continue
		if not text.is_empty() and not catalog.search_text[id].contains(text):
			continue
		out.append(id)
	_sort(out, catalog, inventory, str(s["orden"]), era_order)
	return out


static func _sort(ids: Array[String], catalog: Catalog, inventory: Inventory, mode: String, era_order: Dictionary) -> void:
	match mode:
		"nombre":
			ids.sort_custom(func(a, b): return catalog.get_item(a)["nombre"].naturalnocasecmp_to(catalog.get_item(b)["nombre"]) < 0)
		"precio":
			ids.sort_custom(func(a, b): return int(catalog.get_item(a)["precio"]["valor"]) < int(catalog.get_item(b)["precio"]["valor"]))
		"reciente":
			ids.sort_custom(func(a, b): return float(inventory.owned.get(a, -1.0)) > float(inventory.owned.get(b, -1.0)))
		_:
			var pos := {}
			for i in catalog.order.size():
				pos[catalog.order[i]] = i
			ids.sort_custom(func(a, b):
				var ea: int = era_order.get(catalog.get_item(a)["era"], 99)
				var eb: int = era_order.get(catalog.get_item(b)["era"], 99)
				return ea < eb if ea != eb else pos[a] < pos[b])


## Valores disponibles para construir los menús de filtro.
static func facets(catalog: Catalog) -> Dictionary:
	var styles := {}
	var influences := {}
	var families := {}
	for id in catalog.order:
		var it := catalog.get_item(id)
		for st in it["estilos"]:
			styles[st] = true
		for inf in it.get("influencias", []):
			influences[inf] = true
		families[it.get("familia_color", catalog.color_family[id])] = true
	var st_list := styles.keys()
	st_list.sort()
	var inf_list := influences.keys()
	inf_list.sort()
	var fam_list: Array = []
	for f in Defs.COLOR_FAMILIES:
		if families.has(f):
			fam_list.append(f)
	return {"estilos": st_list, "influencias": inf_list, "colores": fam_list}


static func _any_in(values: Array, wanted: Array) -> bool:
	for v in values:
		if wanted.has(v):
			return true
	return false
