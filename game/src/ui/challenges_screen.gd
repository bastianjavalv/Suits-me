extends Screen
## Lista de desafíos por época, con el reglamento de la evaluación local.

var _game: Node
var _first: Button
var _info: VBoxContainer


func build(_args: Dictionary) -> void:
	_game = app.get_node("/root/Game")
	var root := UiKit.hbox(28)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 48
	root.offset_top = 40
	root.offset_right = -48
	root.offset_bottom = -90
	add_child(root)
	var left := UiKit.panel()
	left.custom_minimum_size = Vector2(900, 0)
	root.add_child(left)
	var list := UiKit.vbox(8)
	var lv := UiKit.vbox(10)
	left.add_child(lv)
	lv.add_child(UiKit.title("Desafíos"))
	lv.add_child(UiKit.scroll(list))
	var groups: Array = _game.eras.map(func(e): return e["id"])
	for era_id in groups + ["libre"]:
		var ids: Array = []
		for id in _game.challenges.order:
			var c: Dictionary = _game.challenges.challenges[id]
			if (era_id == "libre" and c["tipo"] == "libre") or (c["tipo"] != "libre" and c["era"] == era_id):
				ids.append(id)
		if ids.is_empty():
			continue
		list.add_child(UiKit.label("Desafíos libres" if era_id == "libre" else _game.era_names[era_id], UiTheme.SIZE_BODY, UiTheme.GOLD))
		for id in ids:
			var c: Dictionary = _game.challenges.challenges[id]
			var stars: int = _game.challenges.stars(id)
			var b := UiKit.button("%s   %s   %s" % [c["titulo"], "★".repeat(stars) + "☆".repeat(3 - stars),
				("mejor %d" % _game.challenges.best(id)) if stars > 0 or _game.challenges.best(id) > 0 else ""],
				func() -> void: _start(id), Vector2(0, 56))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_entered.connect(func() -> void: _show(id))
			b.mouse_entered.connect(func() -> void: _show(id))
			list.add_child(b)
			if _first == null:
				_first = b
	var panel := UiKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	_info = UiKit.vbox(10)
	panel.add_child(UiKit.scroll(_info))


func _show(id: String) -> void:
	var c: Dictionary = _game.challenges.challenges[id]
	UiKit.clear(_info)
	_info.add_child(UiKit.title(c["titulo"], 34))
	_info.add_child(UiKit.label({"recreacion_historica": "Recreación histórica", "creativo": "Creativo", "libre": "Libre"}[c["tipo"]],
		UiTheme.SIZE_SMALL, UiTheme.GOLD))
	_info.add_child(UiKit.label(c["descripcion"], UiTheme.SIZE_BODY, UiTheme.IVORY, true))
	var req: Dictionary = c.get("requisitos", {})
	var t := ""
	if not req.get("obligatorias", []).is_empty():
		t += "[b]Obligatorio:[/b] %s\n" % ", ".join(req["obligatorias"].map(func(x): return Evaluator._slot_label(x)))
	if not req.get("sugeridas", []).is_empty():
		t += "[b]Sugerido:[/b] %s\n" % ", ".join(req["sugeridas"].map(func(x): return Evaluator._slot_label(x)))
	var banned: Dictionary = req.get("prohibidos", {})
	if not banned.is_empty():
		t += "[b]Norma:[/b] sin %s\n" % ", ".join(banned.get("tejidos", []) + banned.get("colores", []))
	if req.get("min_eras", 0) > 0:
		t += "[b]Mínimo de épocas distintas:[/b] %d\n" % req["min_eras"]
	if not c.get("eras_validas", []).is_empty():
		t += "[b]Época:[/b] %s\n" % ", ".join(c["eras_validas"].map(func(e): return _game.era_names.get(e, e)))
	_info.add_child(UiKit.rich(t))
	if not c.get("paleta", []).is_empty():
		var row := UiKit.hbox(6)
		row.add_child(UiKit.label("Paleta sugerida:", UiTheme.SIZE_SMALL, UiTheme.MUTED))
		for hex in c["paleta"]:
			row.add_child(UiKit.swatch(Color.html(hex), Color.html(hex), Vector2(40, 24)))
		_info.add_child(row)
	_info.add_child(UiKit.rich("\n[b]Cómo se evalúa (local, sin conexión)[/b]\nCoherencia temática 40 · Armonía cromática 25 · Completitud 15 · Creatividad 20. Estrellas a partir de 60, 75 y 90 puntos. Puedes presentar todas las alternativas que quieras: se guarda tu mejor resultado."))
	app.set_stage(c["escenario"])


func _start(id: String) -> void:
	var c: Dictionary = _game.challenges.challenges[id]
	var era := str(c["eras_validas"][0]) if c.get("eras_validas", []).size() == 1 else ""
	app.push("vestidor", {"desafio": id, "era": era})


func default_focus() -> Control:
	return _first


func refresh() -> void:
	pass
