extends Screen
## Enciclopedia: fichas por época, consultables sin conexión.

var _game: Node
var _first: Button
var _preview: VBoxContainer


func build(_args: Dictionary) -> void:
	_game = app.get_node("/root/Game")
	opaque = true
	var bg := ColorRect.new()
	bg.color = UiTheme.BG_SOLID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := UiKit.hbox(28)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 48
	root.offset_top = 40
	root.offset_right = -48
	root.offset_bottom = -90
	add_child(root)
	var list := UiKit.vbox(8)
	var left := UiKit.vbox(10)
	left.custom_minimum_size = Vector2(700, 0)
	root.add_child(left)
	left.add_child(UiKit.title("Enciclopedia"))
	left.add_child(UiKit.label("%d fichas · %d fuentes" % [_game.encyclopedia.entries.size(), _game.encyclopedia.sources.size()],
		UiTheme.SIZE_SMALL, UiTheme.MUTED))
	left.add_child(UiKit.scroll(list))
	for era in _game.eras:
		list.add_child(UiKit.label(era["titulo"], UiTheme.SIZE_BODY, UiTheme.GOLD))
		for id in _game.encyclopedia.by_era.get(era["id"], []):
			var e: Dictionary = _game.encyclopedia.get_entry(id)
			var b := UiKit.button(e["nombre"], func() -> void: app.push("ficha", {"entry": id}), Vector2(0, 52))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_entered.connect(func() -> void: _show(e))
			b.mouse_entered.connect(func() -> void: _show(e))
			list.add_child(b)
			if _first == null:
				_first = b
	var panel := UiKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	_preview = UiKit.vbox(10)
	panel.add_child(UiKit.scroll(_preview))


func _show(e: Dictionary) -> void:
	UiKit.clear(_preview)
	_preview.add_child(UiKit.title(e["nombre"], 34))
	_preview.add_child(UiKit.rich(load("res://src/ui/sheet_screen.gd").entry_bbcode(e, [], false)))


func default_focus() -> Control:
	return _first


func prompts() -> Array:
	return [["ui_accept", "Abrir ficha"], ["ui_cancel", "Atrás"]]
