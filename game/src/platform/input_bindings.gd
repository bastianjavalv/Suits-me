class_name InputBindings
extends RefCounted
## Mapa de controles para Joy-Con, Nintendo Switch Pro Controller, teclado y ratón.
##
## Godot nombra los botones del mando por su POSICIÓN (JOY_BUTTON_A = botón inferior). En los
## mandos de Nintendo el botón con la letra A está a la derecha, B abajo, X arriba e Y a la
## izquierda. Este módulo asigna las acciones por la LETRA que ve el jugador:
##
##   Acción                 Nintendo (letra / posición)   Xbox (letra / posición)
##   Confirmar              A / derecha                    A / abajo
##   Cancelar               B / abajo                      B / derecha
##   Opciones de vestuario  X / arriba                     X / izquierda
##   Cambiar categoría      Y / izquierda                  Y / arriba
##
## El port homebrew de Godot para Switch (switch/motor) es la excepción: informa los botones por su
## LETRA (A de Nintendo = JOY_BUTTON_A). Para él existe la disposición interna "switch": letras sin
## conversión e indicaciones de Nintendo.

const DEADZONE := 0.25
## GUID con el que el port homebrew de Switch registra el mando del jugador 1.
const LABEL_PAD_GUID := "switch-pad"
const TRIGGER_THRESHOLD := 0.3

## Acciones propias del juego, con su descripción para el menú de controles.
const ACTIONS := {
	"rotar_izquierda": "Rotar personaje a la izquierda",
	"rotar_derecha": "Rotar personaje a la derecha",
	"inclinar_arriba": "Inclinar cámara hacia arriba",
	"inclinar_abajo": "Inclinar cámara hacia abajo",
	"zoom_acercar": "Acercar (zoom)",
	"zoom_alejar": "Alejar (zoom)",
	"opciones_prenda": "Opciones de vestuario",
	"cambiar_categoria": "Cambiar categoría",
	"seccion_anterior": "Sección anterior",
	"seccion_siguiente": "Sección siguiente",
	"pausa": "Pausa",
	"inventario": "Inventario",
	"modo_rotacion": "Alternar rotación con el stick izquierdo (Joy-Con individual)",
}

## Acciones de interfaz de Godot a las que se añaden los controles de Switch.
const UI_ACTIONS: Array[String] = ["ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right"]

const LAYOUTS: Array[String] = ["nintendo", "xbox"]


static func face_button(letter: String, layout: String) -> JoyButton:
	if layout == "nintendo":
		match letter:
			"A": return JOY_BUTTON_B   # derecha
			"B": return JOY_BUTTON_A   # abajo
			"X": return JOY_BUTTON_Y   # arriba
			"Y": return JOY_BUTTON_X   # izquierda
	else:
		# "xbox" y "switch": el índice del botón coincide con su letra.
		match letter:
			"A": return JOY_BUTTON_A
			"B": return JOY_BUTTON_B
			"X": return JOY_BUTTON_X
			"Y": return JOY_BUTTON_Y
	return JOY_BUTTON_INVALID


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = -1
	return e


static func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	e.device = -1
	return e


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


## Eventos predeterminados por acción para la disposición indicada.
static func default_events(layout: String) -> Dictionary:
	return {
		"ui_accept": [_joy_button(face_button("A", layout)), _key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE)],
		"ui_cancel": [_joy_button(face_button("B", layout)), _key(KEY_ESCAPE), _key(KEY_BACKSPACE)],
		"ui_up": [_joy_button(JOY_BUTTON_DPAD_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0), _key(KEY_UP), _key(KEY_W)],
		"ui_down": [_joy_button(JOY_BUTTON_DPAD_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0), _key(KEY_DOWN), _key(KEY_S)],
		"ui_left": [_joy_button(JOY_BUTTON_DPAD_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0), _key(KEY_LEFT), _key(KEY_A)],
		"ui_right": [_joy_button(JOY_BUTTON_DPAD_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0), _key(KEY_RIGHT), _key(KEY_D)],
		"rotar_izquierda": [_joy_axis(JOY_AXIS_RIGHT_X, -1.0), _key(KEY_Q)],
		"rotar_derecha": [_joy_axis(JOY_AXIS_RIGHT_X, 1.0), _key(KEY_E)],
		"inclinar_arriba": [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0), _key(KEY_R)],
		"inclinar_abajo": [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0), _key(KEY_F)],
		"zoom_acercar": [_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0), _key(KEY_X), _mouse(MOUSE_BUTTON_WHEEL_UP)],
		"zoom_alejar": [_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), _key(KEY_Z), _mouse(MOUSE_BUTTON_WHEEL_DOWN)],
		"opciones_prenda": [_joy_button(face_button("X", layout)), _key(KEY_C)],
		"cambiar_categoria": [_joy_button(face_button("Y", layout)), _key(KEY_TAB)],
		"seccion_anterior": [_joy_button(JOY_BUTTON_LEFT_SHOULDER), _key(KEY_1), _key(KEY_PAGEUP)],
		"seccion_siguiente": [_joy_button(JOY_BUTTON_RIGHT_SHOULDER), _key(KEY_2), _key(KEY_PAGEDOWN)],
		"pausa": [_joy_button(JOY_BUTTON_START), _key(KEY_P), _key(KEY_F10)],
		"inventario": [_joy_button(JOY_BUTTON_BACK), _key(KEY_I)],
		"modo_rotacion": [_joy_button(JOY_BUTTON_LEFT_STICK), _key(KEY_V)],
	}


## Aplica los controles al InputMap. `overrides`: acción -> lista de eventos serializados.
static func apply(layout: String, overrides: Dictionary = {}) -> void:
	var defaults := default_events(layout)
	for action in defaults:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		else:
			InputMap.action_set_deadzone(action, DEADZONE)
		InputMap.action_erase_events(action)
		var events: Array = defaults[action]
		if overrides.has(action):
			var custom: Array = []
			for d in overrides[action]:
				var ev := deserialize(d)
				if ev != null:
					custom.append(ev)
			if not custom.is_empty():
				events = custom
		for ev in events:
			InputMap.action_add_event(action, ev)


static func serialize(e: InputEvent) -> Dictionary:
	if e is InputEventKey:
		return {"tipo": "tecla", "codigo": int(e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode)}
	if e is InputEventJoypadButton:
		return {"tipo": "boton", "boton": int(e.button_index)}
	if e is InputEventJoypadMotion:
		return {"tipo": "eje", "eje": int(e.axis), "signo": 1 if e.axis_value >= 0.0 else -1}
	if e is InputEventMouseButton:
		return {"tipo": "raton", "boton": int(e.button_index)}
	return {}


static func deserialize(d: Dictionary) -> InputEvent:
	match str(d.get("tipo", "")):
		"tecla":
			return _key(int(d.get("codigo", 0)) as Key)
		"boton":
			return _joy_button(int(d.get("boton", -1)) as JoyButton)
		"eje":
			return _joy_axis(int(d.get("eje", 0)) as JoyAxis, float(d.get("signo", 1)))
		"raton":
			return _mouse(int(d.get("boton", 1)) as MouseButton)
	return null


## Clasifica un mando por el nombre que informa el sistema.
static func classify(joy_name: String) -> String:
	var n := joy_name.to_lower()
	if n.contains("pro controller"):
		return "pro"
	if n.contains("joy-con") or n.contains("joycon"):
		var left := n.contains("(l)") or n.contains("left")
		var right := n.contains("(r)") or n.contains("right")
		if n.contains("l/r") or n.contains("(l)+(r)") or n.contains("dual") or (left and right):
			return "joycon_par"
		if left:
			return "joycon_izq"
		if right:
			return "joycon_der"
		return "joycon_par"
	if n.contains("nintendo") or n.contains("switch"):
		return "pro"
	if n.contains("xbox") or n.contains("xinput"):
		return "xbox"
	if n.contains("playstation") or n.contains("dualsense") or n.contains("dualshock") or n.contains("ps4") \
			or n.contains("ps5"):
		return "playstation"
	return "generico"


## `by_label`: el sistema informa los botones por su letra (port homebrew de Switch). La disposición
## física es fija, así que el ajuste manual no se aplica.
static func layout_for(profile: String, setting: String, on_console: bool, by_label := false) -> String:
	if by_label:
		return "switch"
	if setting == "nintendo" or setting == "xbox":
		return setting
	if on_console or profile in ["pro", "joycon_par", "joycon_izq", "joycon_der"]:
		return "nintendo"
	return "xbox"


static func is_single_joycon(profile: String) -> bool:
	return profile == "joycon_izq" or profile == "joycon_der"


static func is_label_pad(joy_guid: String) -> bool:
	return joy_guid == LABEL_PAD_GUID


## Texto del botón que se muestra en las indicaciones de pantalla.
static func glyph(action: String, mode: String, layout: String) -> String:
	if mode == "teclado" or mode == "raton":
		return {
			"ui_accept": "Intro", "ui_cancel": "Esc", "opciones_prenda": "C", "cambiar_categoria": "Tab",
			"seccion_anterior": "1", "seccion_siguiente": "2", "zoom_acercar": "X", "zoom_alejar": "Z",
			"pausa": "P", "inventario": "I", "rotar_izquierda": "Q", "rotar_derecha": "E", "modo_rotacion": "V",
		}.get(action, "")
	if mode == "tactil":
		return ""
	if layout == "nintendo" or layout == "switch":
		return {
			"ui_accept": "A", "ui_cancel": "B", "opciones_prenda": "X", "cambiar_categoria": "Y",
			"seccion_anterior": "L", "seccion_siguiente": "R", "zoom_acercar": "ZR", "zoom_alejar": "ZL",
			"pausa": "+", "inventario": "−", "rotar_izquierda": "Stick R", "rotar_derecha": "Stick R",
			"modo_rotacion": "Pulsar stick L",
		}.get(action, "")
	return {
		"ui_accept": "A", "ui_cancel": "B", "opciones_prenda": "X", "cambiar_categoria": "Y",
		"seccion_anterior": "LB", "seccion_siguiente": "RB", "zoom_acercar": "RT", "zoom_alejar": "LT",
		"pausa": "Menú", "inventario": "Vista", "rotar_izquierda": "Stick R", "rotar_derecha": "Stick R",
		"modo_rotacion": "Pulsar stick L",
	}.get(action, "")


## Modo de entrada que representa un evento: "tactil", "mando", "teclado", "raton" o "" (ignorar).
static func mode_of(event: InputEvent) -> String:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "tactil"
	if event is InputEventJoypadButton:
		return "mando"
	if event is InputEventJoypadMotion:
		return "mando" if absf(event.axis_value) > 0.5 else ""
	if event is InputEventKey:
		return "teclado"
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		return "" if event.device == InputEvent.DEVICE_ID_EMULATION else "raton"
	return ""
