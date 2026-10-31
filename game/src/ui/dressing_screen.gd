extends Screen
## Vestidor: armario con categorías y filtros, el conjunto puesto y las acciones (guardar, pose,
## foto, escenario, Historia de la prenda, presentar a un desafío).

const ALL := "todas"

var era_filter := ""
var challenge_id := ""
var category := ALL
var filter_spec: Dictionary = {}
var focused_item := ""
var _game: Node
var _tabs: HBoxContainer
var _grid: GridContainer
var _scroll: ScrollContainer
var _detail: Label
var _outfit_box: VBoxContainer
var _actions: VBoxContainer
var _header: Label
var _balance: Label
var _filter_label: Label
var _pose_button: Button
var _stage_button: Button
var _cards: Dictionary = {}
var _options: PopupMenu


func build(args: Dictionary) -> void:
	allows_camera = true
	_game = app.get_node("/root/Game")
	era_filter = str(args.get("era", ""))
	challenge_id = str(args.get("desafio", ""))
	if challenge_id.is_empty() and _game.active_context.begins_with("desafio:") and args.get("reanudar", false):
		challenge_id = _game.active_context.trim_prefix("desafio:")
	_game.active_context = ("desafio:" + challenge_id) if not challenge_id.is_empty() else "vestidor"
	if not era_filter.is_empty():
		app.set_stage(_game.era_by_id[era_filter]["escenario"])
	if not challenge_id.is_empty():
		app.set_stage(_game.challenges.challenges[challenge_id]["escenario"])
	app.rig.offset_x = 0.0
	_build_layout()
	_rebuild_tabs()
	_rebuild_grid()
	_rebuild_outfit()
	_game.outfit.changed.connect(_rebuild_outfit)
	_game.inventory.changed.connect(_refresh_cards)


func _build_layout() -> void:
	var left := UiKit.panel(16)
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 28
	left.offset_top = 28
	left.offset_bottom = -84
	left.custom_minimum_size = Vector2(640, 0)
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(left)
	var lv := UiKit.vbox(10)
	left.add_child(lv)
	_header = UiKit.title("", 34)
	lv.add_child(_header)
	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.custom_minimum_size = Vector2(0, 64)
	tabs_scroll.follow_focus = true
	lv.add_child(tabs_scroll)
	_tabs = UiKit.hbox(8)
	tabs_scroll.add_child(_tabs)
	var frow := UiKit.hbox(10)
	lv.add_child(frow)
	_filter_label = UiKit.label("", UiTheme.SIZE_SMALL, UiTheme.MUTED)
	_filter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_label.clip_text = true
	frow.add_child(_filter_label)
	frow.add_child(UiKit.button("Filtros", func() -> void: app.push("filtros", {"vestidor": self}), Vector2(150, 48)))
	_grid = GridContainer.new()
	_grid.columns = 3
	_scroll = UiKit.scroll(_grid)
	lv.add_child(_scroll)
	_detail = UiKit.label("", UiTheme.SIZE_SMALL, UiTheme.IVORY, true)
	_detail.custom_minimum_size = Vector2(0, 58)
	lv.add_child(_detail)

	var right := UiKit.panel(16)
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_right = -28
	right.offset_top = 28
	right.offset_bottom = -84
	right.offset_left = -420
	right.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(right)
	var rv := UiKit.vbox(10)
	right.add_child(rv)
	_balance = UiKit.label("", UiTheme.SIZE_SMALL, UiTheme.GOLD)
	rv.add_child(_balance)
	rv.add_child(UiKit.title("Conjunto", 30))
	_outfit_box = UiKit.vbox(6)
	rv.add_child(UiKit.scroll(_outfit_box))
	_actions = UiKit.vbox(8)
	rv.add_child(_actions)
	_actions.add_child(UiKit.button("Historia de la prenda", _open_sheet, Vector2(0, 56)))
	_actions.add_child(UiKit.button("Guardar look", _save_look, Vector2(0, 56)))
	_actions.add_child(UiKit.button("Guardar borrador", _save_draft, Vector2(0, 56)))
	_pose_button = UiKit.button("Pose: Erguida", _next_pose, Vector2(0, 56))
	_actions.add_child(_pose_button)
	_stage_button = UiKit.button("Escenario", _next_stage, Vector2(0, 56))
	_actions.add_child(_stage_button)
	_actions.add_child(UiKit.button("Modo foto", func() -> void: app.start_photo_mode(), Vector2(0, 56)))
	if not challenge_id.is_empty():
		var submit := UiKit.button("Presentar al desafío", _submit, Vector2(0, 64))
		submit.add_theme_color_override("font_color", UiTheme.GOLD)
		_actions.add_child(submit)
	_options = PopupMenu.new()
	add_child(_options)
	_options.id_pressed.connect(_on_option)
	_update_header()


func _update_header() -> void:
	var parts: Array[String] = []
	if not challenge_id.is_empty():
		parts.append("Desafío: " + str(_game.challenges.challenges[challenge_id]["titulo"]))
	elif not era_filter.is_empty():
		parts.append(str(_game.era_by_id[era_filter]["titulo"]))
	else:
		parts.append("Vestidor libre")
	_header.text = parts[0]
	_balance.text = "Monedas %s · Gemas %s" % [_game.economy.display_balance("monedas"), _game.economy.display_balance("gemas")]
	var stage: Dictionary = _game.stages.get(app.current_stage, {})
	_stage_button.text = "Escenario: %s" % stage.get("nombre", "—")


func _rebuild_tabs() -> void:
	UiKit.clear(_tabs)
	var cats: Array[String] = [ALL]
	cats.append_array(Defs.CATEGORIES)
	for c in cats:
		var name: String = "Todo" if c == ALL else Defs.CATEGORY_NAMES[c]
		var b := UiKit.button(name, func() -> void: set_category(c), Vector2(0, 52))
		b.toggle_mode = true
		b.button_pressed = c == category
		_tabs.add_child(b)


func set_category(c: String) -> void:
	category = c
	_rebuild_tabs()
	_rebuild_grid()


func current_spec() -> Dictionary:
	var spec := filter_spec.duplicate(true)
	spec["categoria"] = "" if category == ALL else category
	if not era_filter.is_empty() and not spec.has("eras"):
		spec["eras"] = [era_filter]
	return spec


func _rebuild_grid() -> void:
	UiKit.clear(_grid)
	_cards.clear()
	var ids := WardrobeFilter.apply(_game.catalog, _game.inventory, current_spec(), _game.era_order)
	for id in ids:
		_grid.add_child(_make_card(id))
	_filter_label.text = "%d prendas · %s" % [ids.size(), _filter_summary()]
	if ids.is_empty():
		_detail.text = "Ninguna prenda coincide con los filtros."


func _filter_summary() -> String:
	var bits: Array[String] = []
	var spec := current_spec()
	if not spec.get("eras", []).is_empty():
		bits.append(", ".join(spec["eras"].map(func(e): return _game.era_names.get(e, e))))
	for key in ["colores", "estilos", "temporadas", "influencias"]:
		if not spec.get(key, []).is_empty():
			bits.append(", ".join(spec[key]))
	if spec.get("solo_favoritas", false):
		bits.append("favoritas")
	if spec.get("solo_adquiridas", false):
		bits.append("mi armario")
	if not str(spec.get("texto", "")).is_empty():
		bits.append("«%s»" % spec["texto"])
	return "sin filtros" if bits.is_empty() else " · ".join(bits)


func _make_card(id: String) -> Button:
	var it: Dictionary = _game.catalog.get_item(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(186, 214)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = it["nombre"]
	var v := UiKit.vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var main := Color.html(it["color"])
	var second := Color.html(str(it.get("color_secundario", it["color"])))
	v.add_child(UiKit.swatch(main, second, Vector2(166, 100)))
	var name := UiKit.label(it["nombre"], UiTheme.SIZE_SMALL, UiTheme.IVORY, true)
	name.custom_minimum_size = Vector2(166, 0)
	name.max_lines_visible = 2
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name)
	var status := UiKit.label("", 18, UiTheme.MUTED)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(status)
	b.set_meta("status", status)
	b.focus_entered.connect(func() -> void: _on_focus_item(id))
	b.mouse_entered.connect(func() -> void: _on_focus_item(id))
	b.pressed.connect(func() -> void: _try_on(id))
	_cards[id] = b
	_update_card(id)
	return b


func _update_card(id: String) -> void:
	if not _cards.has(id):
		return
	var it: Dictionary = _game.catalog.get_item(id)
	var marks: Array[String] = [_game.era_names.get(it["era"], it["era"])]
	if _game.outfit.is_worn(id):
		marks.append("● puesta")
	elif _game.inventory.owns(id):
		marks.append("✓ en tu armario")
	else:
		marks.append("∞ gratis")
	if _game.inventory.is_favorite(id):
		marks.append("★")
	(_cards[id].get_meta("status") as Label).text = " · ".join(marks)


func _refresh_cards() -> void:
	for id in _cards:
		_update_card(id)


func _on_focus_item(id: String) -> void:
	focused_item = id
	var it: Dictionary = _game.catalog.get_item(id)
	var fabric: Dictionary = _game.fabrics.get(it["tejido"], {})
	_detail.text = "%s · %s · %s. Opciones: %s" % [it["nombre"], Defs.CATEGORY_NAMES[it["categoria"]],
		fabric.get("nombre", it["tejido"]), _glyph("opciones_prenda", "C")]


func _glyph(action: String, fallback: String) -> String:
	var controls := app.get_node_or_null("/root/Controls")
	var g: String = controls.glyph(action) if controls != null else ""
	return g if not g.is_empty() else fallback


func _try_on(id: String) -> void:
	var r: Dictionary = _game.try_on(id)
	if not r.get("ok", false):
		app.toast(str(r.get("mensaje", "")))
		return
	app.toast(str(r.get("mensaje", "")), 2.0)
	app.vibrate(0.2, 0.05)
	_update_card(id)
	_refresh_cards()


func _rebuild_outfit() -> void:
	if not is_instance_valid(_outfit_box):
		return
	UiKit.clear(_outfit_box)
	var slots: Dictionary = _game.outfit.to_dict()
	if slots.is_empty():
		_outfit_box.add_child(UiKit.label("Elige prendas del armario.", UiTheme.SIZE_SMALL, UiTheme.MUTED, true))
	for cat in Defs.CATEGORIES:
		if slots.has(cat):
			var it: Dictionary = _game.catalog.get_item(slots[cat])
			var b := UiKit.button("%s: %s" % [Defs.CATEGORY_NAMES[cat], it["nombre"]], func() -> void: _game.outfit.unequip(cat), Vector2(0, 48))
			b.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.tooltip_text = "Quitar"
			_outfit_box.add_child(b)
	_refresh_cards()


func default_focus() -> Control:
	return _grid.get_child(0) if _grid.get_child_count() > 0 else _tabs.get_child(0)


func refresh() -> void:
	_update_header()
	_rebuild_grid()
	_rebuild_outfit()
	app.view.show_outfit(_game.outfit.to_dict())


func on_action(action: String) -> bool:
	match action:
		"cambiar_categoria":
			var cats: Array[String] = [ALL]
			cats.append_array(Defs.CATEGORIES)
			set_category(cats[(cats.find(category) + 1) % cats.size()])
			app.vibrate(0.15, 0.04)
			on_shown()
			return true
		"seccion_anterior", "seccion_siguiente":
			var in_actions: bool = _actions.get_child(0).has_focus() or _actions.is_ancestor_of(get_viewport().gui_get_focus_owner())
			if in_actions:
				on_shown()
			else:
				_actions.get_child(0).grab_focus()
			return true
		"opciones_prenda":
			_open_options()
			return true
		"inventario":
			filter_spec["solo_adquiridas"] = not filter_spec.get("solo_adquiridas", false)
			_rebuild_grid()
			app.toast("Mostrando " + ("solo tu armario" if filter_spec["solo_adquiridas"] else "todo el catálogo"), 1.5)
			on_shown()
			return true
	return false


func _open_options() -> void:
	if focused_item.is_empty():
		return
	_options.clear()
	_options.add_item("Historia de la prenda", 0)
	_options.add_item("Quitar de favoritas" if _game.inventory.is_favorite(focused_item) else "Marcar como favorita", 1)
	_options.add_item("Quitarse la prenda" if _game.outfit.is_worn(focused_item) else "Probarse la prenda", 2)
	_options.add_item("Inspeccionar de cerca", 3)
	_options.popup_centered(Vector2i(520, 0))


func _on_option(option: int) -> void:
	match option:
		0:
			_open_sheet()
		1:
			_game.inventory.toggle_favorite(focused_item)
			_update_card(focused_item)
		2:
			_try_on(focused_item)
		3:
			app.rig.inspect(_inspect_height(focused_item))


func _inspect_height(id: String) -> float:
	var cat: String = _game.catalog.get_item(id)["categoria"]
	return {"tocado": 1.62, "peinado": 1.62, "maquillaje": 1.65, "gafas": 1.64, "joyeria": 1.4, "calzado": 0.12,
		"parte_inferior": 0.7, "cinturon": 1.0, "guantes": 0.95, "bolso": 0.9}.get(cat, 1.1)


func _open_sheet() -> void:
	if focused_item.is_empty():
		app.toast("Selecciona primero una prenda del armario.")
		return
	app.push("ficha", {"item": focused_item})


func _save_look() -> void:
	if _game.outfit.count() == 0:
		app.toast("El conjunto está vacío.")
		return
	var id: String = _game.save_current_look("")
	app.toast("Look guardado como «%s»." % _game.library.looks[id]["nombre"])


func _save_draft() -> void:
	_game.save_current_draft()
	app.toast("Borrador guardado. Lo encontrarás en Mis looks.")


func _next_pose() -> void:
	_pose_button.text = "Pose: " + app.next_pose()


func _next_stage() -> void:
	var ids: Array = _game.stages.keys()
	var i := (ids.find(app.current_stage) + 1) % ids.size()
	app.set_stage(ids[i])
	_update_header()


func _submit() -> void:
	if _game.outfit.count() == 0:
		app.toast("Viste el maniquí antes de presentar el conjunto.")
		return
	var result: Dictionary = _game.submit_challenge(challenge_id)
	app.vibrate(0.5, 0.15)
	app.push("resultado", {"resultado": result, "desafio": challenge_id})


func prompts() -> Array:
	var p := [["ui_accept", "Probar"], ["opciones_prenda", "Opciones"], ["cambiar_categoria", "Categoría"],
		["seccion_siguiente", "Sección"], ["rotar_derecha", "Girar"], ["zoom_acercar", "Zoom"], ["inventario", "Mi armario"],
		["ui_cancel", "Atrás"]]
	return p


func _exit_tree() -> void:
	if _game != null:
		if _game.outfit.changed.is_connected(_rebuild_outfit):
			_game.outfit.changed.disconnect(_rebuild_outfit)
		if _game.inventory.changed.is_connected(_refresh_cards):
			_game.inventory.changed.disconnect(_refresh_cards)
