class_name Settings
extends RefCounted
## Ajustes del jugador (se guardan con la partida).

signal changed(key: String)

const DEFAULTS := {
	"escala_texto": 1.0,             ## 1.0, 1.15 o 1.3
	"disposicion_botones": "auto",   ## auto | nintendo | xbox
	"invertir_rotacion": false,
	"sensibilidad_rotacion": 1.0,
	"vibracion": true,
	"perfil_calidad": "auto",        ## auto | sobremesa | portatil
	"mostrar_rendimiento": false,
	"volumen_musica": 0.8,
	"volumen_efectos": 0.8,
	"controles": {},                 ## acción -> lista de eventos reasignados
}

var values: Dictionary = DEFAULTS.duplicate(true)


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("Ajuste desconocido: %s" % key)
		return
	if values.get(key) == value:
		return
	values[key] = value
	changed.emit(key)


func reset() -> void:
	values = DEFAULTS.duplicate(true)
	changed.emit("")


func to_dict() -> Dictionary:
	return values.duplicate(true)


func load_dict(d: Dictionary) -> void:
	values = DEFAULTS.duplicate(true)
	for key in d:
		if DEFAULTS.has(key) and typeof(d[key]) == typeof(DEFAULTS[key]) or \
				(DEFAULTS.has(key) and typeof(DEFAULTS[key]) == TYPE_FLOAT and typeof(d[key]) == TYPE_INT):
			values[key] = d[key]
	changed.emit("")
