class_name FabricLibrary
extends RefCounted
## Crea y reutiliza los materiales PBR de cada prenda según su tejido (res://data/tejidos.json),
## sus colores, su estampado y el papel de la pieza (principal, secundario, metal, perla…).

const TELA := preload("res://shaders/tela.gdshader")
const CALADA := preload("res://shaders/tela_calada.gdshader")
const MANIQUI := preload("res://shaders/maniqui.gdshader")

const WEAVES := {"tafetan": 0, "sarga": 1, "raso": 2, "punto": 3, "ninguno": -1}
const PATTERNS := {"liso": 0, "lunares": 1, "rayas": 2, "cuadros": 3, "tartan": 4, "floral": 5, "deco": 6,
	"op_art": 7, "reticula": 8, "damasco": 9, "leopardo": 10, "pata_de_gallo": 11, "diplomatica": 12}
const FINISHES := {"normal": 0, "lentejuelas": 1, "cuero": 2, "pelo": 3, "brocado": 4}
const SHEERS := {"encaje": 0, "tul": 1, "gasa": 2, "flecos": 3, "velo": 4}
const METALS := {"oro": Color(1.0, 0.78, 0.36), "plata": Color(0.93, 0.93, 0.95), "bronce": Color(0.8, 0.55, 0.36),
	"laton": Color(0.92, 0.76, 0.42), "acero": Color(0.62, 0.63, 0.65)}

var fabrics: Dictionary = {}
var _cache: Dictionary = {}


func _init(p_fabrics: Dictionary = {}) -> void:
	fabrics = p_fabrics


func material_for(item: Dictionary, role: String) -> Material:
	var key := "%s|%s|%s|%s|%s|%s" % [item.get("tejido", ""), item.get("color", ""), item.get("color_secundario", ""),
		item.get("estampado", "liso"), item.get("metal", "oro"), role]
	if _cache.has(key):
		return _cache[key]
	var main := Color.html(str(item.get("color", "#cccccc")))
	var second := Color.html(str(item.get("color_secundario", item.get("color", "#333333"))))
	var m: Material
	match role:
		"principal", "forro":
			m = fabric_material(str(item.get("tejido", "algodon")), main, second, str(item.get("estampado", "liso")))
			if role == "forro" and m is ShaderMaterial:
				m.set_shader_parameter("color_principal", main.darkened(0.25))
		"secundario":
			m = fabric_material(str(item.get("tejido_secundario", "saten")), second, second, "liso")
		"cabello":
			m = hair_material(main)
		"suela":
			m = _standard(Color.html(str(item.get("color_suela", "#1d1a18"))), 0.55, 0.0)
		"metal", "boton":
			var metal: Color = METALS.get(str(item.get("metal", "oro")), METALS["oro"])
			m = _standard(metal, 0.28, 1.0)
		"perla":
			var pearl := _standard(main if item.get("categoria", "") == "joyeria" else Color(0.95, 0.93, 0.88), 0.22, 0.0)
			pearl.clearcoat_enabled = true
			pearl.clearcoat = 0.8
			pearl.rim_enabled = true
			pearl.rim = 0.35
			m = pearl
		"lente":
			var lens := _standard(second, 0.05, 0.0)
			lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			lens.albedo_color.a = 0.55
			m = lens
		"velo":
			m = fabric_material("tul", second if item.has("color_secundario") else Color(0.97, 0.96, 0.94), second, "liso")
		_:
			m = fabric_material(str(item.get("tejido", "algodon")), main, second, "liso")
	_cache[key] = m
	return m


func fabric_material(fabric_id: String, main: Color, second: Color, pattern: String) -> ShaderMaterial:
	var f: Dictionary = fabrics.get(fabric_id, {})
	var m := ShaderMaterial.new()
	if str(f.get("shader", "tela")) == "calada":
		m.shader = CALADA
		m.set_shader_parameter("color_principal", main)
		m.set_shader_parameter("tipo", SHEERS.get(str(f.get("tipo", "tul")), 1))
		m.set_shader_parameter("opacidad", float(f.get("opacidad", 0.6)))
		m.set_shader_parameter("escala", float(f.get("escala", 90.0)))
		m.set_shader_parameter("rugosidad", float(f.get("rugosidad", 0.7)))
		m.set_shader_parameter("metalico", float(f.get("metalico", 0.0)))
		return m
	m.shader = TELA
	m.set_shader_parameter("color_principal", main)
	m.set_shader_parameter("color_secundario", second)
	m.set_shader_parameter("color_trama", Color.html(str(f.get("color_trama", "#ebe7df"))))
	m.set_shader_parameter("ligamento_modo", WEAVES.get(str(f.get("ligamento", "tafetan")), 0))
	m.set_shader_parameter("estampado", PATTERNS.get(pattern, 0))
	m.set_shader_parameter("escala_hilo", float(f.get("escala_hilo", 140.0)))
	m.set_shader_parameter("escala_estampado", float(f.get("escala_estampado", 8.0)))
	m.set_shader_parameter("rugosidad", float(f.get("rugosidad", 0.8)))
	m.set_shader_parameter("metalico", float(f.get("metalico", 0.0)))
	m.set_shader_parameter("anisotropia", float(f.get("anisotropia", 0.0)))
	m.set_shader_parameter("brillo_borde", float(f.get("brillo_borde", 0.0)))
	m.set_shader_parameter("tinte_borde", float(f.get("tinte_borde", 0.5)))
	m.set_shader_parameter("relieve", float(f.get("relieve", 0.6)))
	m.set_shader_parameter("capa_brillo", float(f.get("capa_brillo", 0.0)))
	m.set_shader_parameter("mezcla_trama", float(f.get("mezcla_trama", 0.0)))
	m.set_shader_parameter("acabado", FINISHES.get(str(f.get("acabado", "normal")), 0))
	m.set_shader_parameter("costura_intensidad", float(f.get("costuras", 1.0)))
	return m


func hair_material(color: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TELA
	m.set_shader_parameter("color_principal", color)
	m.set_shader_parameter("color_secundario", color.lightened(0.12))
	m.set_shader_parameter("ligamento_modo", -1)
	m.set_shader_parameter("estampado", PATTERNS["rayas"])
	m.set_shader_parameter("escala_estampado", 260.0)
	m.set_shader_parameter("rugosidad", 0.42)
	m.set_shader_parameter("anisotropia", 0.65)
	m.set_shader_parameter("flujo_anisotropia", Vector2(0.0, 1.0))
	m.set_shader_parameter("brillo_borde", 0.2)
	m.set_shader_parameter("costura_intensidad", 0.0)
	return m


static func skin_material(head: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MANIQUI
	m.set_shader_parameter("es_cabeza", head)
	return m


static func _standard(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.6
	return m
