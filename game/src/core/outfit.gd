class_name Outfit
extends RefCounted
## Conjunto actual: una prenda por categoría, con la regla vestido ⟷ parte de arriba/abajo.

signal changed

var slots: Dictionary = {}  ## categoría -> id de prenda


## Equipa una prenda y devuelve los ids que se quitaron para hacerle sitio.
func equip(item: Dictionary) -> Array[String]:
	var removed: Array[String] = []
	var slot: String = item["categoria"]
	if slot == "vestido":
		for s in ["parte_superior", "parte_inferior"]:
			if slots.has(s):
				removed.append(slots[s])
				slots.erase(s)
	elif slot == "parte_superior" or slot == "parte_inferior":
		if slots.has("vestido"):
			removed.append(slots["vestido"])
			slots.erase("vestido")
	if slots.has(slot) and slots[slot] != item["id"]:
		removed.append(slots[slot])
	slots[slot] = item["id"]
	changed.emit()
	return removed


## Si la prenda ya está puesta, la quita; si no, la pone. Devuelve true si quedó puesta.
func toggle(item: Dictionary) -> bool:
	if is_worn(item["id"]):
		unequip(item["categoria"])
		return false
	equip(item)
	return true


func unequip(slot: String) -> void:
	if slots.erase(slot):
		changed.emit()


func clear() -> void:
	if not slots.is_empty():
		slots.clear()
		changed.emit()


func is_worn(id: String) -> bool:
	return slots.values().has(id)


func item_ids() -> Array[String]:
	var ids: Array[String] = []
	for slot in Defs.CATEGORIES:
		if slots.has(slot):
			ids.append(slots[slot])
	return ids


func count() -> int:
	return slots.size()


## Firma estable del conjunto (para comparar entregas y detectar repeticiones).
func signature() -> String:
	var ids := item_ids()
	ids.sort()
	return "|".join(ids)


func to_dict() -> Dictionary:
	return slots.duplicate()


## Restaura desde un diccionario guardado; descarta prendas que ya no existan en el catálogo.
func load_dict(data: Dictionary, catalog: Catalog = null) -> Array[String]:
	var dropped: Array[String] = []
	slots.clear()
	for slot in data:
		var id := str(data[slot])
		if not Defs.CATEGORIES.has(slot):
			dropped.append(id)
		elif catalog != null and (not catalog.has_item(id) or catalog.get_item(id)["categoria"] != slot):
			dropped.append(id)
		else:
			slots[slot] = id
	changed.emit()
	return dropped


static func jaccard(a: Array, b: Array) -> float:
	if a.is_empty() and b.is_empty():
		return 1.0
	var set_a := {}
	for x in a:
		set_a[x] = true
	var inter := 0
	var union := set_a.size()
	for x in b:
		if set_a.has(x):
			inter += 1
		else:
			union += 1
	return float(inter) / float(union)
