class_name JsonUtil
extends RefCounted
## Lectura de JSON con mensajes de error legibles.


## Devuelve {"ok": bool, "data": Variant, "error": String}.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": null, "error": "No existe el archivo: %s" % path}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "data": null,
			"error": "No se pudo abrir %s (error %d)" % [path, FileAccess.get_open_error()]}
	var text := file.get_as_text()
	file.close()
	return parse_text(text, path)


static func parse_text(text: String, origin: String = "") -> Dictionary:
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return {"ok": false, "data": null,
			"error": "%s: línea %d: %s" % [origin, json.get_error_line(), json.get_error_message()]}
	return {"ok": true, "data": json.data, "error": ""}


## Lee un JSON que debe ser un objeto; agrega el error a `errors` si falla.
static func load_object(path: String, errors: Array) -> Dictionary:
	var r := load_file(path)
	if not r.ok:
		errors.append(r.error)
		return {}
	if typeof(r.data) != TYPE_DICTIONARY:
		errors.append("%s: se esperaba un objeto JSON" % path)
		return {}
	return r.data


static func write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	var err := file.get_error()
	file.close()
	return err
