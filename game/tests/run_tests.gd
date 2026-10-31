extends SceneTree
## Ejecuta las pruebas unitarias en modo sin ventana:
##   godot --headless --path game -s res://tests/run_tests.gd [-- --filtro=texto]
## Una prueba falla si alguna aserción falla o si el motor registra un error de script durante
## su ejecución. Termina con código 0 si todo pasa y 1 si hay fallos.

const TEST_DIRS: Array[String] = ["res://tests/unit"]


class ErrorCatcher extends Logger:
	var _mutex := Mutex.new()
	var _errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		_errors.append("%s:%d (%s) %s %s" % [file, line, function, code, rationale])
		_mutex.unlock()

	func take() -> Array[String]:
		_mutex.lock()
		var out := _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return out


func _initialize() -> void:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filtro="):
			filter = arg.trim_prefix("--filtro=")
	var total := 0
	var failed: Array[String] = []
	var started := Time.get_ticks_msec()
	catcher.take()
	for dir in TEST_DIRS:
		var files := Array(DirAccess.get_files_at(dir))
		files.sort()
		for f in files:
			if not (f.begins_with("test_") and f.ends_with(".gd")):
				continue
			var script: GDScript = load(dir.path_join(f))
			var load_errors := catcher.take()
			if script == null or not script.can_instantiate() or not load_errors.is_empty():
				failed.append("%s: el script no compila. %s" % [f, " | ".join(load_errors)])
				print("  FALLO %s no compila" % f)
				continue
			for m in script.get_script_method_list():
				var name: String = m["name"]
				if not name.begins_with("test_") or (not filter.is_empty() and not (f + "." + name).contains(filter)):
					continue
				var case: TestCase = script.new()
				case.current_test = "%s.%s" % [f.get_basename(), name]
				case.before_each()
				await case.call(name)
				case.after_each()
				total += 1
				var engine_errors := catcher.take()
				if not case.allow_engine_errors:
					for e in engine_errors:
						case.failures.append("%s: error del motor: %s" % [case.current_test, e])
				if case.failures.is_empty():
					print("  ok   %s" % case.current_test)
				else:
					for msg in case.failures:
						failed.append(msg)
						print("  FALLO %s" % msg)
	print("")
	print("%d pruebas, %d fallos (%d ms)" % [total, failed.size(), Time.get_ticks_msec() - started])
	TestCase.remove_tree("user://pruebas")
	OS.remove_logger(catcher)
	quit(1 if not failed.is_empty() or total == 0 else 0)
