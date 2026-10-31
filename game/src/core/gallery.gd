class_name Gallery
extends RefCounted
## Galería local de fotografías de looks: imagen PNG, miniatura y los datos para recrear el look.

signal changed

const THUMB_SIZE := Vector2i(384, 216)

var dir: String
var entries: Dictionary = {}  ## id -> {id, titulo, imagen, miniatura, prendas, pose, escenario, era, creado}
var _counter := 0
var last_error := ""


func _init(base_dir: String = "user://galeria") -> void:
	dir = base_dir


func add_photo(image: Image, meta: Dictionary, now: float) -> String:
	last_error = ""
	if image == null or image.is_empty():
		last_error = "La imagen está vacía."
		return ""
	if not DirAccess.dir_exists_absolute(dir) and DirAccess.make_dir_recursive_absolute(dir) != OK:
		last_error = "No se pudo crear la carpeta de la galería."
		return ""
	_counter += 1
	var id := "foto_%d_%d" % [int(now), _counter]
	var full := dir.path_join(id + ".png")
	var thumb := dir.path_join(id + "_min.png")
	if image.save_png(full) != OK:
		last_error = "No se pudo guardar la foto."
		return ""
	var small := image.duplicate() as Image
	var scale := minf(float(THUMB_SIZE.x) / image.get_width(), float(THUMB_SIZE.y) / image.get_height())
	small.resize(maxi(1, roundi(image.get_width() * scale)), maxi(1, roundi(image.get_height() * scale)),
		Image.INTERPOLATE_BILINEAR)
	small.save_png(thumb)
	entries[id] = {
		"id": id, "titulo": OutfitLibrary.clean_name(str(meta.get("titulo", "")), "Foto %d" % (entries.size() + 1)),
		"imagen": full, "miniatura": thumb, "prendas": meta.get("prendas", {}).duplicate(),
		"pose": str(meta.get("pose", "")), "escenario": str(meta.get("escenario", "")),
		"era": str(meta.get("era", "")), "creado": now,
	}
	changed.emit()
	return id


func delete(id: String) -> bool:
	if not entries.has(id):
		return false
	for key in ["imagen", "miniatura"]:
		var path: String = entries[id][key]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	entries.erase(id)
	changed.emit()
	return true


func load_image(id: String, thumbnail: bool = true) -> Image:
	if not entries.has(id):
		return null
	var path: String = entries[id]["miniatura" if thumbnail else "imagen"]
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(path)


func sorted() -> Array:
	var list := entries.values()
	list.sort_custom(func(a, b): return a["creado"] > b["creado"])
	return list


func to_dict() -> Dictionary:
	return {"fotos": entries.duplicate(true), "contador": _counter}


## Restaura la galería y descarta las entradas cuyos archivos ya no existen.
func load_dict(d: Dictionary) -> void:
	entries.clear()
	_counter = int(d.get("contador", 0))
	var saved: Dictionary = d.get("fotos", {})
	for id in saved:
		if FileAccess.file_exists(saved[id].get("imagen", "")):
			entries[id] = saved[id]
	changed.emit()
