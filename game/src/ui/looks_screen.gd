extends Screen
## Mis looks: guardados, borradores, historial de atuendos y papelera recuperable.

const TABS := ["Guardados", "Borradores", "Historial", "Papelera"]

var _game: Node
var _tab := 0
var _tab_row: HBoxContainer
var _list: VBoxContainer
var _rename: LineEdit
var _menu: PopupMenu
var _selected := {}


func build(_args: Dictionary) -> void:
	_game = app.get_node("/root/Game")
	var panel := UiKit.panel()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 40
	panel.offset_top = 40
	panel.offset_bottom = -90
	panel.custom_minimum_size = Vector2(900, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := UiKit.vbox(12)
	panel.add_child(v)
	v.add_child(UiKit.title("Mis looks"))
	_tab_row = UiKit.hbox(8)
	v.add_child(_tab_row)
	_list = UiKit.vbox(8)
	v.add_child(UiKit.scroll(_list))
	_rename = LineEdit.new()
	_rename.placeholder_text = "Nuevo nombre y Intro"
	_rename.visible = false
	_rename.max_length = OutfitLibrary.MAX_NAME
	_rename.virtual_keyboard_enabled = true
	_rename.text_submitted.connect(_on_rename)
	v.add_child(_rename)
	_menu = PopupMenu.new()
	add_child(_menu)
	_menu.id_pressed.connect(_on_menu)
	_rebuild()


func _rebuild() -> void:
	UiKit.clear(_tab_row)
	for i in TABS.size():
		var b := UiKit.button(TABS[i], func() -> void: _select_tab(i), Vector2(0, 52))
		b.toggle_mode = true
		b.button_pressed = i == _tab
		_tab_row.add_child(b)
	UiKit.clear(_list)
	var lib: OutfitLibrary = _game.library
	var rows: Array = []
	match _tab:
		0:
			for l in lib.looks_sorted():
				rows.append({"tipo": "look", "id": l["id"], "texto": "%s · %d prendas" % [l["nombre"], l["prendas"].size()], "prendas": l["prendas"]})
		1:
			for d in lib.drafts_sorted():
				rows.append({"tipo": "borrador", "id": d["id"], "texto": "%s · %d prendas" % [d["nombre"], d["prendas"].size()], "prendas": d["prendas"]})
		2:
			for i in range(lib.history.size() - 1, -1, -1):
				var h: Dictionary = lib.history[i]
				rows.append({"tipo": "historial", "id": str(i), "texto": "%s · %s · %d prendas" % [_date(h["t"]), h["origen"], h["prendas"].size()], "prendas": h["prendas"]})
		3:
			for i in lib.trash.size():
				var tr: Dictionary = lib.trash[i]
				rows.append({"tipo": "papelera", "id": str(i), "texto": "%s (%s)" % [tr["datos"].get("nombre", "—"), tr["tipo"]], "prendas": tr["datos"].get("prendas", {})})
	if rows.is_empty():
		_list.add_child(UiKit.label("No hay nada aquí todavía.", UiTheme.SIZE_SMALL, UiTheme.MUTED))
	for r in rows:
		var b := UiKit.button(r["texto"], func() -> void: _open_menu(r), Vector2(0, 56))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_entered.connect(func() -> void: app.view.show_outfit(r["prendas"]))
		_list.add_child(b)


func _select_tab(i: int) -> void:
	_tab = i
	_rebuild()
	on_shown()


static func _date(t: float) -> String:
	return LooksDate.format(t)


func _open_menu(r: Dictionary) -> void:
	_selected = r
	_menu.clear()
	match r["tipo"]:
		"look":
			_menu.add_item("Cargar en el vestidor", 0)
			_menu.add_item("Renombrar", 1)
			_menu.add_item("Duplicar", 2)
			_menu.add_item("Enviar a la papelera", 3)
		"borrador":
			_menu.add_item("Seguir editando", 0)
			_menu.add_item("Convertir en look", 4)
			_menu.add_item("Enviar a la papelera", 5)
		"historial":
			_menu.add_item("Cargar en el vestidor", 0)
		"papelera":
			_menu.add_item("Restaurar", 6)
	_menu.popup_centered(Vector2i(480, 0))


func _on_menu(option: int) -> void:
	var lib: OutfitLibrary = _game.library
	var now: float = _game.now()
	match option:
		0:
			var dropped: Array = _game.load_into_outfit(_selected["prendas"])
			if _selected["tipo"] == "borrador":
				_game.active_draft_id = _selected["id"]
			if not dropped.is_empty():
				app.toast("%d prenda(s) ya no existen y se omitieron." % dropped.size())
			app.push("vestidor")
			return
		1:
			_rename.visible = true
			_rename.text = lib.looks[_selected["id"]]["nombre"]
			_rename.grab_focus()
			return
		2:
			lib.duplicate_look(_selected["id"], now)
		3:
			lib.delete_look(_selected["id"], now)
			app.toast("Look enviado a la papelera (se puede restaurar).")
		4:
			lib.promote_draft(_selected["id"], "", now)
		5:
			lib.delete_draft(_selected["id"], now)
		6:
			lib.restore_from_trash(int(_selected["id"]))
			app.toast("Restaurado.")
	_rebuild()
	on_shown()


func _on_rename(text: String) -> void:
	_game.library.rename_look(_selected["id"], text)
	_rename.visible = false
	_rebuild()
	on_shown()


func default_focus() -> Control:
	return _list.get_child(0) if _list.get_child_count() > 0 and _list.get_child(0) is Button else _tab_row.get_child(_tab)


func on_action(action: String) -> bool:
	if action == "seccion_siguiente" or action == "seccion_anterior":
		_tab = (_tab + (1 if action == "seccion_siguiente" else TABS.size() - 1)) % TABS.size()
		_rebuild()
		on_shown()
		return true
	return false


func prompts() -> Array:
	return [["ui_accept", "Opciones"], ["seccion_siguiente", "Pestaña"], ["ui_cancel", "Atrás"]]


func _exit_tree() -> void:
	if app != null:
		app.view.show_outfit(app.get_node("/root/Game").outfit.to_dict())
