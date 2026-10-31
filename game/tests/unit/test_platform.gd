extends TestCase


func test_botones_por_letra_en_cada_disposicion() -> void:
	assert_eq(InputBindings.face_button("A", "nintendo"), JOY_BUTTON_B, "A de Nintendo está a la derecha")
	assert_eq(InputBindings.face_button("B", "nintendo"), JOY_BUTTON_A, "B de Nintendo está abajo")
	assert_eq(InputBindings.face_button("X", "nintendo"), JOY_BUTTON_Y, "X de Nintendo está arriba")
	assert_eq(InputBindings.face_button("Y", "nintendo"), JOY_BUTTON_X, "Y de Nintendo está a la izquierda")
	assert_eq(InputBindings.face_button("A", "xbox"), JOY_BUTTON_A)
	assert_eq(InputBindings.face_button("Y", "xbox"), JOY_BUTTON_Y)


func test_mapa_completo_de_la_especificacion() -> void:
	InputBindings.apply("nintendo")
	var expected := {
		"ui_accept": JOY_BUTTON_B, "ui_cancel": JOY_BUTTON_A, "opciones_prenda": JOY_BUTTON_Y,
		"cambiar_categoria": JOY_BUTTON_X, "seccion_anterior": JOY_BUTTON_LEFT_SHOULDER,
		"seccion_siguiente": JOY_BUTTON_RIGHT_SHOULDER, "pausa": JOY_BUTTON_START, "inventario": JOY_BUTTON_BACK,
		"ui_up": JOY_BUTTON_DPAD_UP, "ui_left": JOY_BUTTON_DPAD_LEFT,
	}
	for action in expected:
		var found := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton and ev.button_index == expected[action]:
				found = true
		assert_true(found, "%s debe usar el botón %d" % [action, expected[action]])
	var axes := {"rotar_derecha": JOY_AXIS_RIGHT_X, "zoom_acercar": JOY_AXIS_TRIGGER_RIGHT,
		"zoom_alejar": JOY_AXIS_TRIGGER_LEFT, "ui_down": JOY_AXIS_LEFT_Y}
	for action in axes:
		var found := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion and ev.axis == axes[action] and ev.axis_value > 0.0:
				found = true
		assert_true(found, "%s debe usar el eje %d" % [action, axes[action]])


func test_simulacion_de_pulsaciones() -> void:
	InputBindings.apply("nintendo")
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_B
	press.pressed = true
	assert_true(press.is_action("ui_accept"), "A (posición derecha) confirma en Switch")
	assert_false(press.is_action("ui_cancel"))
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0.9
	assert_true(stick.is_action("rotar_derecha"))
	var zr := InputEventJoypadMotion.new()
	zr.axis = JOY_AXIS_TRIGGER_RIGHT
	zr.axis_value = 1.0
	assert_true(zr.is_action("zoom_acercar"))


func test_reasignacion_y_serializacion() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	var data := InputBindings.serialize(key)
	InputBindings.apply("xbox", {"pausa": [data]})
	var events := InputMap.action_get_events("pausa")
	assert_eq(events.size(), 1)
	assert_eq(events[0].physical_keycode, KEY_J)
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_Y
	axis.axis_value = -0.8
	var back := InputBindings.deserialize(InputBindings.serialize(axis))
	assert_eq(back.axis, JOY_AXIS_LEFT_Y)
	assert_eq(back.axis_value, -1.0)
	assert_eq(InputBindings.deserialize({"tipo": "desconocido"}), null)
	InputBindings.apply("nintendo")


func test_clasificacion_de_mandos() -> void:
	assert_eq(InputBindings.classify("Nintendo Switch Pro Controller"), "pro")
	assert_eq(InputBindings.classify("Joy-Con (L)"), "joycon_izq")
	assert_eq(InputBindings.classify("Joy-Con (R)"), "joycon_der")
	assert_eq(InputBindings.classify("Joy-Con (L/R)"), "joycon_par")
	assert_eq(InputBindings.classify("Nintendo Switch Joy-Con Left"), "joycon_izq")
	assert_eq(InputBindings.classify("Xbox Series Controller"), "xbox")
	assert_eq(InputBindings.classify("DualSense Wireless Controller"), "playstation")
	assert_eq(InputBindings.classify("USB Gamepad"), "generico")
	assert_true(InputBindings.is_single_joycon("joycon_izq"))
	assert_eq(InputBindings.layout_for("xbox", "auto", false), "xbox")
	assert_eq(InputBindings.layout_for("pro", "auto", false), "nintendo")
	assert_eq(InputBindings.layout_for("xbox", "auto", true), "nintendo", "en la consola siempre Nintendo")
	assert_eq(InputBindings.layout_for("pro", "xbox", false), "xbox", "el ajuste manual manda")


func test_indicaciones_y_modo_de_entrada() -> void:
	assert_eq(InputBindings.glyph("ui_accept", "mando", "nintendo"), "A")
	assert_eq(InputBindings.glyph("zoom_acercar", "mando", "nintendo"), "ZR")
	assert_eq(InputBindings.glyph("inventario", "mando", "nintendo"), "−")
	assert_eq(InputBindings.glyph("seccion_siguiente", "mando", "xbox"), "RB")
	assert_eq(InputBindings.glyph("ui_cancel", "teclado", "nintendo"), "Esc")
	assert_eq(InputBindings.glyph("ui_accept", "tactil", "nintendo"), "")
	var touch := InputEventScreenTouch.new()
	assert_eq(InputBindings.mode_of(touch), "tactil")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	assert_eq(InputBindings.mode_of(emulated), "", "el ratón emulado desde el táctil no cambia el modo")
	var weak := InputEventJoypadMotion.new()
	weak.axis_value = 0.1
	assert_eq(InputBindings.mode_of(weak), "", "la deriva del stick no cambia el modo")


func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	return e


func _drag(index: int, pos: Vector2, rel: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	return e


func test_gestos_tactiles() -> void:
	var g := GestureRecognizer.new()
	g.feed(_touch(0, Vector2(100, 100), true), 0.0)
	var r := g.feed(_drag(0, Vector2(140, 100), Vector2(40, 0)), 0.05)
	assert_eq(r["rotar"], Vector2(40, 0), "un dedo rota")
	g.feed(_touch(0, Vector2(140, 100), false), 0.1)
	g.feed(_touch(0, Vector2(100, 100), true), 1.0)
	g.feed(_touch(1, Vector2(200, 100), true), 1.0)
	r = g.feed(_drag(1, Vector2(300, 100), Vector2(100, 0)), 1.1)
	assert_almost(r["zoom"], 2.0, 0.001, "separar dos dedos amplía al doble")
	g.feed(_touch(1, Vector2(300, 100), false), 1.2)
	g.feed(_touch(0, Vector2(100, 100), false), 1.2)
	g.reset()
	g.feed(_touch(0, Vector2(50, 50), true), 2.0)
	r = g.feed(_touch(0, Vector2(52, 50), false), 2.1)
	assert_eq(r["toque"], Vector2(52, 50), "un toque corto selecciona")
	g.feed(_touch(0, Vector2(52, 50), true), 2.2)
	r = g.feed(_touch(0, Vector2(52, 51), false), 2.3)
	assert_true(r["doble_toque"], "dos toques rápidos restablecen la vista")


func test_resolucion_dinamica() -> void:
	var d := DynamicResolution.new()
	d.configure(60.0, 0.7, 1.0)
	for i in 120:
		d.push(25.0, 1.0 / 60.0)
	assert_true(d.scale < 1.0, "con cuadros lentos baja la escala")
	assert_true(d.scale >= 0.7)
	for i in 2000:
		d.push(25.0, 1.0 / 60.0)
	assert_almost(d.scale, 0.7, 0.001, "nunca baja del mínimo")
	for i in 2000:
		d.push(8.0, 1.0 / 60.0)
	assert_almost(d.scale, 1.0, 0.001, "con margen vuelve al máximo")
	var before := d.scale
	for i in 300:
		d.push(15.5, 1.0 / 60.0)
	assert_eq(d.scale, before, "dentro de la banda objetivo no cambia")


func test_medidor_de_rendimiento() -> void:
	var p := PerfProbe.new()
	for i in 99:
		p.add(16.0, 100, 50000)
	p.add(40.0, 120, 60000)
	var r := p.report()
	assert_eq(r["cuadros"], 100)
	assert_almost(r["ms_p50"], 16.0)
	assert_almost(r["ms_p99"], 16.0)
	assert_almost(r["fps_1pct_bajo"], 25.0)
	assert_eq(r["cuadros_sobre_16_7ms"], 1)
	assert_eq(r["llamadas_dibujo_max"], 120)


func test_modo_por_tamano_y_perfiles() -> void:
	assert_eq(load("res://src/platform/platform_bridge.gd").mode_for_size(Vector2i(1280, 720)), "portatil")
	assert_eq(load("res://src/platform/platform_bridge.gd").mode_for_size(Vector2i(1920, 1080)), "sobremesa")
	var q := QualityProfiles.new()
	q.load_file("res://data/config/calidad.json")
	assert_eq(q.errors, [])
	var docked := q.get_profile("sobremesa")
	var handheld := q.get_profile("portatil")
	assert_eq(docked["resolucion"], [1920, 1080])
	assert_eq(handheld["resolucion"], [1280, 720])
	assert_eq(int(docked["fps_objetivo"]), 60)
	assert_eq(int(handheld["fps_objetivo"]), 60)
	assert_true(handheld["sombra_tamano"] <= docked["sombra_tamano"])
	assert_true(handheld["segmentos_radiales"] <= docked["segmentos_radiales"])
	assert_eq(QualityProfiles.resolve_mode("auto", "portatil"), "portatil")
	assert_eq(QualityProfiles.resolve_mode("sobremesa", "portatil"), "sobremesa")


func test_port_homebrew_informa_los_botones_por_letra() -> void:
	assert_true(InputBindings.is_label_pad("switch-pad"))
	assert_false(InputBindings.is_label_pad("030000007e0500000920000011810000"), "un mando por SDL en PC")
	assert_eq(InputBindings.layout_for("pro", "xbox", true, true), "switch", "en el port la disposición es fija")
	assert_eq(InputBindings.face_button("A", "switch"), JOY_BUTTON_A)
	assert_eq(InputBindings.face_button("B", "switch"), JOY_BUTTON_B)
	assert_eq(InputBindings.face_button("X", "switch"), JOY_BUTTON_X)
	assert_eq(InputBindings.face_button("Y", "switch"), JOY_BUTTON_Y)
	assert_eq(InputBindings.glyph("seccion_siguiente", "mando", "switch"), "R")
	assert_eq(InputBindings.glyph("inventario", "mando", "switch"), "−")
	InputBindings.apply("switch")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	assert_true(a.is_action("ui_accept"), "la A de Nintendo llega como JOY_BUTTON_A y confirma")
	assert_false(a.is_action("ui_cancel"))
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	assert_true(b.is_action("ui_cancel"), "la B cancela")
	var zl := InputEventJoypadMotion.new()
	zl.axis = JOY_AXIS_TRIGGER_LEFT
	zl.axis_value = 1.0
	assert_true(zl.is_action("zoom_alejar"), "ZL llega como gatillo a 1,0")
	InputBindings.apply("nintendo")
	var platform: Node = load("res://src/platform/platform_bridge.gd").new()
	assert_false(platform.is_switch_homebrew(), "en PC no es el port homebrew")
	assert_true(platform.can_quit())
	platform.free()
