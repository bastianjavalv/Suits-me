class_name CameraRig
extends Node3D
## Cámara de estudio: zoom de cuerpo entero a primer plano y encuadre vertical (inspección de
## prendas). La rotación de 360° la hace el maniquí (plataforma giratoria).

var camera: Camera3D
var zoom := 0.0            ## 0 = cuerpo entero, 1 = primer plano
var focus_height := 0.0    ## desplazamiento vertical del encuadre (-1 pies, +1 cabeza)
var pitch := -4.0
var _zoom_shown := 0.0
var _focus_shown := 0.0
var _pitch_shown := -4.0
var offset_x := 0.0        ## desplaza el encuadre a un lado cuando un panel cubre la pantalla


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.near = 0.05
	camera.far = 30.0
	add_child(camera)
	_apply(1.0)


func zoom_by(amount: float) -> void:
	zoom = clampf(zoom + amount, 0.0, 1.0)


func pan_by(amount: float) -> void:
	focus_height = clampf(focus_height + amount, -1.0, 1.0)


func tilt_by(degrees: float) -> void:
	pitch = clampf(pitch + degrees, -20.0, 25.0)


func reset() -> void:
	zoom = 0.0
	focus_height = 0.0
	pitch = -4.0


## Encuadra una altura concreta del cuerpo (por ejemplo, la de una prenda) con zoom.
func inspect(height: float, amount: float = 0.6) -> void:
	zoom = amount
	focus_height = clampf((height - 0.95) / 0.75, -1.0, 1.0)


func _process(delta: float) -> void:
	_apply(1.0 - exp(-delta * 8.0))


func _apply(k: float) -> void:
	if camera == null:
		return
	_zoom_shown = lerpf(_zoom_shown, zoom, k)
	_focus_shown = lerpf(_focus_shown, focus_height, k)
	_pitch_shown = lerpf(_pitch_shown, pitch, k)
	var distance := lerpf(4.6, 1.15, _zoom_shown)
	var target := Vector3(offset_x * distance * 0.22, 0.95 + _focus_shown * lerpf(0.35, 0.75, _zoom_shown), 0.0)
	var dir := Vector3(0, sin(deg_to_rad(-_pitch_shown)), cos(deg_to_rad(_pitch_shown)))
	camera.position = target + dir * distance
	camera.look_at(target, Vector3.UP)
