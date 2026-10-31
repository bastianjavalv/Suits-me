class_name Screen
extends Control
## Base de las pantallas: construcción, foco inicial, «Atrás» e indicaciones de botones.

var app: Node
## Si es true, la cámara y el maniquí responden a los controles mientras la pantalla está activa.
var allows_camera := false
## Si es true, la pantalla tapa el mundo 3D (no hace falta renderizarlo detrás).
var opaque := false


func setup(p_app: Node, args: Dictionary = {}) -> void:
	app = p_app
	# Ya está en el árbol: hay que fijar anclas y márgenes a la vez; set_anchors_preset() conservaría
	# el rectángulo actual (0×0) y todas las pantallas se maquetarían contra un padre vacío.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	build(args)


func build(_args: Dictionary) -> void:
	pass


## Control que recibe el foco al mostrarse.
func default_focus() -> Control:
	return null


func on_shown() -> void:
	var c := default_focus()
	if c != null and c.is_inside_tree() and c.visible:
		c.grab_focus.call_deferred()


## Devuelve true si la pantalla gestionó «Atrás» por sí misma.
func on_cancel() -> bool:
	return false


## Indicaciones [[acción, texto], ...] para la barra inferior.
func prompts() -> Array:
	return [["ui_accept", "Elegir"], ["ui_cancel", "Atrás"]]


## Pantallas que reaccionan a acciones globales (categoría, secciones, opciones...).
func on_action(_action: String) -> bool:
	return false


func refresh() -> void:
	pass
