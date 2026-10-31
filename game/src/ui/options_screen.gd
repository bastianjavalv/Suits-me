extends Screen
## Opciones: legibilidad, controles (con reasignación), gráficos, copias de seguridad, colección
## completa y créditos.

var _game: Node
var _first: Control
var _body: VBoxContainer
var _waiting_action := ""
var _waiting_button: Button

const TEXT_SCALES := [[1.0, "100 %"], [1.15, "115 %"], [1.3, "130 %"]]
const LAYOUTS := [["auto", "Automática"], ["nintendo", "Nintendo (A a la derecha)"], ["xbox", "Xbox (A abajo)"]]
const PROFILES := [["auto", "Automático"], ["sobremesa", "Sobremesa (1920×1080)"], ["portatil", "Portátil (1280×720)"]]
const SENS := [[0.5, "Baja"], [1.0, "Normal"], [1.5, "Alta"], [2.0, "Muy alta"]]


func build(_args: Dictionary) -> void:
	_game = app.get_node("/root/Game")
	var panel := UiKit.panel(24)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120
	panel.offset_right = -120
	panel.offset_top = 40
	panel.offset_bottom = -90
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := UiKit.vbox(10)
	panel.add_child(v)
	v.add_child(UiKit.title("Opciones", 40))
	_body = UiKit.vbox(10)
	v.add_child(UiKit.scroll(_body))
	_rebuild()


func _rebuild() -> void:
	UiKit.clear(_body)
	var s: Settings = _game.settings
	_body.add_child(UiKit.label("Legibilidad y controles", UiTheme.SIZE_BODY, UiTheme.GOLD))
	_first = _choice("Tamaño del texto", TEXT_SCALES, s.get_value("escala_texto"), func(v): s.set_value("escala_texto", v))
	_choice("Disposición de botones", LAYOUTS, s.get_value("disposicion_botones"), func(v): s.set_value("disposicion_botones", v))
	_choice("Sensibilidad de giro", SENS, s.get_value("sensibilidad_rotacion"), func(v): s.set_value("sensibilidad_rotacion", v))
	_toggle("Invertir el giro del maniquí", s.get_value("invertir_rotacion"), func(v): s.set_value("invertir_rotacion", v))
	_toggle("Vibración", s.get_value("vibracion"), func(v): s.set_value("vibracion", v))
	_body.add_child(UiKit.label("Gráficos", UiTheme.SIZE_BODY, UiTheme.GOLD))
	_choice("Perfil gráfico", PROFILES, s.get_value("perfil_calidad"), func(v): s.set_value("perfil_calidad", v))
	_toggle("Mostrar rendimiento (FPS)", s.get_value("mostrar_rendimiento"), func(v): s.set_value("mostrar_rendimiento", v))
	_body.add_child(UiKit.label("Reasignar controles", UiTheme.SIZE_BODY, UiTheme.GOLD))
	var actions := ["ui_accept", "ui_cancel", "opciones_prenda", "cambiar_categoria", "seccion_anterior", "seccion_siguiente",
		"zoom_acercar", "zoom_alejar", "pausa", "inventario"]
	for action in actions:
		var label: String = InputBindings.ACTIONS.get(action, {"ui_accept": "Confirmar", "ui_cancel": "Cancelar"}.get(action, action))
		var b := UiKit.button("%s: %s" % [label, _binding_text(action)], func() -> void: _start_rebind(action), Vector2(0, 52))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.set_meta("accion", action)
		_body.add_child(b)
	_body.add_child(UiKit.button("Restablecer controles", _reset_controls, Vector2(0, 52)))
	_body.add_child(UiKit.label("Partida", UiTheme.SIZE_BODY, UiTheme.GOLD))
	_body.add_child(UiKit.button("Añadir toda la colección a mi armario", _acquire_all, Vector2(0, 52)))
	_body.add_child(UiKit.label("Copias de seguridad automáticas (de la más reciente a la más antigua):", UiTheme.SIZE_SMALL, UiTheme.MUTED))
	var backups: PackedStringArray = _game.save_system.list_backups()
	if backups.is_empty():
		_body.add_child(UiKit.label("Todavía no hay copias.", UiTheme.SIZE_SMALL, UiTheme.MUTED))
	for i in range(backups.size() - 1, -1, -1):
		var name: String = backups[i]
		_body.add_child(UiKit.button("Restaurar %s" % name.trim_prefix("partida_").trim_suffix(".json"), func() -> void: _restore(name), Vector2(0, 48)))
	_body.add_child(UiKit.label("Acerca de", UiTheme.SIZE_BODY, UiTheme.GOLD))
	_body.add_child(UiKit.label("Atelier de las Eras es un proyecto original. No está afiliado a SUITSME ni a Zirafit Limited y no usa sus recursos. Motor: Godot Engine (licencia MIT). Tipografías: Playfair Display y Jost (SIL Open Font License 1.1). La enciclopedia cita sus fuentes en cada ficha.",
		UiTheme.SIZE_SMALL, UiTheme.MUTED, true))


func _choice(title: String, options: Array, current: Variant, on_change: Callable) -> OptionButton:
	var row := UiKit.hbox(12)
	_body.add_child(row)
	var l := UiKit.label(title, UiTheme.SIZE_BODY)
	l.custom_minimum_size = Vector2(460, 0)
	row.add_child(l)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_ALL
	for i in options.size():
		ob.add_item(options[i][1], i)
		if options[i][0] == current:
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void: on_change.call(options[i][0]))
	row.add_child(ob)
	return ob


func _toggle(title: String, value: bool, on_change: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = title
	cb.button_pressed = value
	cb.focus_mode = Control.FOCUS_ALL
	cb.toggled.connect(func(v: bool) -> void: on_change.call(v))
	_body.add_child(cb)
	return cb


func _binding_text(action: String) -> String:
	var names: Array[String] = []
	for ev in InputMap.action_get_events(action):
		names.append(ev.as_text().replace(" (Physical)", ""))
	return ", ".join(names.slice(0, 3))


func _start_rebind(action: String) -> void:
	_waiting_action = action
	for c in _body.get_children():
		if c is Button and c.get_meta("accion", "") == action:
			_waiting_button = c
			c.text = "Pulsa la nueva tecla o botón para «%s»…" % action
	app.toast("Pulsa la nueva tecla o botón (Esc para cancelar).", 2.5)


func _input(event: InputEvent) -> void:
	if _waiting_action.is_empty() or not visible:
		return
	if not (event is InputEventKey or event is InputEventJoypadButton) or not event.is_pressed():
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		_waiting_action = ""
		_rebuild()
		return
	var controls := app.get_node_or_null("/root/Controls")
	if controls != null:
		controls.rebind(_waiting_action, event)
		_game.settings.set_value("controles", controls.overrides())
	_waiting_action = ""
	_rebuild()
	app.toast("Control reasignado.")


func _reset_controls() -> void:
	var controls := app.get_node_or_null("/root/Controls")
	if controls != null:
		controls.reset_bindings()
	_game.settings.set_value("controles", {})
	_rebuild()


func _acquire_all() -> void:
	var n: int = _game.inventory.acquire_all(_game.catalog, _game.economy, _game.now())
	app.toast("%d prendas añadidas a tu armario (saldo ilimitado)." % n)


func _restore(name: String) -> void:
	var path: String = _game.save_system.backup_dir.path_join(name)
	if _game.save_system.import_copy(path, _game.now()):
		_game.load_save()
		app.toast("Copia restaurada.")
		app.go_home()
	else:
		app.toast("No se pudo restaurar: %s" % _game.save_system.last_error)


func default_focus() -> Control:
	return _first
