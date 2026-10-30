extends Node
## Puente con la plataforma (autoload "Platform").
##
## En PC se simulan los dos modos de Nintendo Switch: "sobremesa" (televisor, hasta 1920×1080) y
## "portatil" (pantalla de la consola, 1280×720). El modo se deduce del tamaño de la ventana o se
## fuerza con `-- --modo=portatil|sobremesa`.
##
## En la consola, la detección del modo y la confirmación de los datos guardados dependen de la API
## del port autorizado de Godot para Switch, que no forma parte de este repositorio (ver
## docs/06-nintendo-switch.md). Si ese port expone un singleton con el nombre configurado en
## CONSOLE_SINGLETON, se usa; si no, se aplican las mismas reglas que en PC.

signal operation_mode_changed(mode: String)

const MODES: Array[String] = ["sobremesa", "portatil"]
const MODE_NAMES := {"sobremesa": "Modo sobremesa (TV)", "portatil": "Modo portátil"}
## Nombre del singleton del port de consola. Debe confirmarse con el proveedor del port.
const CONSOLE_SINGLETON := "SwitchPlatform"

var operation_mode := "sobremesa"
var forced_mode := ""
var _poll := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--modo="):
			var m := arg.trim_prefix("--modo=")
			if MODES.has(m):
				forced_mode = m
	operation_mode = detect_operation_mode()


func _process(delta: float) -> void:
	_poll += delta
	if _poll < 0.5:
		return
	_poll = 0.0
	var m := detect_operation_mode()
	if m != operation_mode:
		operation_mode = m
		operation_mode_changed.emit(m)


func is_console() -> bool:
	return Engine.has_singleton(CONSOLE_SINGLETON)


func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func force_mode(mode: String) -> void:
	forced_mode = mode if MODES.has(mode) else ""
	var m := detect_operation_mode()
	if m != operation_mode:
		operation_mode = m
		operation_mode_changed.emit(m)


func detect_operation_mode() -> String:
	if not forced_mode.is_empty():
		return forced_mode
	if is_console():
		var console := Engine.get_singleton(CONSOLE_SINGLETON)
		if console.has_method("get_operation_mode"):
			return "portatil" if str(console.get_operation_mode()) in ["handheld", "portatil"] else "sobremesa"
	if is_headless():
		return "sobremesa"
	return mode_for_size(DisplayServer.window_get_size())


static func mode_for_size(size: Vector2i) -> String:
	return "portatil" if size.y <= 720 else "sobremesa"


## Confirma los datos guardados en plataformas que lo exigen (en Switch, el sistema de archivos
## de datos de guardado requiere confirmar cada escritura). En PC no hace nada.
func commit_save_data() -> void:
	if is_console():
		var console := Engine.get_singleton(CONSOLE_SINGLETON)
		if console.has_method("commit_save_data"):
			console.commit_save_data()


func platform_name() -> String:
	return "Nintendo Switch" if is_console() else OS.get_name()
