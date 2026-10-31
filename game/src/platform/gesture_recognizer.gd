class_name GestureRecognizer
extends RefCounted
## Gestos táctiles del modo portátil: un dedo rota la cámara, dos dedos hacen zoom (pellizco),
## un toque selecciona y un doble toque restablece la vista.

const TAP_MAX_MOVE := 14.0
const TAP_MAX_TIME := 0.3
const DOUBLE_TAP_TIME := 0.35

var touches: Dictionary = {}  ## índice -> {pos, start, t0, moved}
var _last_tap_time := -INF
var _last_tap_pos := Vector2.ZERO


## Procesa un evento y devuelve {"rotar": Vector2, "zoom": float (factor, 1 = sin cambio),
## "toque": Vector2 o null, "doble_toque": bool}.
func feed(event: InputEvent, now: float) -> Dictionary:
	var out := {"rotar": Vector2.ZERO, "zoom": 1.0, "toque": null, "doble_toque": false}
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			touches[touch.index] = {"pos": touch.position, "start": touch.position, "t0": now, "moved": 0.0}
		elif touches.has(touch.index):
			var t: Dictionary = touches[touch.index]
			touches.erase(touch.index)
			if touches.is_empty() and t["moved"] <= TAP_MAX_MOVE and now - t["t0"] <= TAP_MAX_TIME:
				if now - _last_tap_time <= DOUBLE_TAP_TIME and touch.position.distance_to(_last_tap_pos) < 40.0:
					out["doble_toque"] = true
					_last_tap_time = -INF
				else:
					out["toque"] = touch.position
					_last_tap_time = now
					_last_tap_pos = touch.position
	elif event is InputEventScreenDrag and touches.has(event.index):
		var drag := event as InputEventScreenDrag
		var t: Dictionary = touches[drag.index]
		if touches.size() == 1:
			out["rotar"] = drag.relative
		elif touches.size() == 2:
			var other_pos := Vector2.ZERO
			for idx in touches:
				if idx != drag.index:
					other_pos = touches[idx]["pos"]
			var before: float = (t["pos"] as Vector2).distance_to(other_pos)
			var after: float = drag.position.distance_to(other_pos)
			if before > 1.0:
				out["zoom"] = after / before
		t["moved"] = float(t["moved"]) + drag.relative.length()
		t["pos"] = drag.position
	return out


func reset() -> void:
	touches.clear()
