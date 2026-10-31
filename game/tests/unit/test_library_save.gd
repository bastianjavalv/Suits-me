extends TestCase

var dir := ""


func before_each() -> void:
	dir = TestCase.temp_dir("guardado")


func after_each() -> void:
	TestCase.remove_tree(dir)


func test_looks_borradores_historial_y_papelera() -> void:
	var lib := OutfitLibrary.new()
	var a := lib.save_look("  Gala  ", {"vestido": "x"}, 10.0, ["noche"])
	var b := lib.save_look("", {"vestido": "y"}, 11.0)
	assert_ne(a, b)
	assert_eq(lib.looks[a]["nombre"], "Gala")
	assert_eq(lib.looks[b]["nombre"], "Look 2")
	assert_true(lib.update_look(a, {"vestido": "z"}, 20.0))
	assert_eq(lib.looks_sorted()[0]["id"], a, "el actualizado más recientemente va primero")
	var dup := lib.duplicate_look(a, 21.0)
	assert_eq(lib.looks[dup]["prendas"], {"vestido": "z"})
	assert_true(lib.delete_look(a, 22.0))
	assert_false(lib.looks.has(a))
	assert_eq(lib.restore_from_trash(0), a, "lo borrado se puede recuperar")
	assert_true(lib.looks.has(a))
	var d := lib.save_draft({"calzado": "c"}, "vestidor", 30.0)
	assert_eq(lib.save_draft({"calzado": "d"}, "vestidor", 31.0, d), d, "se edita el mismo borrador")
	var promoted := lib.promote_draft(d, "Desde borrador", 32.0)
	assert_false(lib.drafts.has(d))
	assert_eq(lib.looks[promoted]["prendas"], {"calzado": "d"})
	lib.record_history({"vestido": "z"}, "desafío", 40.0)
	lib.record_history({"vestido": "z"}, "desafío", 41.0)
	assert_eq(lib.history.size(), 1, "no se repite la misma entrada consecutiva")
	for i in 150:
		lib.record_history({"vestido": "v%d" % i}, "prueba", 50.0 + i)
	assert_eq(lib.history.size(), OutfitLibrary.MAX_HISTORY)
	var copy := OutfitLibrary.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(lib.to_dict())))
	assert_eq(copy.looks.size(), lib.looks.size())
	var fresh := copy.save_look("nuevo", {}, 99.0)
	assert_false(lib.looks.has(fresh), "el contador persistido evita ids repetidos")


func test_guardar_y_cargar() -> void:
	var s := SaveSystem.new(dir)
	assert_true(s.save({"monedas": "∞", "lista": [1, 2, 3]}, 1000.0))
	var r := s.load_game()
	assert_true(r.ok)
	assert_eq(r.origen, "principal")
	assert_eq(r.datos, {"monedas": "∞", "lista": [1, 2, 3]})
	assert_eq(r.aviso, "")


func test_detecta_corrupcion_y_recupera_copia() -> void:
	var s := SaveSystem.new(dir)
	s.save({"version_datos": 1}, 1000.0)
	s.save({"version_datos": 2}, 2000.0, true)  # copia de la versión 1
	# Se corrompe el archivo principal (escritura cortada).
	var text := FileAccess.get_file_as_string(s.main_path)
	JsonUtil.write_text(s.main_path, text.substr(0, text.length() - 7))
	var r := s.load_game()
	assert_true(r.ok)
	assert_eq(r.origen, "copia")
	assert_eq(r.datos["version_datos"], 1)
	assert_has(r.aviso, "copia de seguridad")


func test_usa_el_temporal_si_el_guardado_se_interrumpio() -> void:
	var s := SaveSystem.new(dir)
	s.save({"n": 1}, 1000.0)
	JsonUtil.write_text(s.temp_path, SaveSystem.encode({"n": 2}, 1500.0, SaveSystem.CURRENT_VERSION))
	var r := s.load_game()
	assert_eq(r.origen, "temporal")
	assert_eq(r.datos["n"], 2)


func test_todo_danado_inicia_partida_nueva_y_conserva_el_archivo() -> void:
	var s := SaveSystem.new(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	JsonUtil.write_text(s.main_path, "basura sin formato")
	var r := s.load_game()
	assert_true(r.ok)
	assert_eq(r.origen, "nueva")
	assert_has(r.aviso, "partida.danada.json")
	assert_true(FileAccess.file_exists(dir.path_join("partida.danada.json")))


func test_rotacion_de_copias() -> void:
	var s := SaveSystem.new(dir)
	for i in 25:
		s.save({"i": i}, 1000.0 + i * 1000.0, true)
	assert_eq(s.list_backups().size(), SaveSystem.MAX_BACKUPS)


func test_copias_respetan_el_intervalo() -> void:
	var s := SaveSystem.new(dir)
	s.save({"i": 0}, 1000.0)
	for i in 5:
		s.save({"i": i}, 1000.0 + i)
	assert_eq(s.list_backups().size(), 1, "solo una copia en 5 segundos")


func test_migracion_y_version_futura() -> void:
	var s := SaveSystem.new(dir)
	s.current_version = 1
	s.save({"monedas": 5}, 1000.0)
	s.current_version = 2
	s.migrations = {1: func(d: Dictionary) -> Dictionary: return {"economia": {"monedas": d["monedas"]}}}
	var r := s.load_game()
	assert_eq(r.datos, {"economia": {"monedas": 5}})
	s.current_version = 3
	s.save({"x": 1}, 2000.0)
	s.current_version = 2
	var future := s.load_game()
	assert_false(future.ok, "no se carga una partida de una versión más nueva")


func test_exportar_e_importar_copia() -> void:
	var s := SaveSystem.new(dir)
	s.save({"a": 1}, 1000.0)
	var dest := dir.path_join("exportada.json")
	assert_true(s.export_copy(dest))
	s.save({"a": 2}, 2000.0)
	assert_true(s.import_copy(dest, 3000.0))
	assert_eq(s.load_game().datos, {"a": 1})
	JsonUtil.write_text(dest, "no válida")
	assert_false(s.import_copy(dest, 4000.0))
	assert_eq(s.load_game().datos, {"a": 1}, "una copia inválida no reemplaza la partida")
