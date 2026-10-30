extends SceneTree
## Compila todos los scripts del proyecto e informa de los que fallan:
##   godot --headless --path game -s res://tools/check_scripts.gd

func _initialize() -> void:
	var failed := 0
	var files := _collect("res://src") + _collect("res://scenes") + _collect("res://tools")
	for f in files:
		var s: GDScript = load(f)
		if s == null or not s.can_instantiate():
			failed += 1
			print("FALLA: ", f)
	print("%d scripts revisados, %d con errores" % [files.size(), failed])
	quit(1 if failed > 0 else 0)


func _collect(dir: String) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for d in DirAccess.get_directories_at(dir):
		out += _collect(dir.path_join(d))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out
