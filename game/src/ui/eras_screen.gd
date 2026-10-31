extends Screen
## Eras de la Moda: nueve capítulos. Al enfocar uno se muestra su escenario y su resumen.

var _cards: Array[Button] = []
var _info: VBoxContainer


func build(_args: Dictionary) -> void:
	var game := app.get_node("/root/Game")
	var root := UiKit.hbox(28)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 56
	root.offset_top = 48
	root.offset_right = -56
	root.offset_bottom = -90
	add_child(root)
	var left := UiKit.vbox(18)
	left.custom_minimum_size = Vector2(980, 0)
	root.add_child(left)
	left.add_child(UiKit.title("Eras de la Moda"))
	var grid := GridContainer.new()
	grid.columns = 3
	left.add_child(grid)
	for era in game.eras:
		var summary: Dictionary = game.challenges.era_summary(era["id"])
		var b := Button.new()
		b.custom_minimum_size = Vector2(310, 196)
		b.focus_mode = Control.FOCUS_ALL
		var v := UiKit.vbox(6)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 18
		v.offset_top = 14
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(UiKit.label("Capítulo %d" % era["orden"], UiTheme.SIZE_SMALL, UiTheme.GOLD))
		var t := UiKit.title(era["titulo"], 34)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(t)
		v.add_child(UiKit.label(era["periodo"], UiTheme.SIZE_SMALL, UiTheme.MUTED))
		var colors := UiKit.hbox(4)
		for hex in era.get("paleta", []):
			colors.add_child(UiKit.swatch(Color.html(hex), Color.html(hex), Vector2(30, 14)))
		v.add_child(colors)
		v.add_child(UiKit.label("★ %d/%d · %d prendas" % [summary["estrellas"], summary["max_estrellas"],
			game.catalog.by_era.get(era["id"], []).size()], UiTheme.SIZE_SMALL, UiTheme.IVORY))
		b.add_child(v)
		var id: String = era["id"]
		b.focus_entered.connect(func() -> void: _preview(id))
		b.mouse_entered.connect(func() -> void: _preview(id))
		b.pressed.connect(func() -> void: app.push("vestidor", {"era": id}))
		grid.add_child(b)
		_cards.append(b)
	var panel := UiKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	_info = UiKit.vbox(10)
	panel.add_child(UiKit.scroll(_info))


func default_focus() -> Control:
	return _cards[0] if not _cards.is_empty() else null


func _preview(id: String) -> void:
	var game := app.get_node("/root/Game")
	var era: Dictionary = game.era_by_id[id]
	app.set_stage(era["escenario"])
	UiKit.clear(_info)
	_info.add_child(UiKit.title(era["titulo"], 36))
	_info.add_child(UiKit.label(era["periodo"], UiTheme.SIZE_SMALL, UiTheme.GOLD))
	_info.add_child(UiKit.label(era["resumen"], UiTheme.SIZE_BODY, UiTheme.IVORY, true))
	for s in era.get("subperiodos", []):
		_info.add_child(UiKit.rich("[b]%s.[/b] %s" % [s["nombre"], s["descripcion"]]))
	_info.add_child(UiKit.label("Resumen introductorio: los datos con sus fuentes están en las fichas de la Enciclopedia.",
		UiTheme.SIZE_SMALL, UiTheme.MUTED, true))


func prompts() -> Array:
	return [["ui_accept", "Entrar al vestidor"], ["ui_cancel", "Atrás"]]
