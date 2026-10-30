extends TestCase

const DATA := "res://tests/fixtures/data"
const GameStateScript := preload("res://src/core/game_state.gd")

var save_dir := ""
var gallery_dir := ""
var _states: Array = []


func before_each() -> void:
	save_dir = TestCase.temp_dir("partida")
	gallery_dir = TestCase.temp_dir("galeria")


func after_each() -> void:
	for s in _states:
		s.free()
	_states.clear()
	TestCase.remove_tree(save_dir)
	TestCase.remove_tree(gallery_dir)


func _new_state(t: float = 1000.0) -> Node:
	var s: Node = GameStateScript.new()
	s.clock = func() -> float: return t
	s.initialize(DATA, save_dir, gallery_dir)
	_states.append(s)
	return s


func test_partida_nueva_sin_conexion() -> void:
	var g := _new_state()
	assert_eq(g.data_errors, [], "los datos de prueba son válidos")
	assert_true(g.economy.unlimited)
	assert_eq(g.economy.display_balance("gemas"), "∞")
	assert_eq(g.inventory.owned_ids().size(), 2, "solo las prendas iniciales")
	assert_true(FileAccess.file_exists(save_dir.path_join("partida.json")), "la partida nueva se guarda al crearse")


func test_probar_una_prenda_la_adquiere_gratis_y_la_equipa() -> void:
	var g := _new_state()
	var r: Dictionary = g.try_on("a_collar_perlas")
	assert_true(r.ok)
	assert_true(r.puesta)
	assert_has(r.mensaje, "Añadida a tu armario")
	assert_true(g.inventory.owns("a_collar_perlas"))
	assert_true(g.outfit.is_worn("a_collar_perlas"))
	assert_true(g.is_dirty(), "el cambio programa un autoguardado")
	r = g.try_on("a_collar_perlas")
	assert_false(r.puesta, "pulsar de nuevo la quita")
	assert_true(g.inventory.owns("a_collar_perlas"), "quitarse una prenda no la elimina del armario")


func test_todo_persiste_entre_sesiones() -> void:
	var g := _new_state()
	g.try_on("a_vestido_negro")
	g.try_on("a_zapatos_dorados")
	g.inventory.set_favorite("a_vestido_negro", true)
	var look_id: String = g.save_current_look("Noche")
	g.active_context = "desafio:d_noche_a"
	var result: Dictionary = g.submit_challenge("d_noche_a")
	assert_true(result.total > 0)
	g.settings.set_value("escala_texto", 1.3)
	var img := Image.create(64, 36, false, Image.FORMAT_RGB8)
	img.fill(Color.DARK_SLATE_BLUE)
	var photo: String = g.gallery.add_photo(img, {"titulo": "Prueba", "prendas": g.outfit.to_dict()}, 1000.0)
	assert_ne(photo, "")
	assert_true(g.save_now())
	var h := _new_state(2000.0)
	assert_true(h.inventory.owns("a_vestido_negro"))
	assert_true(h.inventory.is_favorite("a_vestido_negro"))
	assert_true(h.library.looks.has(look_id))
	assert_eq(h.challenges.best("d_noche_a"), result.total)
	assert_eq(h.settings.get_value("escala_texto"), 1.3)
	assert_true(h.gallery.entries.has(photo))
	assert_true(h.outfit.is_worn("a_vestido_negro"), "el conjunto en curso se recupera")
	assert_has("\n".join(h.take_notices()), "Se recuperó el conjunto")
	assert_true(h.economy.unlimited, "monedas y gemas siguen siendo infinitas")


func test_partida_danada_se_recupera_de_la_copia() -> void:
	var g := _new_state()
	g.try_on("a_vestido_negro")
	g.save_now(true)
	g.try_on("a_sombrero_cloche")
	g.save_now(true)
	var main := save_dir.path_join("partida.json")
	JsonUtil.write_text(main, FileAccess.get_file_as_string(main).substr(0, 40))
	var h := _new_state(3000.0)
	assert_true(h.inventory.owns("a_vestido_negro"), "se recupera desde la copia de seguridad")
	assert_has("\n".join(h.take_notices()), "copia de seguridad")


func test_modo_ilimitado_de_la_configuracion_prevalece() -> void:
	var g := _new_state()
	g.economy.unlimited = false
	g.save_now()
	var h := _new_state(2000.0)
	assert_true(h.economy.unlimited)
