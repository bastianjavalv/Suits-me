class_name SaveSystem
extends RefCounted
## Guardado local robusto:
##  * escritura atómica (archivo temporal verificado y renombrado),
##  * suma SHA-256 del contenido para detectar corrupción,
##  * copias de seguridad rotativas y recuperación automática,
##  * migraciones de formato por versión.
##
## Formato del archivo: una línea de cabecera JSON y, a continuación, el contenido JSON.
##   {"formato": "...", "version": N, "guardado": t, "sha256": "..."}
##   { ...datos de la partida... }

const FORMAT := "atelier-eras-partida"
const CURRENT_VERSION := 1
const MAX_BACKUPS := 10
const BACKUP_INTERVAL := 300.0  ## segundos mínimos entre copias automáticas

var base_dir: String
var main_path: String
var temp_path: String
var backup_dir: String
var current_version := CURRENT_VERSION
var migrations: Dictionary = {}  ## versión origen -> Callable(datos: Dictionary) -> Dictionary
var last_error := ""
var last_notice := ""  ## mensaje para el jugador (p. ej., recuperación desde una copia)
var _last_backup_time := -INF
var _backup_counter := 0


func _init(dir: String = "user://partida") -> void:
	base_dir = dir
	main_path = dir.path_join("partida.json")
	temp_path = dir.path_join("partida.json.tmp")
	backup_dir = dir.path_join("copias")


func _ensure_dirs() -> bool:
	for d in [base_dir, backup_dir]:
		if not DirAccess.dir_exists_absolute(d):
			if DirAccess.make_dir_recursive_absolute(d) != OK:
				last_error = "No se pudo crear la carpeta %s" % d
				return false
	return true


static func encode(data: Dictionary, now: float, version: int) -> String:
	var payload := JSON.stringify(data, "\t", true)
	var header := {"formato": FORMAT, "version": version, "guardado": now, "sha256": payload.sha256_text()}
	return JSON.stringify(header, "", true) + "\n" + payload


## Devuelve {"ok", "datos", "version", "guardado", "error"}.
static func decode(text: String) -> Dictionary:
	var nl := text.find("\n")
	if nl < 0:
		return {"ok": false, "error": "falta la cabecera"}
	var header_r := JsonUtil.parse_text(text.substr(0, nl), "cabecera")
	if not header_r.ok or typeof(header_r.data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "cabecera ilegible"}
	var header: Dictionary = header_r.data
	if header.get("formato") != FORMAT:
		return {"ok": false, "error": "formato desconocido"}
	var payload := text.substr(nl + 1)
	if payload.sha256_text() != str(header.get("sha256", "")):
		return {"ok": false, "error": "la suma SHA-256 no coincide (archivo dañado o incompleto)"}
	var body := JsonUtil.parse_text(payload, "partida")
	if not body.ok or typeof(body.data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "contenido ilegible"}
	return {"ok": true, "datos": body.data, "version": int(header.get("version", 0)),
		"guardado": float(header.get("guardado", 0.0)), "error": ""}


static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "no existe"}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "no se pudo abrir (error %d)" % FileAccess.get_open_error()}
	var text := f.get_as_text()
	f.close()
	return decode(text)


## Guarda la partida. `force_backup` crea una copia aunque no haya pasado el intervalo.
func save(data: Dictionary, now: float, force_backup: bool = false) -> bool:
	last_error = ""
	if not _ensure_dirs():
		return false
	var text := encode(data, now, current_version)
	if JsonUtil.write_text(temp_path, text) != OK:
		last_error = "No se pudo escribir el archivo temporal"
		return false
	var check := read_file(temp_path)
	if not check.ok:
		last_error = "La verificación del archivo temporal falló: %s" % check.error
		return false
	if FileAccess.file_exists(main_path) and (force_backup or now - _last_backup_time >= BACKUP_INTERVAL):
		_make_backup(now)
	if DirAccess.rename_absolute(temp_path, main_path) != OK:
		# Algunos sistemas no reemplazan al renombrar: se borra el destino y se reintenta.
		DirAccess.remove_absolute(main_path)
		if DirAccess.rename_absolute(temp_path, main_path) != OK:
			last_error = "No se pudo reemplazar el archivo de partida"
			return false
	return true


func _make_backup(now: float) -> void:
	var r := read_file(main_path)
	if not r.ok:
		return  # No se copian archivos dañados.
	_backup_counter += 1
	var dt := Time.get_datetime_dict_from_unix_time(int(now))
	var name := "partida_%04d%02d%02d_%02d%02d%02d_%03d.json" % [dt.year, dt.month, dt.day, dt.hour, dt.minute,
		dt.second, _backup_counter % 1000]
	var src := FileAccess.get_file_as_string(main_path)
	if JsonUtil.write_text(backup_dir.path_join(name), src) == OK:
		_last_backup_time = now
	_prune_backups()


func _prune_backups() -> void:
	var files := list_backups()
	while files.size() > MAX_BACKUPS:
		DirAccess.remove_absolute(backup_dir.path_join(files[0]))
		files.remove_at(0)


## Copias de seguridad, de la más antigua a la más reciente.
func list_backups() -> PackedStringArray:
	if not DirAccess.dir_exists_absolute(backup_dir):
		return PackedStringArray()
	var files := PackedStringArray()
	for f in DirAccess.get_files_at(backup_dir):
		if f.begins_with("partida_") and f.ends_with(".json"):
			files.append(f)
	files.sort()
	return files


func has_save() -> bool:
	return FileAccess.file_exists(main_path) or FileAccess.file_exists(temp_path) or not list_backups().is_empty()


## Carga la partida. Devuelve {"ok", "datos", "origen", "aviso"}; origen es
## "principal", "temporal", "copia" o "nueva".
func load_game() -> Dictionary:
	last_notice = ""
	var candidates: Array = []
	if FileAccess.file_exists(main_path):
		candidates.append(["principal", main_path])
	if FileAccess.file_exists(temp_path):
		candidates.append(["temporal", temp_path])
	var backups := list_backups()
	for i in range(backups.size() - 1, -1, -1):
		candidates.append(["copia", backup_dir.path_join(backups[i])])
	var failures: Array[String] = []
	var best: Dictionary = {}
	var best_origin := ""
	for c in candidates:
		if c[0] == "copia" and not best.is_empty():
			break  # Las copias solo se leen si no hay una partida válida más reciente.
		var r := read_file(c[1])
		if not r.ok:
			failures.append("%s: %s" % [c[1].get_file(), r.error])
			continue
		# El temporal solo se usa si es más nuevo que el principal o si el principal falló.
		if best.is_empty() or (c[0] == "temporal" and r.guardado > best.guardado):
			best = r
			best_origin = c[0]
	if best.is_empty():
		if not failures.is_empty():
			_quarantine_main()
			last_notice = "No se pudo leer la partida guardada ni sus copias. Se empezó una partida nueva; " + \
				"el archivo dañado se conservó como partida.danada.json."
		return {"ok": true, "datos": {}, "origen": "nueva", "aviso": last_notice}
	var data := _migrate(best.datos, best.version)
	if data.is_empty() and not best.datos.is_empty():
		return {"ok": false, "datos": {}, "origen": best_origin, "aviso": last_error}
	if best_origin == "copia":
		last_notice = "La partida principal estaba dañada. Se recuperó la copia de seguridad más reciente."
	elif best_origin == "temporal":
		last_notice = "Se recuperaron los cambios del último guardado interrumpido."
	return {"ok": true, "datos": data, "origen": best_origin, "aviso": last_notice}


func _quarantine_main() -> void:
	if FileAccess.file_exists(main_path):
		var dest := base_dir.path_join("partida.danada.json")
		DirAccess.remove_absolute(dest)
		DirAccess.rename_absolute(main_path, dest)


func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	if from_version > current_version:
		last_error = "La partida es de una versión más nueva del juego (%d > %d)." % [from_version, current_version]
		return {}
	var d := data
	var v := from_version
	while v < current_version:
		if not migrations.has(v):
			last_error = "No hay migración desde la versión %d." % v
			return {}
		d = migrations[v].call(d)
		v += 1
	return d


## Exporta una copia legible a una ruta elegida por el jugador (solo PC).
func export_copy(dest_path: String) -> bool:
	if not FileAccess.file_exists(main_path):
		return false
	return JsonUtil.write_text(dest_path, FileAccess.get_file_as_string(main_path)) == OK


## Valida e importa una copia; la partida actual se respalda antes de reemplazarla.
func import_copy(src_path: String, now: float) -> bool:
	var r := read_file(src_path)
	if not r.ok:
		last_error = "La copia no es válida: %s" % r.error
		return false
	if FileAccess.file_exists(main_path):
		_make_backup(now)
	return save(r.datos, now)
