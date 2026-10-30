extends TestCase

const DATA := "res://tests/fixtures/data"
const ERA_NAMES := {"era_a": "Era A", "era_b": "Era B"}


func _catalog() -> Catalog:
	var c := Catalog.new()
	c.load_files([DATA + "/prendas/prueba.json"])
	return c


func _book() -> ChallengeBook:
	var b := ChallengeBook.new()
	b.known_eras = {"era_a": true, "era_b": true}
	b.known_stages = {"estudio": true}
	b.load_file(DATA + "/desafios.json")
	return b


func _criterion(result: Dictionary, id: String) -> Dictionary:
	for c in result["criterios"]:
		if c["id"] == id:
			return c
	return {}


func test_familias_de_color() -> void:
	assert_eq(ColorTools.family_of(Color.html("#141414")), "negro")
	assert_eq(ColorTools.family_of(Color.html("#F5F5F2")), "blanco")
	assert_eq(ColorTools.family_of(Color.html("#808080")), "gris")
	assert_eq(ColorTools.family_of(Color.html("#D8C8A8")), "beige")
	assert_eq(ColorTools.family_of(Color.html("#6B3E26")), "marron")
	assert_eq(ColorTools.family_of(Color.html("#C0182A")), "rojo")
	assert_eq(ColorTools.family_of(Color.html("#F2B6C6")), "rosa")
	assert_eq(ColorTools.family_of(Color.html("#1F4E9A")), "azul")
	assert_eq(ColorTools.family_of(Color.html("#2E7D4F")), "verde")
	assert_eq(ColorTools.family_of(Color.html("#6A2C91")), "morado")


func test_esquemas_de_armonia() -> void:
	var mono := ColorTools.analyze([Color.html("#1F4E9A"), Color.html("#5C86C8")])
	assert_eq(mono["esquema"], "monocromático")
	var analog := ColorTools.analyze([Color.html("#C0182A"), Color.html("#E07020"), Color.html("#E8B020")])
	assert_eq(analog["esquema"], "análogo")
	var comp := ColorTools.analyze([Color.html("#1F4E9A"), Color.html("#E08A1F")])
	assert_eq(comp["esquema"], "complementario")
	var triad := ColorTools.analyze([Color.html("#D02020"), Color.html("#20D020"), Color.html("#2020D0")])
	assert_eq(triad["esquema"], "triádico")
	var neutral := ColorTools.analyze([Color.html("#141414"), Color.html("#F5F5F2"), Color.html("#808080")])
	assert_eq(neutral["esquema"], "neutro")
	var busy := ColorTools.analyze([Color.html("#FF0000"), Color.html("#FFFF00"), Color.html("#00FF80"),
		Color.html("#0080FF"), Color.html("#FF00FF")])
	assert_eq(busy["esquema"], "multicolor")
	assert_true(busy["puntuacion"] < mono["puntuacion"])
	# Tonos a ambos lados del rojo (350° y 10°) forman un solo grupo.
	assert_eq(ColorTools.cluster_hues([350.0, 10.0]).size(), 1)
	assert_almost(ColorTools.hue_span([350.0, 10.0]), 20.0)


func test_paleta_sugerida() -> void:
	var p: Array[Color] = [Color.html("#141414"), Color.html("#C8A040")]
	var near: Array[Color] = [Color.html("#181818"), Color.html("#C9A345")]
	var far: Array[Color] = [Color.html("#20C0F0")]
	assert_almost(ColorTools.palette_match(near, p), 1.0)
	assert_almost(ColorTools.palette_match(far, p), 0.0)


func test_evaluacion_transparente_y_estrellas() -> void:
	var c := _catalog()
	var b := _book()
	assert_eq(b.errors, [])
	var good := {"vestido": "a_vestido_negro", "calzado": "a_zapatos_dorados", "tocado": "a_sombrero_cloche",
		"joyeria": "a_collar_perlas"}
	var r := Evaluator.evaluate(b.challenges["d_noche_a"], good, c, ERA_NAMES)
	assert_eq(r["criterios"].size(), 4)
	var total := 0
	for crit in r["criterios"]:
		total += crit["puntos"]
		assert_true(crit["puntos"] <= crit["max"])
		assert_false(crit["detalle"].is_empty(), "cada criterio explica su puntuación")
	assert_eq(r["total"], total)
	assert_eq(_criterion(r, "completo")["puntos"], 15)
	assert_has(r["aviso"], "sin conexión")
	var bad := {"vestido": "b_vestido_naranja", "calzado": "b_botas_blancas"}
	var r2 := Evaluator.evaluate(b.challenges["d_noche_a"], bad, c, ERA_NAMES)
	assert_true(r2["total"] < r["total"])
	assert_has("\n".join(_criterion(r2, "tema")["detalle"]), "Fuera de época: Vestido naranja (Era B)")
	assert_eq(Evaluator.stars_for(59), 0)
	assert_eq(Evaluator.stars_for(60), 1)
	assert_eq(Evaluator.stars_for(75), 2)
	assert_eq(Evaluator.stars_for(90), 3)


func test_completitud_exige_prenda_principal() -> void:
	var c := _catalog()
	var b := _book()
	var r := Evaluator.evaluate(b.challenges["d_noche_a"], {"parte_superior": "a_blusa_rosa"}, c, ERA_NAMES)
	var comp := _criterion(r, "completo")
	assert_eq(comp["puntos"], 0)
	assert_has("\n".join(comp["detalle"]), "Falta: un vestido, o una parte de arriba y otra de abajo")
	var empty := Evaluator.evaluate(b.challenges["d_libre"], {}, c, ERA_NAMES)
	assert_eq(_criterion(empty, "tema")["puntos"], 0)


func test_desafio_libre_admite_cualquier_epoca() -> void:
	var c := _catalog()
	var b := _book()
	var mixed := {"vestido": "a_vestido_marfil", "calzado": "b_botas_blancas"}
	var r := Evaluator.evaluate(b.challenges["d_libre"], mixed, c, ERA_NAMES)
	assert_eq(_criterion(r, "tema")["puntos"], 40)


func test_alternativas_y_originalidad() -> void:
	var c := _catalog()
	var b := _book()
	var look := {"vestido": "a_vestido_negro", "calzado": "a_zapatos_dorados"}
	var first := b.submit("d_noche_a", look, c, ERA_NAMES, 1.0)
	assert_true(first["nuevo_record"])
	var repeat := b.submit("d_noche_a", look, c, ERA_NAMES, 2.0)
	assert_true(_criterion(repeat, "creatividad")["puntos"] < _criterion(first, "creatividad")["puntos"],
		"repetir exactamente la misma entrega puntúa menos en originalidad")
	assert_false(repeat["nuevo_record"])
	assert_eq(b.submissions("d_noche_a").size(), 2, "se guardan todas las alternativas")
	for i in 20:
		b.submit("d_noche_a", look, c, ERA_NAMES, 10.0 + i)
	assert_eq(b.submissions("d_noche_a").size(), ChallengeBook.MAX_SUBMISSIONS)
	assert_eq(b.best("d_noche_a"), first["total"])
	var summary := b.era_summary("era_a")
	assert_eq(summary["desafios"], 1)


func test_valida_desafios() -> void:
	var b := _book()
	var bad := {"id": "x", "titulo": "t", "descripcion": "d", "tipo": "batalla", "era": "era_z",
		"requisitos": {"obligatorias": ["capa"]}, "paleta": ["azul"], "escenario": "luna"}
	var all := "\n".join(b.validate(bad))
	for expected in ["'tipo' debe ser", "era desconocida", "categoría desconocida", "color de paleta", "escenario desconocido"]:
		assert_has(all, expected)


func test_enciclopedia_valida_fuentes_y_compone_la_historia() -> void:
	var e := Encyclopedia.new()
	e.load_sources(DATA + "/enciclopedia/fuentes.json")
	e.load_entries([DATA + "/enciclopedia/prueba.json"])
	e.check_references()
	assert_eq(e.errors, [])
	var bad := {"id": "x", "nombre": "n", "era": "e", "periodo": "p", "region": "r", "resumen": "s",
		"revision_humana": false,
		"hechos": [{"texto": "Sin fuente", "estado": "verificado", "fuentes": []},
			{"texto": "Opinión", "estado": "interpretacion", "fuentes": []}]}
	var problems := "\n".join(e.validate_entry(bad))
	assert_has(problems, "necesita al menos una fuente")
	assert_false(problems.contains("Opinión"), "una interpretación no necesita fuente")
	var item := _catalog().get_item("a_vestido_marfil")
	var sheet := e.sheet_for_item(item)
	assert_eq(sheet["fichas"].size(), 1)
	assert_eq(sheet["fuentes"][0]["id"], "fuente_a")
	assert_true(sheet["pendiente_revision"])
	assert_eq(e.search("complemento"), ["tipo_general"])
