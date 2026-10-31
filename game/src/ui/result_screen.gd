extends Screen
## Resultado de la evaluación local con el desglose de cada criterio.

var _first: Button
var _game: Node
var _challenge := ""


func build(args: Dictionary) -> void:
	_game = app.get_node("/root/Game")
	_challenge = str(args.get("desafio", ""))
	var r: Dictionary = args.get("resultado", {})
	var panel := UiKit.panel(28)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1040, 760)
	panel.position = Vector2(-520, -400)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := UiKit.vbox(12)
	panel.add_child(v)
	var head := UiKit.hbox(24)
	v.add_child(head)
	head.add_child(UiKit.title("%d" % int(r.get("total", 0)), 96))
	var hv := UiKit.vbox(4)
	head.add_child(hv)
	var stars := int(r.get("estrellas", 0))
	hv.add_child(UiKit.label("★".repeat(stars) + "☆".repeat(3 - stars), 48, UiTheme.GOLD))
	if r.get("nuevo_record", false):
		hv.add_child(UiKit.label("¡Nuevo récord!", UiTheme.SIZE_BODY, UiTheme.OK))
	var body := UiKit.vbox(10)
	v.add_child(UiKit.scroll(body))
	for c in r.get("criterios", []):
		var t := "[b]%s[/b]  %d / %d\n" % [c["nombre"], c["puntos"], c["max"]]
		for d in c["detalle"]:
			t += "• %s\n" % d
		body.add_child(UiKit.rich(t))
	body.add_child(UiKit.label(str(r.get("aviso", "")), UiTheme.SIZE_SMALL, UiTheme.MUTED, true))
	var row := UiKit.hbox(12)
	v.add_child(row)
	_first = UiKit.button("Seguir editando", func() -> void: app.pop(), Vector2(300, 60))
	row.add_child(_first)
	row.add_child(UiKit.button("Guardar como look", _save, Vector2(300, 60)))
	row.add_child(UiKit.button("Otros desafíos", _to_challenges, Vector2(300, 60)))


func _to_challenges() -> void:
	app.go_home()
	app.push("desafios")


func _save() -> void:
	var name: String = _game.challenges.challenges.get(_challenge, {}).get("titulo", "")
	_game.save_current_look(name)
	app.toast("Look guardado.")


func default_focus() -> Control:
	return _first
