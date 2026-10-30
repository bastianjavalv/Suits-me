extends TestCase
## Todas las prendas de muestra generan mallas válidas y dentro del presupuesto de triángulos.

const MUESTRAS := "res://tests/fixtures/prendas_muestra.json"
## Presupuesto por prenda en el perfil sobremesa (objetivo de diseño, ver docs/06-nintendo-switch.md).
const MAX_TRIS_PRENDA := 12000


func _catalog() -> Catalog:
	var c := Catalog.new()
	c.load_files([MUESTRAS])
	return c


func test_cada_generador_produce_mallas_validas() -> void:
	var c := _catalog()
	assert_eq(c.errors, [])
	var gb := GarmentBuilder.new({"segmentos_radiales": 48, "anillos_por_metro": 40})
	for id in c.order:
		var item := c.get_item(id)
		var parts := gb.build(item)
		if item["categoria"] == "maquillaje":
			assert_eq(parts.size(), 0, "el maquillaje no genera mallas")
			continue
		assert_true(parts.size() > 0, "%s no generó piezas" % id)
		var tris := 0
		for part in parts:
			assert_true(Mannequin.JOINT_LAYOUT.has(part["articulacion"]), "%s: articulación %s" % [id, part["articulacion"]])
			var mesh: Mesh = part["malla"]
			assert_true(mesh != null and mesh.get_surface_count() > 0, "%s: malla vacía" % id)
			var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for v in verts:
				if not (is_finite(v.x) and is_finite(v.y) and is_finite(v.z)):
					fail("%s: vértice no finito" % id)
					break
			tris += MeshKit.triangle_count(mesh)
		assert_true(tris <= MAX_TRIS_PRENDA, "%s: %d triángulos (máx. %d)" % [id, tris, MAX_TRIS_PRENDA])


func test_perfil_portatil_usa_menos_geometria() -> void:
	var item := _catalog().get_item("m_vestido_50s")
	var docked := 0
	var handheld := 0
	for part in GarmentBuilder.new({"segmentos_radiales": 48, "anillos_por_metro": 40}).build(item):
		docked += MeshKit.triangle_count(part["malla"])
	for part in GarmentBuilder.new({"segmentos_radiales": 32, "anillos_por_metro": 28}).build(item):
		handheld += MeshKit.triangle_count(part["malla"])
	assert_true(handheld < docked * 0.7, "portátil %d vs sobremesa %d" % [handheld, docked])


func test_falda_cubre_las_piernas() -> void:
	var item := _catalog().get_item("m_falda_lapiz")
	var parts := GarmentBuilder.new({}).build(item)
	var verts: PackedVector3Array = parts[0]["malla"].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in verts:
		if v.y < 0.8 and v.y > 0.47:
			var legs := GarmentBuilder.leg_clearance(v.y)
			var e := Vector2(v.x / legs.x, v.z / legs.y)
			assert_true(e.length() >= 0.98 or absf(v.x) >= legs.x * 0.7, "la falda atraviesa las piernas a y=%.2f" % v.y)
			if failures.size() > 0:
				return


func test_vista_de_conjunto_y_oclusion_de_mangas() -> void:
	var c := _catalog()
	var view := OutfitView.new()
	view.setup(c, JsonUtil.load_object("res://data/tejidos.json", []).get("tejidos", {}),
		{"segmentos_radiales": 24, "anillos_por_metro": 20})
	view.show_outfit({"parte_superior": "m_blusa", "parte_inferior": "m_falda_lapiz", "calzado": "m_salon"})
	var mangas_visibles := 0
	for mi in view._instances["parte_superior"]:
		if mi.visible and str(mi.get_parent().name).begins_with("hombro_"):
			mangas_visibles += 1
	assert_eq(mangas_visibles, 2)
	assert_almost(view.mannequin.heel, 0.088, 0.001, "el tacón eleva la figura")
	view.show_outfit({"parte_superior": "m_blusa", "parte_inferior": "m_falda_lapiz", "abrigo": "m_chaqueta"})
	for mi in view._instances["parte_superior"]:
		if str(mi.get_parent().name).begins_with("hombro_"):
			assert_false(mi.visible, "la chaqueta oculta las mangas de la blusa")
	assert_almost(view.mannequin.heel, 0.0, 0.001, "sin zapatos no hay tacón")
	var st := view.stats()
	assert_true(st["piezas"] > 0 and st["triangulos"] > 0)
	view.free()


func test_todas_las_prendas_reales_generan_mallas_validas() -> void:
	var c := Catalog.new()
	var idx := JsonUtil.load_object("res://data/indice.json", [])
	c.load_files(idx["prendas"].map(func(r): return "res://data/" + r))
	assert_eq(c.errors, [])
	var gb := GarmentBuilder.new({"segmentos_radiales": 48, "anillos_por_metro": 40})
	var worst := 0
	var worst_id := ""
	for id in c.order:
		var item := c.get_item(id)
		var tris := 0
		for part in gb.build(item):
			assert_true(part["malla"] != null and part["malla"].get_surface_count() > 0, "%s: malla vacía" % id)
			tris += MeshKit.triangle_count(part["malla"])
		if item["categoria"] != "maquillaje":
			assert_true(tris > 0, "%s no generó geometría" % id)
		assert_true(tris <= MAX_TRIS_PRENDA, "%s: %d triángulos (máx. %d)" % [id, tris, MAX_TRIS_PRENDA])
		if tris > worst:
			worst = tris
			worst_id = id
	print("    prenda más pesada: %s (%d triángulos)" % [worst_id, worst])


func test_el_corpino_recto_cubre_el_busto() -> void:
	var gb := GarmentBuilder.new({"segmentos_radiales": 48, "anillos_por_metro": 40})
	var part: Dictionary = gb.bodice({"escote": "redondo", "silueta": "recta"}, 0, 0.9)
	var verts: PackedVector3Array = part["malla"].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in verts:
		if v.y > 1.15 and v.y < 1.28:
			# Dirección polar del vértice -> parámetro angular del cuerpo en esa misma dirección
			# (en una elipse x = a·sen θ, z = b·cos θ, el ángulo polar no es θ).
			var phi := atan2(v.x, v.z)
			var body := GarmentBuilder.body_radius(v.y)
			var th := atan2(body.y * sin(phi), body.x * cos(phi))
			var rel := Mannequin.torso_relief(th, v.y)
			var garment_r := Vector2(v.x, v.z).length()
			var body_r := Vector2((body.x + rel) * sin(th), (body.y + rel) * cos(th)).length()
			if garment_r < body_r:
				fail("el maniquí atraviesa el corpino a y=%.2f θ=%.2f" % [v.y, th])
				return
