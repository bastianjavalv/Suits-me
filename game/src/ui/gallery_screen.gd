extends Screen
## Galería de fotografías de looks, guardada en la partida local.

var _game: Node
var _grid: GridContainer
var _viewer: PanelContainer


func build(_args: Dictionary) -> void:
	_game = app.get_node("/root/Game")
	opaque = true
	var bg := ColorRect.new()
	bg.color = UiTheme.BG_SOLID
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := UiKit.vbox(14)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 48
	v.offset_top = 40
	v.offset_right = -48
	v.offset_bottom = -90
	add_child(v)
	v.add_child(UiKit.title("Galería"))
	_grid = GridContainer.new()
	_grid.columns = 4
	v.add_child(UiKit.scroll(_grid))
	_viewer = UiKit.panel(20)
	_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewer.offset_left = 120
	_viewer.offset_right = -120
	_viewer.offset_top = 60
	_viewer.offset_bottom = -100
	_viewer.visible = false
	add_child(_viewer)
	_rebuild()


func _rebuild() -> void:
	UiKit.clear(_grid)
	var photos: Array = _game.gallery.sorted()
	if photos.is_empty():
		_grid.add_child(UiKit.label("Aún no hay fotos. En el vestidor elige «Modo foto».", UiTheme.SIZE_BODY, UiTheme.MUTED, true))
	for p in photos:
		var b := Button.new()
		b.custom_minimum_size = Vector2(400, 260)
		b.focus_mode = Control.FOCUS_ALL
		var img: Image = _game.gallery.load_image(p["id"])
		if img != null:
			b.icon = ImageTexture.create_from_image(img)
			b.expand_icon = true
		b.text = p["titulo"]
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.pressed.connect(func() -> void: _open(p))
		_grid.add_child(b)


func _open(p: Dictionary) -> void:
	UiKit.clear(_viewer)
	_viewer.visible = true
	var v := UiKit.vbox(12)
	_viewer.add_child(v)
	var img: Image = _game.gallery.load_image(p["id"], false)
	if img != null:
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(tr)
	var row := UiKit.hbox(12)
	v.add_child(row)
	row.add_child(UiKit.label("%s · %s" % [p["titulo"], LooksDate.format(p["creado"])], UiTheme.SIZE_BODY, UiTheme.IVORY))
	var recreate := UiKit.button("Recrear el look", func() -> void: _recreate(p), Vector2(260, 56))
	row.add_child(recreate)
	row.add_child(UiKit.button("Borrar foto", func() -> void: _delete(p), Vector2(220, 56)))
	row.add_child(UiKit.button("Cerrar", func() -> void: on_cancel(), Vector2(180, 56)))
	recreate.grab_focus()


func _recreate(p: Dictionary) -> void:
	_game.load_into_outfit(p["prendas"])
	app.push("vestidor")


func _delete(p: Dictionary) -> void:
	_game.gallery.delete(p["id"])
	_viewer.visible = false
	_rebuild()
	on_shown()


func on_cancel() -> bool:
	if _viewer.visible:
		_viewer.visible = false
		on_shown()
		return true
	return false


func default_focus() -> Control:
	return _grid.get_child(0) if _grid.get_child_count() > 0 and _grid.get_child(0) is Button else null
