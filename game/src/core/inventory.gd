class_name Inventory
extends RefCounted
## Armario del jugador. Las prendas adquiridas son permanentes: no se consumen, no caducan y no
## se duplican. Una misma prenda puede usarse en cualquier número de conjuntos.

signal changed

enum Result { ACQUIRED, ALREADY_OWNED, UNKNOWN_ITEM, CANNOT_AFFORD }

var owned: Dictionary = {}      ## id -> marca de tiempo de adquisición
var favorites: Dictionary = {}  ## id -> true
## Adquisiciones que el catálogo actual no contiene (contenido retirado o datos dañados): se
## conservan en la partida para no perder nunca una prenda.
var orphans: Dictionary = {}


func owns(id: String) -> bool:
	return owned.has(id)


func acquire(catalog: Catalog, economy: Economy, id: String, now: float) -> Result:
	if not catalog.has_item(id):
		return Result.UNKNOWN_ITEM
	if owned.has(id):
		return Result.ALREADY_OWNED
	var price := catalog.price_of(id)
	if not economy.spend(price["moneda"], price["valor"], "Compra: %s" % id, now):
		return Result.CANNOT_AFFORD
	owned[id] = now
	changed.emit()
	return Result.ACQUIRED


## Adquiere todas las prendas del catálogo (o de una era). Devuelve cuántas eran nuevas.
func acquire_all(catalog: Catalog, economy: Economy, now: float, era: String = "") -> int:
	var count := 0
	for id in catalog.order:
		if era.is_empty() or catalog.get_item(id)["era"] == era:
			if acquire(catalog, economy, id, now) == Result.ACQUIRED:
				count += 1
	return count


func is_favorite(id: String) -> bool:
	return favorites.has(id)


func set_favorite(id: String, value: bool) -> void:
	if value == favorites.has(id):
		return
	if value:
		favorites[id] = true
	else:
		favorites.erase(id)
	changed.emit()


func toggle_favorite(id: String) -> bool:
	set_favorite(id, not is_favorite(id))
	return is_favorite(id)


func owned_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in owned:
		ids.append(id)
	return ids


func to_dict() -> Dictionary:
	var all := orphans.duplicate()
	all.merge(owned, true)
	return {"adquiridas": all, "favoritas": favorites.keys()}


## Restaura el inventario sin crear duplicados (las claves de diccionario son únicas).
func load_dict(d: Dictionary, catalog: Catalog = null) -> void:
	owned.clear()
	favorites.clear()
	orphans.clear()
	var saved: Variant = d.get("adquiridas", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for id in saved:
			if catalog == null or catalog.has_item(id):
				owned[str(id)] = float(saved[id])
			else:
				orphans[str(id)] = float(saved[id])
	for id in d.get("favoritas", []):
		if catalog == null or catalog.has_item(str(id)):
			favorites[str(id)] = true
	changed.emit()
