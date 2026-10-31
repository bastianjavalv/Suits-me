extends TestCase
## Los datos reales del juego (res://data) cargan sin errores y cumplen las reglas de contenido.

const GameStateScript := preload("res://src/core/game_state.gd")

var save_dir := ""
var _g: Node


func before_each() -> void:
	save_dir = TestCase.temp_dir("contenido")
	_g = GameStateScript.new()
	_g.clock = func() -> float: return 1000.0
	_g.initialize("res://data", save_dir, save_dir.path_join("galeria"))


func after_each() -> void:
	_g.free()
	TestCase.remove_tree(save_dir)


func test_datos_sin_errores() -> void:
	assert_eq(_g.data_errors, [], "los datos del juego deben validar sin errores")
	assert_eq(_g.eras.size(), 9, "nueve capítulos de Eras de la Moda")


func test_cada_era_tiene_contenido_completo() -> void:
	for era in _g.eras:
		var id: String = era["id"]
		assert_true(_g.catalog.by_era.get(id, []).size() >= 8, "%s: al menos 8 prendas" % id)
		assert_true(_g.encyclopedia.by_era.get(id, []).size() >= 3, "%s: al menos 3 fichas" % id)
		assert_true(_g.challenges.for_era(id).size() >= 3, "%s: al menos 3 desafíos" % id)
		assert_true(_g.stages.has(era["escenario"]), "%s: escenario %s" % [id, era["escenario"]])


func test_cada_prenda_tiene_historia_con_fuentes() -> void:
	for id in _g.catalog.order:
		var sheet: Dictionary = _g.encyclopedia.sheet_for_item(_g.catalog.get_item(id))
		assert_true(sheet["fichas"].size() > 0, "%s sin ficha enlazada" % id)
		assert_true(sheet["fuentes"].size() > 0, "%s sin fuentes" % id)
		var item: Dictionary = sheet["prenda"]
		assert_eq(item["ficha"]["tipo_pieza"], "interpretacion_de_epoca", "%s: las prendas del juego son interpretaciones" % id)


func test_todas_las_categorias_tienen_prendas_iniciales_o_disponibles() -> void:
	var cats := {}
	for id in _g.catalog.order:
		cats[_g.catalog.get_item(id)["categoria"]] = true
	for c in ["vestido", "parte_superior", "parte_inferior", "abrigo", "calzado", "tocado", "peinado", "maquillaje"]:
		assert_true(cats.has(c), "falta la categoría %s" % c)
	assert_true(_g.inventory.owned_ids().size() >= 18, "partida nueva con al menos 2 prendas iniciales por época")


func test_ley_suntuaria_penaliza_seda_y_escarlata() -> void:
	var ok := {"vestido": "med_saya_lana", "calzado": "med_poulaines", "tocado": "med_toca_lino"}
	var bad := {"vestido": "med_bliaut_azul", "abrigo": "med_manto_escarlata", "calzado": "med_poulaines", "tocado": "med_toca_lino"}
	var era_names: Dictionary = _g.era_names
	var r_ok := Evaluator.evaluate(_g.challenges.challenges["med_ley_1322"], ok, _g.catalog, era_names)
	var r_bad := Evaluator.evaluate(_g.challenges.challenges["med_ley_1322"], bad, _g.catalog, era_names)
	var tema_ok: int = r_ok["criterios"][0]["puntos"]
	var tema_bad: int = r_bad["criterios"][0]["puntos"]
	assert_true(tema_bad < tema_ok, "la seda y el paño escarlata restan puntos (%d vs %d)" % [tema_bad, tema_ok])
	assert_has("\n".join(r_bad["criterios"][0]["detalle"]), "Incumple la norma del desafío")


func test_cruce_de_epocas_exige_tres_epocas() -> void:
	var c: Dictionary = _g.challenges.challenges["libre_cruce"]
	var two := {"vestido": "a20_vestido_negro", "calzado": "a50_salones_aguja"}
	var three := {"vestido": "a20_vestido_negro", "calzado": "a50_salones_aguja", "tocado": "a60_casquete"}
	var r2 := Evaluator.evaluate(c, two, _g.catalog, _g.era_names)
	var r3 := Evaluator.evaluate(c, three, _g.catalog, _g.era_names)
	assert_true(r3["criterios"][2]["puntos"] > r2["criterios"][2]["puntos"])
	assert_has("\n".join(r2["criterios"][2]["detalle"]), "Faltan épocas")
