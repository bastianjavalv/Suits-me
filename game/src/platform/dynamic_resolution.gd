class_name DynamicResolution
extends RefCounted
## Escalado dinámico de la resolución 3D para sostener el objetivo de cuadros por segundo.
## Baja la escala si el tiempo de cuadro supera el objetivo durante 0,5 s y la sube si sobra
## margen durante 2 s. La interfaz 2D siempre se dibuja a resolución completa.

var target_ms := 1000.0 / 60.0
var min_scale := 0.7
var max_scale := 1.0
var step := 0.05
var scale := 1.0
var average_ms := 0.0
var _over := 0.0
var _under := 0.0
var _primed := false


func configure(target_fps: float, p_min: float, p_max: float) -> void:
	target_ms = 1000.0 / maxf(target_fps, 1.0)
	min_scale = p_min
	max_scale = p_max
	scale = clampf(scale, min_scale, max_scale)


## Registra el tiempo del último cuadro (ms) y devuelve la escala que debe aplicarse.
func push(frame_ms: float, delta: float) -> float:
	if not _primed:
		average_ms = frame_ms
		_primed = true
	else:
		average_ms = lerpf(average_ms, frame_ms, 0.1)
	if average_ms > target_ms * 1.05:
		_over += delta
		_under = 0.0
		if _over >= 0.5:
			scale = maxf(min_scale, snappedf(scale - step, 0.01))
			_over = 0.0
	elif average_ms < target_ms * 0.85:
		_under += delta
		_over = 0.0
		if _under >= 2.0:
			scale = minf(max_scale, snappedf(scale + step, 0.01))
			_under = 0.0
	else:
		_over = 0.0
		_under = 0.0
	return scale
