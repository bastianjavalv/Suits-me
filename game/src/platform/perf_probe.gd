class_name PerfProbe
extends RefCounted
## Mide el rendimiento real cuadro a cuadro: FPS medio, percentiles de tiempo de cuadro,
## "1 % bajo", llamadas de dibujo y primitivas.

var frame_ms: Array[float] = []
var draw_calls: Array[int] = []
var primitives: Array[int] = []


func add(ms: float, calls: int = -1, prims: int = -1) -> void:
	frame_ms.append(ms)
	if calls >= 0:
		draw_calls.append(calls)
	if prims >= 0:
		primitives.append(prims)


func sample_engine(delta: float) -> void:
	add(delta * 1000.0,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))


static func percentile(values: Array, p: float) -> float:
	if values.is_empty():
		return 0.0
	var s := values.duplicate()
	s.sort()
	var idx := clampi(ceili(p / 100.0 * s.size()) - 1, 0, s.size() - 1)
	return float(s[idx])


func report() -> Dictionary:
	if frame_ms.is_empty():
		return {"cuadros": 0}
	var total := 0.0
	for v in frame_ms:
		total += v
	var avg_ms := total / frame_ms.size()
	var worst := frame_ms.duplicate()
	worst.sort()
	worst.reverse()
	var n_low := maxi(1, frame_ms.size() / 100)
	var low_total := 0.0
	for i in n_low:
		low_total += worst[i]
	var r := {
		"cuadros": frame_ms.size(),
		"fps_medio": snappedf(1000.0 / avg_ms, 0.1),
		"ms_medio": snappedf(avg_ms, 0.01),
		"ms_p50": snappedf(percentile(frame_ms, 50.0), 0.01),
		"ms_p95": snappedf(percentile(frame_ms, 95.0), 0.01),
		"ms_p99": snappedf(percentile(frame_ms, 99.0), 0.01),
		"fps_1pct_bajo": snappedf(1000.0 / (low_total / n_low), 0.1),
		"cuadros_sobre_16_7ms": frame_ms.filter(func(v): return v > 1000.0 / 60.0).size(),
	}
	if not draw_calls.is_empty():
		r["llamadas_dibujo_max"] = draw_calls.max()
		r["primitivas_max"] = primitives.max() if not primitives.is_empty() else 0
	return r
