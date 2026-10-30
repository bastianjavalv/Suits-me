class_name OutfitLibrary
extends RefCounted
## Looks guardados, borradores editables, historial de atuendos y papelera recuperable.

signal changed

const MAX_HISTORY := 100
const MAX_TRASH := 30
const MAX_NAME := 40

var looks: Dictionary = {}   ## id -> {id, nombre, prendas, etiquetas, creado, actualizado, desafio}
var drafts: Dictionary = {}  ## id -> {id, nombre, prendas, contexto, creado, actualizado}
var history: Array = []      ## [{t, prendas, origen, desafio}] (más reciente al final)
var trash: Array = []        ## [{borrado, tipo, datos}]
var _counter := 0


func _new_id(prefix: String, now: float) -> String:
	_counter += 1
	return "%s_%d_%d" % [prefix, int(now), _counter]


static func clean_name(name: String, fallback: String) -> String:
	var n := name.strip_edges().replace("\n", " ")
	if n.is_empty():
		n = fallback
	return n.substr(0, MAX_NAME)


func save_look(name: String, outfit: Dictionary, now: float, tags: Array = [], challenge: String = "") -> String:
	var id := _new_id("look", now)
	looks[id] = {
		"id": id, "nombre": clean_name(name, "Look %d" % (looks.size() + 1)), "prendas": outfit.duplicate(),
		"etiquetas": tags.duplicate(), "creado": now, "actualizado": now, "desafio": challenge,
	}
	changed.emit()
	return id


func update_look(id: String, outfit: Dictionary, now: float) -> bool:
	if not looks.has(id):
		return false
	looks[id]["prendas"] = outfit.duplicate()
	looks[id]["actualizado"] = now
	changed.emit()
	return true


func rename_look(id: String, name: String) -> bool:
	if not looks.has(id):
		return false
	looks[id]["nombre"] = clean_name(name, looks[id]["nombre"])
	changed.emit()
	return true


func duplicate_look(id: String, now: float) -> String:
	if not looks.has(id):
		return ""
	var src: Dictionary = looks[id]
	return save_look("%s (copia)" % src["nombre"], src["prendas"], now, src.get("etiquetas", []), src.get("desafio", ""))


func delete_look(id: String, now: float) -> bool:
	if not looks.has(id):
		return false
	_to_trash("look", looks[id], now)
	looks.erase(id)
	changed.emit()
	return true


## Guarda o actualiza un borrador. Devuelve su id.
func save_draft(outfit: Dictionary, context: String, now: float, draft_id: String = "") -> String:
	if draft_id.is_empty() or not drafts.has(draft_id):
		draft_id = _new_id("borrador", now)
		drafts[draft_id] = {"id": draft_id, "nombre": "Borrador %d" % (drafts.size() + 1), "creado": now}
	drafts[draft_id]["prendas"] = outfit.duplicate()
	drafts[draft_id]["contexto"] = context
	drafts[draft_id]["actualizado"] = now
	changed.emit()
	return draft_id


func delete_draft(id: String, now: float) -> bool:
	if not drafts.has(id):
		return false
	_to_trash("borrador", drafts[id], now)
	drafts.erase(id)
	changed.emit()
	return true


## Convierte un borrador en look guardado.
func promote_draft(id: String, name: String, now: float) -> String:
	if not drafts.has(id):
		return ""
	var d: Dictionary = drafts[id]
	var look_id := save_look(name if not name.is_empty() else d["nombre"], d["prendas"], now)
	drafts.erase(id)
	changed.emit()
	return look_id


func record_history(outfit: Dictionary, origin: String, now: float, challenge: String = "") -> void:
	if outfit.is_empty():
		return
	if not history.is_empty() and history[-1]["prendas"] == outfit and history[-1]["origen"] == origin:
		return
	history.append({"t": now, "prendas": outfit.duplicate(), "origen": origin, "desafio": challenge})
	if history.size() > MAX_HISTORY:
		history = history.slice(history.size() - MAX_HISTORY)
	changed.emit()


func restore_from_trash(index: int) -> String:
	if index < 0 or index >= trash.size():
		return ""
	var entry: Dictionary = trash[index]
	trash.remove_at(index)
	var data: Dictionary = entry["datos"]
	var target := looks if entry["tipo"] == "look" else drafts
	target[data["id"]] = data
	changed.emit()
	return data["id"]


func _to_trash(kind: String, data: Dictionary, now: float) -> void:
	trash.append({"borrado": now, "tipo": kind, "datos": data.duplicate(true)})
	if trash.size() > MAX_TRASH:
		trash = trash.slice(trash.size() - MAX_TRASH)


func looks_sorted() -> Array:
	var list := looks.values()
	list.sort_custom(func(a, b): return a["actualizado"] > b["actualizado"])
	return list


func drafts_sorted() -> Array:
	var list := drafts.values()
	list.sort_custom(func(a, b): return a["actualizado"] > b["actualizado"])
	return list


func to_dict() -> Dictionary:
	return {"looks": looks.duplicate(true), "borradores": drafts.duplicate(true),
		"historial": history.duplicate(true), "papelera": trash.duplicate(true), "contador": _counter}


func load_dict(d: Dictionary) -> void:
	looks = d.get("looks", {}).duplicate(true)
	drafts = d.get("borradores", {}).duplicate(true)
	history = d.get("historial", []).duplicate(true)
	trash = d.get("papelera", []).duplicate(true)
	_counter = int(d.get("contador", 0))
	changed.emit()
