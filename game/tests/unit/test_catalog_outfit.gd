extends TestCase

const DATA := "res://tests/fixtures/data"


func _catalog() -> Catalog:
	var c := Catalog.new()
	c.known_eras = {"era_a": true, "era_b": true}
	c.known_fabrics = {"seda": true, "lana": true, "cuero": true}
	c.load_files([DATA + "/prendas/prueba.json"])
	return c


func test_carga_catalogo_valido() -> void:
	var c := _catalog()
	assert_eq(c.errors, [], "el catálogo de prueba es válido")
	assert_eq(c.size(), 10)
	assert_eq(c.by_category["vestido"].size(), 3)
	assert_eq(c.by_era["era_b"], ["b_botas_blancas", "b_vestido_naranja", "b_gafas"])
	assert_eq(c.price_of("a_vestido_negro"), {"moneda": "gemas", "valor": 5})
	assert_eq(c.color_family["a_vestido_negro"], "negro")


func test_rechaza_prendas_invalidas_con_mensajes() -> void:
	var c := _catalog()
	var bad := c.get_item("a_vestido_marfil").duplicate(true)
	assert_false(c.add_item(bad), "id duplicado")
	bad["id"] = "Con Espacios"
	bad["categoria"] = "capa_magica"
	bad["color"] = "rojo"
	bad["temporadas"] = ["monzon"]
	bad["ficha"].erase("silueta")
	bad["ficha"]["atribucion"] = {"estado": "documentada"}
	assert_false(c.add_item(bad, "prueba"))
	var all := "\n".join(c.errors)
	for expected in ["id duplicado", "id ausente", "categoría desconocida", "#RRGGBB", "temporada desconocida",
			"ficha: falta 'silueta'", "atribución documentada necesita 'fuentes'"]:
		assert_has(all, expected)


func test_vestido_excluye_partes_y_viceversa() -> void:
	var c := _catalog()
	var o := Outfit.new()
	o.equip(c.get_item("a_blusa_rosa"))
	o.equip(c.get_item("a_falda_gris"))
	var removed := o.equip(c.get_item("a_vestido_marfil"))
	assert_eq(removed, ["a_blusa_rosa", "a_falda_gris"])
	assert_eq(o.to_dict(), {"vestido": "a_vestido_marfil"})
	removed = o.equip(c.get_item("a_blusa_rosa"))
	assert_eq(removed, ["a_vestido_marfil"])
	assert_eq(o.to_dict(), {"parte_superior": "a_blusa_rosa"})


func test_toggle_y_reemplazo_en_misma_categoria() -> void:
	var c := _catalog()
	var o := Outfit.new()
	assert_true(o.toggle(c.get_item("a_zapatos_dorados")))
	assert_eq(o.equip(c.get_item("b_botas_blancas")), ["a_zapatos_dorados"])
	assert_false(o.toggle(c.get_item("b_botas_blancas")), "un segundo toque quita la prenda")
	assert_eq(o.count(), 0)


func test_firma_y_carga_descartan_prendas_inexistentes() -> void:
	var c := _catalog()
	var o := Outfit.new()
	var dropped := o.load_dict({"vestido": "a_vestido_negro", "calzado": "no_existe", "tocado": "a_vestido_marfil"}, c)
	assert_eq(dropped.size(), 2, "una inexistente y otra en la categoría equivocada")
	assert_eq(o.signature(), "a_vestido_negro")
	assert_almost(Outfit.jaccard(["a", "b"], ["b", "c"]), 1.0 / 3.0)
	assert_almost(Outfit.jaccard([], []), 1.0)


func test_filtros_del_armario() -> void:
	var c := _catalog()
	var inv := Inventory.new()
	var eco := Economy.new()
	inv.acquire(c, eco, "a_vestido_negro", 1.0)
	inv.set_favorite("a_collar_perlas", true)
	var era_order := {"era_a": 0, "era_b": 1}
	assert_eq(WardrobeFilter.apply(c, inv, {"categoria": "calzado"}, era_order), ["a_zapatos_dorados", "b_botas_blancas"])
	assert_eq(WardrobeFilter.apply(c, inv, {"eras": ["era_b"], "estilos": ["futurista"]}, era_order),
		["b_botas_blancas", "b_vestido_naranja", "b_gafas"])
	assert_eq(WardrobeFilter.apply(c, inv, {"colores": ["negro"]}, era_order), ["a_vestido_negro", "b_gafas"])
	assert_eq(WardrobeFilter.apply(c, inv, {"moneda": "gemas"}, era_order), ["a_vestido_negro"])
	assert_eq(WardrobeFilter.apply(c, inv, {"precio_min": 200}, era_order), ["a_collar_perlas"])
	assert_eq(WardrobeFilter.apply(c, inv, {"solo_favoritas": true}), ["a_collar_perlas"])
	assert_eq(WardrobeFilter.apply(c, inv, {"solo_adquiridas": true}), ["a_vestido_negro"])
	assert_eq(WardrobeFilter.apply(c, inv, {"texto": "PERLAS"}), ["a_collar_perlas"])
	assert_eq(WardrobeFilter.apply(c, inv, {"influencias": ["Casa de prueba"], "eras": ["era_b"]}), ["b_vestido_naranja"])
	assert_eq(WardrobeFilter.apply(c, inv, {"temporadas": ["invierno"]}), [])
	var by_name := WardrobeFilter.apply(c, inv, {"categoria": "vestido", "orden": "nombre"})
	assert_eq(by_name, ["a_vestido_marfil", "b_vestido_naranja", "a_vestido_negro"])
	var facets := WardrobeFilter.facets(c)
	assert_has(facets["estilos"], "futurista")
	assert_has(facets["colores"], "negro")


func test_filtro_rapido_con_muchas_prendas() -> void:
	var c := Catalog.new()
	var base := _catalog().get_item("a_vestido_marfil")
	for i in 5000:
		var it := base.duplicate(true)
		it["id"] = "p_%d" % i
		it["era"] = "era_a" if i % 2 == 0 else "era_b"
		it["color"] = "#%02x%02x%02x" % [i % 256, (i * 7) % 256, (i * 13) % 256]
		c.add_item(it)
	var t0 := Time.get_ticks_usec()
	var r := WardrobeFilter.apply(c, Inventory.new(), {"eras": ["era_b"], "colores": ["rojo", "azul"], "texto": "marfil"})
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_true(r.size() > 0)
	assert_true(ms < 250.0, "filtrar 5000 prendas tardó %.1f ms" % ms)
