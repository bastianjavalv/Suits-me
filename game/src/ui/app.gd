extends Node
## Escena principal: mundo 3D (escenario, maniquí y cámara), interfaz, pila de pantallas,
## avisos, indicaciones de botones, gestos táctiles, perfiles de calidad y resolución dinámica.

const SCREENS := {
	"menu": preload("res://src/ui/menu_screen.gd"),
	"eras": preload("res://src/ui/eras_screen.gd"),
	"vestidor": preload("res://src/ui/dressing_screen.gd"),
	"ficha": preload("res://src/ui/sheet_screen.gd"),
	"desafios": preload("res://src/ui/challenges_screen.gd"),
	"resultado": preload("res://src/ui/result_screen.gd"),
	"looks": preload("res://src/ui/looks_screen.gd"),
	"galeria": preload("res://src/ui/gallery_screen.gd"),
	"enciclopedia": preload("res://src/ui/encyclopedia_screen.gd"),
	"opciones": preload("res://src/ui/options_screen.gd"),
	"pausa": preload("res://src/ui/pause_screen.gd"),
	"filtros": preload("res://src/ui/filter_screen.gd"),
}

var world: Node3D
var stage_root: Node3D
var view: OutfitView
var rig: CameraRig
var ui: CanvasLayer
var host: Control
var prompt_bar: HBoxContainer
var toast_box: VBoxContainer
var perf_label: Label
var stack: Array = []
var quality := QualityProfiles.new()
var dyn := DynamicResolution.new()
var gestures := GestureRecognizer.new()
var stage_builder: StageBuilder
var current_stage := ""
var current_pose := "erguida"
var profile_mode := "sobremesa"
var profile: Dictionary = {}
var _perf_t := 0.0
var _mouse_drag := false
var photo_mode := false
## Precompilación de sombreadores en curso (solo con GLES3; ver _prepare_graphics).
var preparing := false
var loading: LoadingOverlay

signal preparation_finished


func _ready() -> void:
	var game := get_node("/root/Game")
	if not game._initialized:
		game.initialize()
	quality.load_file("res://data/config/calidad.json")
	_build_world()
	_build_ui()
	var controls := get_node_or_null("/root/Controls")
	if controls != null:
		controls.configure(str(game.settings.get_value("disposicion_botones")), game.settings.get_value("controles"))
		controls.input_mode_changed.connect(func(_m: String) -> void: update_prompts())
	var platform := get_node_or_null("/root/Platform")
	if platform != null:
		platform.operation_mode_changed.connect(func(_m: String) -> void: apply_quality())
	game.settings.changed.connect(_on_setting_changed)
	apply_quality()
	set_stage("estudio_neutro")
	view.show_outfit(game.outfit.to_dict())
	game.outfit.changed.connect(func() -> void: view.show_outfit(game.outfit.to_dict()))
	if needs_shader_warmup():
		_prepare_graphics()
	else:
		_finish_startup()


func _finish_startup() -> void:
	var game := get_node("/root/Game")
	push("menu")
	for n in game.take_notices():
		toast(n, 6.0)


## Con GLES3 (el renderizador del NRO de Switch) cada sombreador se compila la primera vez que se
## dibuja y Mesa no lo guarda en caché: sin precompilarlos, el arranque queda en negro y el juego se
## congela al abrir cada época.
static func needs_shader_warmup() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility" and DisplayServer.get_name() != "headless"


## Pasos de la precompilación: cada escenario con el conjunto de muestra de una época, hasta recorrer
## todos los escenarios y todas las épocas. Solo se dibujan; la partida no cambia.
func warmup_steps() -> Array[Dictionary]:
	var game := get_node("/root/Game")
	var stage_ids: Array = game.stages.keys()
	var era_ids: Array = game.eras.map(func(e): return e["id"])
	var steps: Array[Dictionary] = []
	for i in maxi(stage_ids.size(), era_ids.size()):
		var era: String = era_ids[i % era_ids.size()] if not era_ids.is_empty() else ""
		var outfit := {}
		for id in game.catalog.by_era.get(era, []):
			var cat: String = game.catalog.get_item(id)["categoria"]
			if not outfit.has(cat):
				outfit[cat] = id
		steps.append({"escenario": stage_ids[i % stage_ids.size()] if not stage_ids.is_empty() else "",
			"era": era, "conjunto": outfit})
	return steps


func _prepare_graphics() -> void:
	var game := get_node("/root/Game")
	preparing = true
	loading = LoadingOverlay.new()
	ui.add_child(loading)
	# El primer cuadro solo lleva la pantalla de carga, así aparece enseguida.
	world.visible = false
	await get_tree().process_frame
	world.visible = true
	var steps := warmup_steps()
	for i in steps.size():
		var step: Dictionary = steps[i]
		set_stage(step["escenario"])
		view.show_outfit(step["conjunto"])
		var stage_name: String = game.stages.get(step["escenario"], {}).get("nombre", "")
		loading.set_progress(float(i) / steps.size(), "%s · %s" % [stage_name, game.era_names.get(step["era"], "")])
		await get_tree().process_frame
		await get_tree().process_frame
	loading.set_progress(1.0)
	set_stage("estudio_neutro")
	view.show_outfit(game.outfit.to_dict())
	await get_tree().process_frame
	# Los cuadros lentos de la compilación no deben bajar la resolución dinámica.
	dyn = DynamicResolution.new()
	apply_quality()
	loading.queue_free()
	loading = null
	preparing = false
	_finish_startup()
	preparation_finished.emit()


# ---------------------------------------------------------------------------
# Mundo 3D
# ---------------------------------------------------------------------------

func _build_world() -> void:
	var game := get_node("/root/Game")
	world = Node3D.new()
	world.name = "Mundo"
	add_child(world)
	stage_builder = StageBuilder.new(FabricLibrary.new(game.fabrics))
	view = OutfitView.new()
	view.name = "Conjunto"
	world.add_child(view)
	view.setup(game.catalog, game.fabrics, quality.get_profile("sobremesa"))
	rig = CameraRig.new()
	rig.name = "Camara"
	world.add_child(rig)


func set_stage(id: String) -> void:
	var game := get_node("/root/Game")
	if id == current_stage or not game.stages.has(id):
		return
	current_stage = id
	if stage_root != null:
		stage_root.queue_free()
	stage_builder.shadow_quality = int(profile.get("sombra_tamano", 2048)) > 0
	stage_root = stage_builder.build(game.stages[id])
	world.add_child(stage_root)


func set_pose(id: String) -> void:
	var game := get_node("/root/Game")
	for p in game.poses:
		if p["id"] == id:
			current_pose = id
			view.apply_pose(Mannequin.pose_from_json(p))
			return


func next_pose() -> String:
	var game := get_node("/root/Game")
	var ids: Array = game.poses.map(func(p): return p["id"])
	var i := (ids.find(current_pose) + 1) % ids.size()
	set_pose(ids[i])
	return game.poses[i]["nombre"]


# ---------------------------------------------------------------------------
# Interfaz
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var game := get_node("/root/Game")
	ui = CanvasLayer.new()
	ui.name = "Interfaz"
	add_child(ui)
	host = Control.new()
	host.name = "Pantallas"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.theme = UiTheme.make(float(game.settings.get_value("escala_texto")))
	ui.add_child(host)
	var bottom := MarginContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -64
	bottom.add_theme_constant_override("margin_left", 32)
	bottom.add_theme_constant_override("margin_bottom", 14)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bottom)
	prompt_bar = UiKit.hbox(26)
	prompt_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(prompt_bar)
	# Avisos abajo, sobre la barra de botones, para no tapar títulos ni el maniquí.
	toast_box = UiKit.vbox(8)
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toast_box.offset_left = -380
	toast_box.offset_right = 380
	toast_box.offset_top = -300
	toast_box.offset_bottom = -78
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(toast_box)
	perf_label = UiKit.label("", UiTheme.SIZE_SMALL, UiTheme.MUTED)
	perf_label.position = Vector2(24, 18)
	perf_label.visible = false
	host.add_child(perf_label)


func top() -> Screen:
	return stack[-1] if not stack.is_empty() else null


func push(name: String, args: Dictionary = {}) -> Screen:
	if top() != null:
		top().visible = false
	var s: Screen = SCREENS[name].new()
	s.name = "Pantalla_" + name
	host.add_child(s)
	host.move_child(s, host.get_child_count() - 4)
	s.setup(self, args)
	stack.append(s)
	_after_change()
	return s


func pop() -> void:
	if stack.size() <= 1:
		return
	var s: Screen = stack.pop_back()
	s.queue_free()
	top().visible = true
	top().refresh()
	_after_change()


## Vuelve al menú cerrando todas las pantallas.
func go_home() -> void:
	while stack.size() > 1:
		var s: Screen = stack.pop_back()
		s.queue_free()
	top().visible = true
	top().refresh()
	_after_change()


func _after_change() -> void:
	var s := top()
	world.visible = not s.opaque
	s.on_shown()
	update_prompts()


func update_prompts() -> void:
	UiKit.clear(prompt_bar)
	var s := top()
	if s == null:
		return
	var controls := get_node_or_null("/root/Controls")
	var touch: bool = controls != null and controls.is_touch()
	prompt_bar.visible = not touch and not photo_mode
	for p in s.prompts():
		var glyph: String = controls.glyph(p[0]) if controls != null else ""
		if glyph.is_empty():
			continue
		var chip := UiKit.hbox(8)
		var g := UiKit.label(" %s " % glyph, UiTheme.SIZE_SMALL, Color(0.08, 0.07, 0.08))
		var sb := UiTheme.box(UiTheme.GOLD, UiTheme.GOLD, 0, 4)
		sb.set_corner_radius_all(14)
		g.add_theme_stylebox_override("normal", sb)
		chip.add_child(g)
		chip.add_child(UiKit.label(p[1], UiTheme.SIZE_SMALL, UiTheme.IVORY))
		prompt_bar.add_child(chip)


func toast(text: String, seconds: float = 3.0) -> void:
	if text.is_empty():
		return
	while toast_box.get_child_count() >= 3:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var p := UiKit.panel(12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(text, UiTheme.SIZE_SMALL, UiTheme.IVORY, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	toast_box.add_child(p)
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_interval(seconds)
		tw.tween_property(p, "modulate:a", 0.0, 0.5)
		tw.tween_callback(p.queue_free)


func vibrate(strength: float = 0.3, seconds: float = 0.08) -> void:
	var game := get_node("/root/Game")
	if game.settings.get_value("vibracion"):
		for pad in Input.get_connected_joypads():
			Input.start_joy_vibration(pad, strength * 0.5, strength, seconds)


# ---------------------------------------------------------------------------
# Calidad y rendimiento
# ---------------------------------------------------------------------------

func apply_quality() -> void:
	var game := get_node("/root/Game")
	var platform := get_node_or_null("/root/Platform")
	var detected: String = platform.operation_mode if platform != null else "sobremesa"
	profile_mode = QualityProfiles.resolve_mode(str(game.settings.get_value("perfil_calidad")), detected)
	profile = quality.get_profile(profile_mode)
	QualityProfiles.apply(get_viewport(), profile)
	dyn.configure(float(profile.get("fps_objetivo", 60)), float(profile.get("escala_min", 0.8)), float(profile.get("escala_max", 1.0)))
	view.set_quality(profile)


func _on_setting_changed(key: String) -> void:
	var game := get_node("/root/Game")
	if key == "perfil_calidad" or key == "":
		apply_quality()
	if key == "escala_texto" or key == "":
		host.theme = UiTheme.make(float(game.settings.get_value("escala_texto")))
	if key == "disposicion_botones" or key == "controles" or key == "":
		var controls := get_node_or_null("/root/Controls")
		if controls != null:
			controls.configure(str(game.settings.get_value("disposicion_botones")), game.settings.get_value("controles"))
			update_prompts()


func _process(delta: float) -> void:
	var game := get_node("/root/Game")
	if top() != null and top().allows_camera:
		_camera_input(delta)
	var scale := dyn.push(delta * 1000.0, delta)
	get_viewport().scaling_3d_scale = scale
	_perf_t += delta
	if _perf_t >= 0.5:
		_perf_t = 0.0
		perf_label.visible = bool(game.settings.get_value("mostrar_rendimiento"))
		if perf_label.visible:
			perf_label.text = "%d FPS · %.1f ms · %d llamadas · %dk triángulos · escala 3D %.2f · %s" % [
				Engine.get_frames_per_second(), dyn.average_ms,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0), scale,
				Platform.MODE_NAMES.get(profile_mode, profile_mode) if get_node_or_null("/root/Platform") != null else profile_mode]


func _camera_input(delta: float) -> void:
	var game := get_node("/root/Game")
	var controls := get_node_or_null("/root/Controls")
	var sens := float(game.settings.get_value("sensibilidad_rotacion"))
	var invert := -1.0 if game.settings.get_value("invertir_rotacion") else 1.0
	var rot := Input.get_axis("rotar_izquierda", "rotar_derecha")
	var tilt := Input.get_axis("inclinar_arriba", "inclinar_abajo")
	if controls != null and controls.stick_rotates:
		rot += Input.get_axis("ui_left", "ui_right")
		tilt += Input.get_axis("ui_up", "ui_down")
	view.rotate_by(rot * 160.0 * sens * invert * delta)
	rig.pan_by(-tilt * 1.4 * delta)
	var z := Input.get_axis("zoom_alejar", "zoom_acercar")
	rig.zoom_by(z * 0.9 * delta)


func _unhandled_input(event: InputEvent) -> void:
	var s := top()
	if s == null:
		return
	if event.is_action_pressed("ui_cancel"):
		if photo_mode:
			end_photo_mode()
		elif not s.on_cancel():
			pop()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pausa") and not (s.get_script() == SCREENS["pausa"]):
		push("pausa")
		get_viewport().set_input_as_handled()
		return
	for action in ["opciones_prenda", "cambiar_categoria", "seccion_anterior", "seccion_siguiente", "inventario"]:
		if event.is_action_pressed(action) and s.on_action(action):
			get_viewport().set_input_as_handled()
			return
	if not s.allows_camera:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		_mouse_drag = event.pressed
	elif event is InputEventMouseMotion and _mouse_drag and event.device != InputEvent.DEVICE_ID_EMULATION:
		view.rotate_by(event.relative.x * 0.4)
		rig.pan_by(-event.relative.y * 0.004)
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var g := gestures.feed(event, Time.get_ticks_msec() / 1000.0)
		view.rotate_by(g["rotar"].x * 0.35)
		rig.pan_by(-g["rotar"].y * 0.004)
		if g["zoom"] != 1.0:
			rig.zoom_by((g["zoom"] - 1.0) * 1.2)
		if g["doble_toque"]:
			rig.reset()


# ---------------------------------------------------------------------------
# Fotos
# ---------------------------------------------------------------------------

func start_photo_mode() -> void:
	photo_mode = true
	host.visible = false
	toast("Modo foto: A para disparar, B para salir.")


func end_photo_mode() -> void:
	photo_mode = false
	host.visible = true
	update_prompts()


func take_photo() -> String:
	var game := get_node("/root/Game")
	var was_visible := host.visible
	host.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	host.visible = was_visible
	var era := ""
	if game.stages.has(current_stage):
		era = str(game.stages[current_stage].get("era", ""))
	var id: String = game.gallery.add_photo(img, {"prendas": game.outfit.to_dict(), "pose": current_pose,
		"escenario": current_stage, "era": era, "titulo": ""}, game.now())
	if id.is_empty():
		toast("No se pudo guardar la foto: %s" % game.gallery.last_error)
	else:
		game.library.record_history(game.outfit.to_dict(), "foto", game.now())
		toast("Foto guardada en la galería.")
		vibrate(0.4, 0.1)
	return id


func _input(event: InputEvent) -> void:
	if photo_mode and event.is_action_pressed("ui_accept"):
		take_photo()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var game := get_node_or_null("/root/Game")
		if game != null and game.is_dirty():
			game.save_now()
