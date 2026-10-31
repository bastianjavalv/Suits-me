extends SceneTree
## Recorrido de integración por el juego completo con datos reales y una partida temporal.
##   xvfb-run godot --path game -s res://tests/integration/recorrido.gd -- [--capturas=DIR] [--modo=portatil]
## Termina con código 0 si todas las comprobaciones pasan.

var failures: Array[String] = []
var shots := ""
var app: Node
var game: Node
var checks := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)
		print("  FALLO ", msg)
	else:
		print("  ok   ", msg)


func frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	if shots.is_empty():
		return
	await frames(8)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(shots.path_join(name + ".png"))


func press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await frames(2)


func _initialize() -> void:
	var mode := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capturas="):
			shots = a.trim_prefix("--capturas=")
			DirAccess.make_dir_recursive_absolute(shots)
		elif a.begins_with("--modo="):
			mode = a.trim_prefix("--modo=")
	if mode == "portatil":
		root.size = Vector2i(1280, 720)
	else:
		root.size = Vector2i(1920, 1080)
	var tmp := "user://pruebas_integracion/%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(tmp)
	game = root.get_node("Game")
	game.initialize("res://data", tmp, tmp.path_join("galeria"))
	if not mode.is_empty():
		root.get_node("Platform").force_mode(mode)
	check(game.data_errors.is_empty(), "datos sin errores")
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames(2)
	var gles3 := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	check(app.preparing == gles3 and (app.loading != null) == gles3,
		"«Preparando gráficos…» aparece solo con GLES3, el renderizador del NRO")
	if app.preparing:
		await shot("00_preparando_graficos")
		while app.preparing:
			await process_frame
	await frames(10)
	check(app.top().name == "Pantalla_menu", "arranca en el menú principal")
	await shot("01_menu")

	app.push("eras")
	await frames(6)
	check(app.top().name == "Pantalla_eras", "abre Eras de la Moda")
	await shot("02_eras")
	await press("ui_accept")
	check(app.top().name == "Pantalla_vestidor", "A en una era abre el vestidor")
	var dressing: Node = app.top()
	check(dressing.era_filter == "medieval", "el vestidor filtra la primera era")
	check(dressing._cards.size() >= 8, "el armario muestra las prendas de la época (%d)" % dressing._cards.size())

	# Probar un conjunto completo de los años 20 desde el vestidor.
	dressing.era_filter = "anos20"
	dressing.set_category(dressing.ALL)
	app.set_stage("deco_salon")
	for id in ["a20_vestido_cuentas", "a20_cloche", "a20_bob", "a20_sautoir", "a20_zapatos_correa", "a20_maquillaje"]:
		dressing._try_on(id)
	await frames(4)
	check(game.outfit.count() == 6, "seis prendas puestas")
	check(game.inventory.owns("a20_vestido_cuentas"), "probar una prenda la añade al armario gratis")
	check(app.view.stats()["piezas"] > 5, "el maniquí muestra las prendas en 3D")
	app.view.yaw = 18.0
	await shot("03_vestidor_anos20")

	# Historia de la prenda.
	dressing.focused_item = "a20_vestido_cuentas"
	dressing._open_sheet()
	await frames(4)
	check(app.top().name == "Pantalla_ficha", "abre HISTORIA DE LA PRENDA")
	var text := _all_text(app.top())
	check(text.contains("HISTORIA DE LA PRENDA"), "la ficha muestra su encabezado")
	check(text.contains("verificado") and text.contains("Fuentes"), "la ficha muestra estados y fuentes")
	check(text.contains("Sin atribución"), "la ficha indica que es un diseño original")
	await shot("04_historia_de_la_prenda")
	await press("ui_cancel")
	check(app.top().name == "Pantalla_vestidor", "B cierra la ficha")

	# Navegación con mando: cambiar de categoría con Y.
	var before: String = dressing.category
	await press("cambiar_categoria")
	check(dressing.category != before, "Y cambia de categoría")

	# Guardar look y borrador.
	dressing._save_look()
	dressing._save_draft()
	check(game.library.looks.size() == 1 and game.library.drafts.size() == 1, "look y borrador guardados")

	# Desafío.
	app.go_home()
	app.push("desafios")
	await frames(4)
	await shot("05_desafios")
	app.top()._start("a20_charleston")
	await frames(4)
	var d2: Node = app.top()
	check(d2.challenge_id == "a20_charleston", "el vestidor abre en modo desafío")
	d2._submit()
	await frames(4)
	check(app.top().name == "Pantalla_resultado", "presentar muestra el resultado")
	var res := _all_text(app.top())
	check(res.contains("Coherencia temática") and res.contains("Armonía cromática") and res.contains("Creatividad"), "el resultado desglosa los criterios")
	check(res.contains("sin conexión"), "el resultado aclara que la evaluación es local")
	check(game.challenges.best("a20_charleston") > 0, "se registra la mejor puntuación")
	await shot("06_resultado_desafio")
	await press("ui_cancel")

	# Foto para la galería.
	if not shots.is_empty():
		var photo: String = await app.take_photo()
		check(not photo.is_empty(), "el modo foto guarda una imagen en la galería")

	# Enciclopedia, looks, galería y opciones.
	app.go_home()
	app.push("enciclopedia")
	await frames(4)
	check(_all_text(app.top()).contains("Enciclopedia"), "abre la enciclopedia")
	await shot("07_enciclopedia")
	app.pop()
	app.push("looks")
	await frames(4)
	check(_all_text(app.top()).contains("Mis looks"), "abre Mis looks")
	app.pop()
	app.push("galeria")
	await frames(4)
	await shot("08_galeria")
	app.pop()
	app.push("opciones")
	await frames(4)
	check(_all_text(app.top()).contains("Reasignar controles"), "abre Opciones con reasignación de controles")
	await shot("09_opciones")
	app.pop()
	await press("pausa")
	check(app.top().name == "Pantalla_pausa", "+ abre la pausa")
	await press("ui_cancel")

	# La economía sigue siendo ilimitada y todo se guarda.
	check(game.economy.display_balance("gemas") == "∞", "gemas ilimitadas")
	check(game.save_now(), "la partida se guarda")

	print("")
	print("%d comprobaciones, %d fallos" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)


func _all_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += node.text + "\n"
	elif node is RichTextLabel:
		out += node.get_parsed_text() + "\n"
	elif node is Button:
		out += node.text + "\n"
	for c in node.get_children():
		out += _all_text(c)
	return out
