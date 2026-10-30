extends Screen
## HISTORIA DE LA PRENDA (o una ficha de la enciclopedia). La prenda se muestra en el maniquí a la
## izquierda y puede girarse mientras se lee; cada afirmación indica su estado y sus fuentes.

var _game: Node
var _scroll: ScrollContainer
var _close: Button


func build(args: Dictionary) -> void:
	allows_camera = true
	_game = app.get_node("/root/Game")
	var panel := UiKit.panel(26)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -1040
	panel.offset_right = -28
	panel.offset_top = 28
	panel.offset_bottom = -84
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := UiKit.vbox(12)
	panel.add_child(v)
	var content := UiKit.vbox(14)
	_scroll = UiKit.scroll(content)
	_scroll.custom_minimum_size = Vector2(980, 0)
	if args.has("item"):
		var item: Dictionary = _game.catalog.get_item(args["item"])
		_preview(item)
		v.add_child(UiKit.label("HISTORIA DE LA PRENDA", UiTheme.SIZE_SMALL, UiTheme.GOLD))
		v.add_child(UiKit.title(item["nombre"], 40))
		content.add_child(UiKit.rich(item_bbcode(item, _game)))
		var sheet: Dictionary = _game.encyclopedia.sheet_for_item(item)
		var cited: Array = []
		for entry in sheet["fichas"]:
			content.add_child(UiKit.rich(entry_bbcode(entry, cited)))
		content.add_child(UiKit.rich(sources_bbcode(cited, _game.encyclopedia)))
	else:
		var entry: Dictionary = _game.encyclopedia.get_entry(str(args.get("entry", "")))
		v.add_child(UiKit.label("ENCICLOPEDIA · %s" % _game.era_names.get(entry.get("era", ""), ""), UiTheme.SIZE_SMALL, UiTheme.GOLD))
		v.add_child(UiKit.title(entry.get("nombre", "Ficha"), 40))
		var cited: Array = []
		content.add_child(UiKit.rich(entry_bbcode(entry, cited, false)))
		content.add_child(UiKit.rich(_related_items(entry)))
		content.add_child(UiKit.rich(sources_bbcode(cited, _game.encyclopedia)))
	v.add_child(_scroll)
	_close = UiKit.button("Cerrar", func() -> void: app.pop(), Vector2(200, 56))
	v.add_child(_close)
	app.rig.offset_x = 0.9


func _preview(item: Dictionary) -> void:
	var o := Outfit.new()
	o.load_dict(_game.outfit.to_dict(), _game.catalog)
	o.equip(item)
	app.view.show_outfit(o.to_dict())


static func item_bbcode(item: Dictionary, game: Node) -> String:
	var f: Dictionary = item["ficha"]
	var fabric: Dictionary = game.fabrics.get(item["tejido"], {})
	var t := ""
	t += "[color=#c9a961]%s · %s[/color]\n" % [game.era_names.get(item["era"], item["era"]), Defs.CATEGORY_NAMES[item["categoria"]]]
	t += "[b]Tipo de pieza:[/b] %s\n" % Defs.PIECE_TYPES[f["tipo_pieza"]]
	t += "[b]Atribución:[/b] %s" % Defs.ATTRIBUTION_STATES[f["atribucion"]["estado"]]
	if f["atribucion"].has("nota"):
		t += " — %s" % f["atribucion"]["nota"]
	t += "\n\n%s\n\n" % f["descripcion"]
	t += "[b]Materiales del modelo:[/b] %s\n" % f["materiales_modelo"]
	t += "[b]Tejido:[/b] %s (%s)\n" % [fabric.get("nombre", item["tejido"]), fabric.get("fibra", "—")]
	t += "[b]Silueta:[/b] %s\n" % f["silueta"]
	t += "[b]Uso:[/b] %s\n" % f["uso"]
	if not item.get("influencias", []).is_empty():
		t += "[b]Influencias (no implica autoría):[/b] %s\n" % ", ".join(item["influencias"])
	t += "[b]Temporadas:[/b] %s · [b]Estilos:[/b] %s\n" % [", ".join(item["temporadas"].map(func(s): return Defs.SEASON_NAMES.get(s, s))),
		", ".join(item["estilos"])]
	return t


static func entry_bbcode(entry: Dictionary, cited: Array, with_title: bool = true) -> String:
	var t := ""
	if with_title:
		t += "\n[b]Ficha: %s[/b]\n" % entry["nombre"]
	t += "[color=#a8a39b]%s · %s[/color]\n%s\n" % [entry["periodo"], entry["region"], entry["resumen"]]
	var names := {"hechos": "Historia y contexto", "materiales": "Materiales", "tecnicas": "Técnicas de confección",
		"silueta": "Silueta", "uso": "Uso", "influencia": "Influencia", "curiosidades": "Curiosidades"}
	for field in Encyclopedia.CLAIM_FIELDS:
		var claims: Array = entry.get(field, [])
		if claims.is_empty():
			continue
		t += "\n[b]%s[/b]\n" % names[field]
		for c in claims:
			var refs: Array[String] = []
			for s in c.get("fuentes", []):
				if not cited.has(s):
					cited.append(s)
				refs.append("[%d]" % (cited.find(s) + 1))
			t += "• %s %s %s\n" % [UiKit.claim_badge(c["estado"]), c["texto"], " ".join(refs)]
	if entry.has("nota_fuentes"):
		t += "\n[i]Nota sobre las fuentes: %s[/i]\n" % entry["nota_fuentes"]
	for p in entry.get("piezas_referencia", []):
		t += "\n[b]Pieza de referencia:[/b] %s (%s)\n" % [p["titulo"], p.get("institucion", "")]
	t += "\n[color=#a8a39b]Revisión humana: %s[/color]\n" % ("realizada" if entry.get("revision_humana", false) else "pendiente")
	return t


static func sources_bbcode(cited: Array, enc: Encyclopedia) -> String:
	if cited.is_empty():
		return ""
	var t := "\n[b]Fuentes[/b]\n"
	for i in cited.size():
		var s: Dictionary = enc.sources.get(cited[i], {})
		t += "[%d] %s. %s. %s (consultado el %s).\n" % [i + 1, s.get("autor", ""), s.get("titulo", ""), s.get("url", ""), s.get("consultado", "")]
	t += "\n[color=#a8a39b]Leyenda: ✔ verificado en las fuentes citadas · ⚠ dato discutido · ◇ interpretación, no un hecho documentado.[/color]"
	return t


func _related_items(entry: Dictionary) -> String:
	var names: Array[String] = []
	for id in _game.catalog.order:
		if _game.catalog.get_item(id)["tipologias"].has(entry["id"]):
			names.append(_game.catalog.get_item(id)["nombre"])
	return "" if names.is_empty() else "\n[b]Prendas del juego relacionadas:[/b] %s\n" % ", ".join(names)


func _process(delta: float) -> void:
	if not visible:
		return
	var v := Input.get_axis("ui_up", "ui_down")
	if absf(v) > 0.1:
		_scroll.scroll_vertical += int(v * 900.0 * delta)


func default_focus() -> Control:
	return _close


func prompts() -> Array:
	return [["ui_down", "Desplazar"], ["rotar_derecha", "Girar"], ["zoom_acercar", "Zoom"], ["ui_cancel", "Cerrar"]]


func _exit_tree() -> void:
	if app != null:
		app.rig.offset_x = 0.0
		app.view.show_outfit(app.get_node("/root/Game").outfit.to_dict())
