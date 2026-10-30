extends Screen
## Filtros del armario: época, color, estilo, temporada, diseñador o influencia, precio,
## favoritas, solo mi armario, texto y orden.

var _dressing: Node
var _game: Node
var _checks: Dictionary = {}   ## clave -> {valor: CheckBox}
var _fav: CheckBox
var _owned: CheckBox
var _text: LineEdit
var _order: OptionButton
var _price: OptionButton
var _first: Control

const ORDERS := {"era": "Época", "nombre": "Nombre", "precio": "Precio", "reciente": "Adquirida recientemente"}
const PRICES := [["Cualquier precio", -1, -1, ""], ["Hasta 500 monedas", 0, 500, "monedas"], ["500 a 1000 monedas", 500, 1000, "monedas"],
	["Más de 1000 monedas", 1000, -1, "monedas"], ["Solo gemas", -1, -1, "gemas"]]


func build(args: Dictionary) -> void:
	_dressing = args["vestidor"]
	_game = app.get_node("/root/Game")
	var spec: Dictionary = _dressing.current_spec()
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
	v.add_child(UiKit.title("Filtros del armario", 36))
	var body := UiKit.vbox(10)
	v.add_child(UiKit.scroll(body))
	var facets := WardrobeFilter.facets(_game.catalog)
	_section(body, "eras", "Época", _game.eras.map(func(e): return [e["id"], e["titulo"]]), spec.get("eras", []))
	_section(body, "colores", "Color", facets["colores"].map(func(c): return [c, Defs.COLOR_FAMILY_NAMES.get(c, c)]), spec.get("colores", []))
	_section(body, "estilos", "Estilo", facets["estilos"].map(func(s): return [s, s]), spec.get("estilos", []))
	_section(body, "temporadas", "Temporada", Defs.SEASONS.map(func(s): return [s, Defs.SEASON_NAMES[s]]), spec.get("temporadas", []))
	_section(body, "influencias", "Diseñador o influencia", facets["influencias"].map(func(s): return [s, s]), spec.get("influencias", []))
	var row := UiKit.hbox(14)
	body.add_child(row)
	_fav = CheckBox.new()
	_fav.text = "Solo favoritas"
	_fav.button_pressed = spec.get("solo_favoritas", false)
	row.add_child(_fav)
	_owned = CheckBox.new()
	_owned.text = "Solo mi armario"
	_owned.button_pressed = spec.get("solo_adquiridas", false)
	row.add_child(_owned)
	_price = OptionButton.new()
	for i in PRICES.size():
		_price.add_item(PRICES[i][0], i)
	row.add_child(_price)
	_order = OptionButton.new()
	for k in ORDERS:
		_order.add_item(ORDERS[k])
	_order.select(ORDERS.keys().find(spec.get("orden", "era")))
	row.add_child(_order)
	_text = LineEdit.new()
	_text.placeholder_text = "Buscar por nombre…"
	_text.text = str(spec.get("texto", ""))
	_text.virtual_keyboard_enabled = true
	_text.custom_minimum_size = Vector2(420, 0)
	body.add_child(_text)
	var buttons := UiKit.hbox(12)
	v.add_child(buttons)
	_first = UiKit.button("Aplicar", _apply, Vector2(240, 60))
	buttons.add_child(_first)
	buttons.add_child(UiKit.button("Limpiar filtros", _clear, Vector2(240, 60)))


func _section(parent: Control, key: String, title: String, options: Array, selected: Array) -> void:
	if options.is_empty():
		return
	parent.add_child(UiKit.label(title, UiTheme.SIZE_BODY, UiTheme.GOLD))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 8)
	parent.add_child(flow)
	_checks[key] = {}
	for o in options:
		var cb := CheckBox.new()
		cb.text = str(o[1])
		cb.button_pressed = selected.has(o[0])
		cb.focus_mode = Control.FOCUS_ALL
		flow.add_child(cb)
		_checks[key][o[0]] = cb


func _apply() -> void:
	var spec := {}
	for key in _checks:
		var values: Array = []
		for value in _checks[key]:
			if _checks[key][value].button_pressed:
				values.append(value)
		spec[key] = values
	spec["solo_favoritas"] = _fav.button_pressed
	spec["solo_adquiridas"] = _owned.button_pressed
	spec["texto"] = _text.text.strip_edges()
	spec["orden"] = ORDERS.keys()[_order.selected]
	var pr: Array = PRICES[_price.selected]
	spec["precio_min"] = pr[1]
	spec["precio_max"] = pr[2]
	spec["moneda"] = pr[3]
	if spec["eras"].is_empty():
		_dressing.era_filter = ""
	_dressing.filter_spec = spec
	app.pop()


func _clear() -> void:
	_dressing.filter_spec = {}
	_dressing.era_filter = ""
	app.pop()


func default_focus() -> Control:
	return _first
