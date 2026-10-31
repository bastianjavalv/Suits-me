class_name OutfitView
extends Node3D
## Monta el conjunto sobre el maniquí: genera (y reutiliza) las mallas de cada prenda, asigna los
## materiales, aplica tacón, maquillaje y poses, y mueve las faldas cuando el maniquí gira.

signal rebuilt

var catalog: Catalog
var fabrics: FabricLibrary
var quality: Dictionary = {}
var mannequin: Mannequin
var head_material: ShaderMaterial
var body_material: ShaderMaterial
var slots: Dictionary = {}           ## categoría -> id equipado
var _instances: Dictionary = {}      ## categoría -> Array[MeshInstance3D]
var _mesh_cache: Dictionary = {}     ## clave -> Array de piezas
var _heel := -1.0
var yaw := 0.0                       ## orientación objetivo del maniquí (grados)
var _yaw_shown := 0.0
var _spin := 0.0
var last_build_ms := 0.0


func setup(p_catalog: Catalog, fabric_data: Dictionary, p_quality: Dictionary) -> void:
	catalog = p_catalog
	fabrics = FabricLibrary.new(fabric_data)
	quality = p_quality
	head_material = FabricLibrary.skin_material(true)
	body_material = FabricLibrary.skin_material(false)
	mannequin = Mannequin.new()
	mannequin.name = "Maniqui"
	add_child(mannequin)
	mannequin.build(int(quality.get("segmentos_radiales", 40)), body_material, head_material)


func set_quality(p_quality: Dictionary) -> void:
	if int(p_quality.get("segmentos_radiales", 0)) == int(quality.get("segmentos_radiales", 0)):
		quality = p_quality
		return
	quality = p_quality
	_mesh_cache.clear()
	var current := slots.duplicate()
	clear()
	mannequin.build(int(quality.get("segmentos_radiales", 40)), body_material, head_material)
	_heel = -1.0
	show_outfit(current)


func clear() -> void:
	for cat in _instances:
		for mi in _instances[cat]:
			mi.queue_free()
	_instances.clear()
	slots.clear()


## Muestra un conjunto {categoría: id}; solo reconstruye las categorías que cambian.
func show_outfit(new_slots: Dictionary) -> void:
	var t0 := Time.get_ticks_usec()
	var heel := heel_for(new_slots)
	var heel_changed := not is_equal_approx(heel, _heel)
	if heel_changed:
		_heel = heel
		mannequin.set_heel_height(heel)
	for cat in Defs.CATEGORIES:
		var old_id: String = slots.get(cat, "")
		var new_id: String = new_slots.get(cat, "")
		var depends_on_heel := heel_changed and cat in ["vestido", "parte_inferior", "abrigo"]
		if old_id == new_id and not depends_on_heel:
			continue
		_remove(cat)
		if new_id.is_empty():
			slots.erase(cat)
			if cat == "maquillaje":
				apply_makeup({})
			continue
		slots[cat] = new_id
		var item := catalog.get_item(new_id)
		if cat == "maquillaje":
			apply_makeup(item.get("modelo", {}).get("params", {}))
			continue
		_add(cat, item)
	_update_occlusion()
	last_build_ms = (Time.get_ticks_usec() - t0) / 1000.0
	rebuilt.emit()


## Oculta las mangas de las prendas interiores cuando un abrigo con mangas o una capa las cubre:
## evita que atraviesen la capa exterior y ahorra llamadas de dibujo.
func _update_occlusion() -> void:
	var covers_arms := false
	if slots.has("abrigo"):
		var model: Dictionary = catalog.get_item(slots["abrigo"]).get("modelo", {})
		var gen := str(model.get("generador", ""))
		covers_arms = gen == "capa" or (gen == "abrigo" and str(model.get("params", {}).get("tipo", "")) != "chaleco")
	for cat in ["vestido", "parte_superior"]:
		for mi in _instances.get(cat, []):
			var joint := str(mi.get_parent().name)
			mi.visible = not (covers_arms and (joint.begins_with("hombro_") or joint.begins_with("codo_")))


func heel_for(s: Dictionary) -> float:
	if not s.has("calzado") or catalog == null:
		return 0.0
	var p: Dictionary = catalog.get_item(s["calzado"]).get("modelo", {}).get("params", {})
	var extra := 0.03 if str(p.get("tipo", "")) == "plataforma" else 0.0
	return float(p.get("tacon", 0.0)) + float(p.get("suela", 0.008)) + extra


func _remove(cat: String) -> void:
	for mi in _instances.get(cat, []):
		mi.queue_free()
	_instances.erase(cat)


func _add(cat: String, item: Dictionary) -> void:
	var key := "%s|%d|%.3f" % [item["id"], int(quality.get("segmentos_radiales", 40)), _heel]
	var parts: Array
	if _mesh_cache.has(key):
		parts = _mesh_cache[key]
	else:
		var gb := GarmentBuilder.new(quality)
		gb.heel = _heel
		parts = gb.build(item)
		_mesh_cache[key] = parts
	var list: Array = []
	for part in parts:
		var mat := fabrics.material_for(item, str(part["rol"]))
		var mi := mannequin.attach(str(part["articulacion"]), part["malla"], mat, part["posicion"], "%s_%s" % [cat, part["rol"]])
		mi.rotation_degrees = part["rotacion"]
		mi.scale = part["escala"]
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader == FabricLibrary.TELA:
			mi.set_instance_shader_parameter("contorno", float(part["contorno"]))
			mi.set_instance_shader_parameter("largo", float(part["largo"]))
		# Solo las piezas con vaivén (faldas, capas, velos) se mecen; el resto queda fuera del rango.
		if mat is ShaderMaterial:
			mi.set_instance_shader_parameter("cintura_local", float(part["cintura_local"]) if part["vaiven"] else -100.0)
			if part["vaiven"]:
				(mat as ShaderMaterial).set_shader_parameter("vaiven", 1.0)
		list.append(mi)
	_instances[cat] = list


## Maquillaje pintado sobre la cabeza del maniquí (sin malla propia).
func apply_makeup(p: Dictionary) -> void:
	var lips := Color.html(str(p.get("labios", "#9a3a42")))
	lips.a = float(p.get("intensidad_labios", 0.0 if p.is_empty() else 0.85))
	var shadow := Color.html(str(p.get("sombra", "#5a4a5a")))
	shadow.a = float(p.get("intensidad_sombra", 0.0 if p.is_empty() else 0.55))
	var blush := Color.html(str(p.get("colorete", "#d98a80")))
	blush.a = float(p.get("intensidad_colorete", 0.0 if p.is_empty() else 0.5))
	head_material.set_shader_parameter("labios", lips)
	head_material.set_shader_parameter("sombra", shadow)
	head_material.set_shader_parameter("colorete", blush)
	head_material.set_shader_parameter("delineado", float(p.get("delineado", 0.0)))
	head_material.set_shader_parameter("rabillo", float(p.get("rabillo", 0.0)))
	head_material.set_shader_parameter("cejas", float(p.get("cejas", 0.25)))


func apply_pose(pose: Dictionary, duration: float = 0.6) -> void:
	mannequin.apply_pose(pose, duration)


func rotate_by(degrees: float) -> void:
	yaw += degrees


func _process(delta: float) -> void:
	var before := _yaw_shown
	_yaw_shown = lerpf(_yaw_shown, yaw, 1.0 - exp(-delta * 10.0))
	mannequin.rotation_degrees.y = _yaw_shown
	var angular := deg_to_rad(_yaw_shown - before) / maxf(delta, 0.0001)
	_spin = lerpf(_spin, clampf(-angular * 0.06, -0.5, 0.5), 1.0 - exp(-delta * 4.0))
	RenderingServer.global_shader_parameter_set("giro_reciente", _spin)


## Estadísticas de geometría del conjunto actual (para presupuestos de rendimiento).
func stats() -> Dictionary:
	var meshes := 0
	var tris := 0
	for cat in _instances:
		for mi in _instances[cat]:
			meshes += 1
			tris += MeshKit.triangle_count(mi.mesh)
	return {"piezas": meshes, "triangulos": tris, "ms_ultima_construccion": snappedf(last_build_ms, 0.1)}
