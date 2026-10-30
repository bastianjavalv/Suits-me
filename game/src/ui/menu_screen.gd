extends Screen
## Menú principal: el maniquí gira despacio en el atelier mientras se elige destino.

var _first: Button


func build(_args: Dictionary) -> void:
	allows_camera = false
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	margin.custom_minimum_size = Vector2(640, 0)
	for side in ["left", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 72)
	add_child(margin)
	var box := UiKit.vbox(16)
	margin.add_child(box)
	box.add_child(UiKit.title("Atelier de las Eras", UiTheme.SIZE_HUGE))
	box.add_child(UiKit.label("Moda e historia del vestido", UiTheme.SIZE_BODY, UiTheme.GOLD))
	box.add_child(UiKit.spacer(24))
	_first = UiKit.button("Vestidor", func() -> void: app.push("vestidor"))
	box.add_child(_first)
	box.add_child(UiKit.button("Eras de la Moda", func() -> void: app.push("eras")))
	box.add_child(UiKit.button("Desafíos", func() -> void: app.push("desafios")))
	box.add_child(UiKit.button("Mis looks", func() -> void: app.push("looks")))
	box.add_child(UiKit.button("Galería", func() -> void: app.push("galeria")))
	box.add_child(UiKit.button("Enciclopedia", func() -> void: app.push("enciclopedia")))
	box.add_child(UiKit.button("Opciones", func() -> void: app.push("opciones")))
	var platform := app.get_node_or_null("/root/Platform")
	if platform == null or not platform.is_console():
		box.add_child(UiKit.button("Salir", _quit))
	box.add_child(UiKit.spacer())
	box.add_child(UiKit.label("Sin conexión · Sin anuncios · Monedas y gemas ilimitadas", UiTheme.SIZE_SMALL, UiTheme.MUTED))


func default_focus() -> Control:
	return _first


func on_cancel() -> bool:
	return true


func prompts() -> Array:
	return [["ui_accept", "Elegir"], ["pausa", "Pausa"]]


func _process(delta: float) -> void:
	if visible:
		app.view.rotate_by(delta * 12.0)


func _quit() -> void:
	app.get_node("/root/Game").save_now()
	get_tree().quit()
