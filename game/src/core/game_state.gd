extends Node
## Estado global del juego (autoload "Game"): datos, partida local, autoguardado y recuperación.
## Todo funciona sin conexión: no hay cuentas, servidores, anuncios ni compras reales.

signal loaded
signal notice(text: String)
signal saved(ok: bool)

var data_dir := "res://data"
var save_dir := "user://partida"
var gallery_dir := "user://galeria"

var catalog: Catalog
var encyclopedia: Encyclopedia
var challenges: ChallengeBook
var eras: Array = []
var era_by_id: Dictionary = {}
var era_names: Dictionary = {}
var era_order: Dictionary = {}
var fabrics: Dictionary = {}
var stages: Dictionary = {}
var poses: Array = []
var economy_config: Dictionary = {}
var data_errors: Array[String] = []

var economy := Economy.new()
var inventory := Inventory.new()
var library := OutfitLibrary.new()
var outfit := Outfit.new()
var settings := Settings.new()
var gallery: Gallery
var save_system: SaveSystem
var active_draft_id := ""
var active_context := "vestidor"  ## "vestidor" o "desafio:<id>"
var created_at := 0.0
var pending_notices: Array[String] = []

var clock: Callable = func() -> float: return Time.get_unix_time_from_system()
var autosave_delay := 1.5
var _dirty := false
var _timer: Timer
var _initialized := false
var _loading := false


func _ready() -> void:
	# Las pruebas crean sus propias instancias con datos y carpetas temporales: el autoload no
	# debe tocar la partida real del jugador mientras se ejecutan.
	if not _initialized and not _is_test_run():
		initialize()


static func _is_test_run() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.ends_with("tests/run_tests.gd") or arg.begins_with("res://tools/"):
			return true
	return false


func initialize(p_data_dir: String = data_dir, p_save_dir: String = save_dir, p_gallery_dir: String = gallery_dir) -> void:
	data_dir = p_data_dir
	save_dir = p_save_dir
	gallery_dir = p_gallery_dir
	_initialized = true
	load_data()
	save_system = SaveSystem.new(save_dir)
	gallery = Gallery.new(gallery_dir)
	_setup_timer()
	_connect_signals()
	load_save()
	loaded.emit()


func now() -> float:
	return clock.call()


# ---------------------------------------------------------------------------
# Datos del juego
# ---------------------------------------------------------------------------

func _data_path(rel: String) -> String:
	return data_dir.path_join(rel)


func load_data() -> void:
	data_errors.clear()
	var index := JsonUtil.load_object(_data_path("indice.json"), data_errors)
	eras = JsonUtil.load_object(_data_path(index.get("eras", "eras.json")), data_errors).get("eras", [])
	era_by_id.clear()
	era_names.clear()
	era_order.clear()
	for i in eras.size():
		var e: Dictionary = eras[i]
		era_by_id[e["id"]] = e
		era_names[e["id"]] = e.get("titulo", e["id"])
		era_order[e["id"]] = i
	var fabric_doc := JsonUtil.load_object(_data_path(index.get("tejidos", "tejidos.json")), data_errors)
	fabrics = fabric_doc.get("tejidos", {})
	var stage_doc := JsonUtil.load_object(_data_path(index.get("escenarios", "escenarios.json")), data_errors)
	stages.clear()
	for s in stage_doc.get("escenarios", []):
		stages[s["id"]] = s
	poses = JsonUtil.load_object(_data_path(index.get("poses", "poses.json")), data_errors).get("poses", [])

	catalog = Catalog.new()
	catalog.known_eras = era_by_id
	catalog.known_fabrics = fabrics
	catalog.load_files(_paths(index.get("prendas", [])))

	encyclopedia = Encyclopedia.new()
	encyclopedia.load_sources(_data_path(index.get("fuentes", "enciclopedia/fuentes.json")))
	encyclopedia.load_entries(_paths(index.get("enciclopedia", [])))
	encyclopedia.check_references()

	challenges = ChallengeBook.new()
	challenges.known_eras = era_by_id
	challenges.known_stages = stages
	challenges.known_fabrics = fabrics
	challenges.load_file(_data_path(index.get("desafios", "desafios.json")))

	economy_config = JsonUtil.load_object(_data_path(index.get("economia", "config/economia.json")), data_errors)

	for id in catalog.order:
		for t in catalog.get_item(id)["tipologias"]:
			if not encyclopedia.has_entry(t):
				data_errors.append("Prenda %s: enlaza una ficha inexistente: %s" % [id, t])
	data_errors.append_array(catalog.errors)
	data_errors.append_array(encyclopedia.errors)
	data_errors.append_array(challenges.errors)
	for err in data_errors:
		push_warning(err)


func _paths(list: Array) -> Array:
	var out: Array = []
	for rel in list:
		out.append(_data_path(rel))
	return out


# ---------------------------------------------------------------------------
# Partida
# ---------------------------------------------------------------------------

func _setup_timer() -> void:
	if _timer != null:
		return
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(func(): save_now())
	add_child(_timer)


func _connect_signals() -> void:
	for emitter in [economy, inventory, library, outfit, settings, challenges, gallery]:
		var sig: Signal = emitter.changed
		if not sig.is_connected(_on_changed):
			sig.connect(_on_changed)


func _on_changed(_arg = null) -> void:
	mark_dirty()


func mark_dirty() -> void:
	if _loading:
		return
	_dirty = true
	if _timer != null and _timer.is_inside_tree():
		_timer.start(autosave_delay)


func is_dirty() -> bool:
	return _dirty


func to_save_dict() -> Dictionary:
	return {
		"economia": economy.to_dict(),
		"inventario": inventory.to_dict(),
		"biblioteca": library.to_dict(),
		"desafios": challenges.to_dict(),
		"galeria": gallery.to_dict(),
		"ajustes": settings.to_dict(),
		"conjunto_actual": outfit.to_dict(),
		"borrador_activo": active_draft_id,
		"contexto": active_context,
		"creada": created_at,
	}


func apply_save_dict(d: Dictionary) -> void:
	economy.load_dict(d.get("economia", {}))
	# El modo de la configuración manda: si el juego se distribuye en modo ilimitado,
	# una partida antigua no puede dejar al jugador sin saldo.
	if str(economy_config.get("modo", "ilimitado")) == "ilimitado":
		economy.unlimited = true
	inventory.load_dict(d.get("inventario", {}), catalog)
	library.load_dict(d.get("biblioteca", {}))
	challenges.load_dict(d.get("desafios", {}))
	gallery.load_dict(d.get("galeria", {}))
	settings.load_dict(d.get("ajustes", {}))
	var dropped := outfit.load_dict(d.get("conjunto_actual", {}), catalog)
	active_draft_id = str(d.get("borrador_activo", ""))
	active_context = str(d.get("contexto", "vestidor"))
	created_at = float(d.get("creada", now()))
	if outfit.count() > 0:
		pending_notices.append("Se recuperó el conjunto en el que estabas trabajando.")
	if not dropped.is_empty():
		pending_notices.append("%d prenda(s) del conjunto ya no existen y se retiraron." % dropped.size())


func new_game() -> void:
	economy.configure(economy_config)
	inventory.load_dict({})
	library.load_dict({})
	challenges.load_dict({})
	gallery.load_dict({})
	settings.reset()
	outfit.clear()
	active_draft_id = ""
	active_context = "vestidor"
	created_at = now()
	var start := str(economy_config.get("inventario_inicial", "basico"))
	for id in catalog.order:
		if start == "todo" or catalog.get_item(id).get("inicial", false):
			inventory.acquire(catalog, economy, id, created_at)
	economy.ledger.clear()


func load_save() -> void:
	_loading = true
	pending_notices.clear()
	var r := save_system.load_game()
	if not r.ok:
		pending_notices.append(r.aviso)
		new_game()
	elif r.origen == "nueva" or r.datos.is_empty():
		new_game()
	else:
		apply_save_dict(r.datos)
	if not str(r.get("aviso", "")).is_empty() and not pending_notices.has(r.aviso):
		pending_notices.insert(0, r.aviso)
	_loading = false
	if r.origen == "nueva":
		save_now(true)


## Mensajes pendientes para mostrar al jugador (recuperaciones, avisos de datos).
func take_notices() -> Array[String]:
	var out := pending_notices.duplicate()
	pending_notices.clear()
	return out


func save_now(force_backup: bool = false) -> bool:
	if save_system == null:
		return false
	var ok := save_system.save(to_save_dict(), now(), force_backup)
	if ok:
		_dirty = false
		if _timer != null and _timer.is_inside_tree():
			_timer.stop()
		var platform := get_node_or_null("/root/Platform") if is_inside_tree() else null
		if platform != null:
			platform.commit_save_data()
	else:
		push_error("Error al guardar: %s" % save_system.last_error)
	saved.emit(ok)
	return ok


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _dirty and save_system != null:
			save_now()


# ---------------------------------------------------------------------------
# Acciones de juego
# ---------------------------------------------------------------------------

## Prueba una prenda: si no es del jugador, se adquiere gratis (saldo ilimitado) y se equipa.
func try_on(id: String) -> Dictionary:
	var item := catalog.get_item(id)
	if item.is_empty():
		return {"ok": false, "mensaje": "Prenda desconocida."}
	var msg := ""
	if not inventory.owns(id):
		var res := inventory.acquire(catalog, economy, id, now())
		if res == Inventory.Result.CANNOT_AFFORD:
			return {"ok": false, "mensaje": "Saldo insuficiente."}
		msg = "Añadida a tu armario: %s" % item["nombre"]
	var worn := outfit.toggle(item)
	return {"ok": true, "puesta": worn, "mensaje": msg}


func save_current_look(name: String, tags: Array = []) -> String:
	var challenge := active_context.trim_prefix("desafio:") if active_context.begins_with("desafio:") else ""
	var id := library.save_look(name, outfit.to_dict(), now(), tags, challenge)
	library.record_history(outfit.to_dict(), "look guardado", now(), challenge)
	return id


func save_current_draft() -> String:
	active_draft_id = library.save_draft(outfit.to_dict(), active_context, now(), active_draft_id)
	return active_draft_id


func load_into_outfit(slots: Dictionary) -> Array[String]:
	return outfit.load_dict(slots, catalog)


func submit_challenge(id: String) -> Dictionary:
	var result := challenges.submit(id, outfit.to_dict(), catalog, era_names, now())
	if not result.is_empty():
		library.record_history(outfit.to_dict(), "desafío", now(), id)
		save_now()
	return result
