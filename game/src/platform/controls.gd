extends Node
## Controles (autoload "Controls"): aplica el mapa de botones, detecta mandos y el último tipo de
## entrada usado (mando, táctil, teclado o ratón) para adaptar las indicaciones en pantalla.

signal input_mode_changed(mode: String)
signal controller_changed(profile: String)

var input_mode := "mando"
var controller_profile := "generico"
var layout := "nintendo"
## Con un Joy-Con individual no hay stick derecho: el stick izquierdo alterna entre navegar y rotar.
var stick_rotates := false
## El mando informa los botones por su letra (port homebrew de Switch).
var pad_by_label := false
var _setting_layout := "auto"
var _overrides: Dictionary = {}


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_controller()
	apply_bindings()


func configure(setting_layout: String, overrides: Dictionary) -> void:
	_setting_layout = setting_layout
	_overrides = overrides
	apply_bindings()


func apply_bindings() -> void:
	var platform := get_node_or_null("/root/Platform")
	var on_console: bool = platform != null and platform.is_console()
	var by_label: bool = pad_by_label or (platform != null and platform.is_switch_homebrew())
	layout = InputBindings.layout_for(controller_profile, _setting_layout, on_console, by_label)
	InputBindings.apply(layout, _overrides)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_controller()
	apply_bindings()


func _refresh_controller() -> void:
	var pads := Input.get_connected_joypads()
	var profile := "generico"
	pad_by_label = false
	if not pads.is_empty():
		profile = InputBindings.classify(Input.get_joy_name(pads[0]))
		pad_by_label = InputBindings.is_label_pad(Input.get_joy_guid(pads[0]))
	if profile != controller_profile:
		controller_profile = profile
		if not InputBindings.is_single_joycon(profile):
			stick_rotates = false
		controller_changed.emit(profile)


func _input(event: InputEvent) -> void:
	var mode := InputBindings.mode_of(event)
	if not mode.is_empty() and mode != input_mode:
		input_mode = mode
		input_mode_changed.emit(mode)
	if event.is_action_pressed("modo_rotacion"):
		stick_rotates = not stick_rotates


func glyph(action: String) -> String:
	return InputBindings.glyph(action, input_mode, layout)


func is_touch() -> bool:
	return input_mode == "tactil"


func rebind(action: String, event: InputEvent) -> void:
	var data := InputBindings.serialize(event)
	if data.is_empty():
		return
	_overrides[action] = [data]
	apply_bindings()


func reset_bindings() -> void:
	_overrides = {}
	apply_bindings()


func overrides() -> Dictionary:
	return _overrides.duplicate(true)
