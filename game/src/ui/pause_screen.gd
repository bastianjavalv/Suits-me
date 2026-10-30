extends Screen
## Pausa (botón +).

var _first: Button


func build(_args: Dictionary) -> void:
	var panel := UiKit.panel(28)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.position = Vector2(-280, -260)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := UiKit.vbox(12)
	panel.add_child(v)
	v.add_child(UiKit.title("Pausa"))
	_first = UiKit.button("Continuar", func() -> void: app.pop())
	v.add_child(_first)
	v.add_child(UiKit.button("Guardar ahora", _save))
	v.add_child(UiKit.button("Opciones", func() -> void: app.push("opciones")))
	v.add_child(UiKit.button("Menú principal", func() -> void: app.go_home()))


func _save() -> void:
	var ok: bool = app.get_node("/root/Game").save_now(true)
	app.toast("Partida guardada (con copia de seguridad)." if ok else "No se pudo guardar.")


func default_focus() -> Control:
	return _first


func prompts() -> Array:
	return [["ui_accept", "Elegir"], ["ui_cancel", "Continuar"]]
