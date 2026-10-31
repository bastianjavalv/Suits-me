class_name TestCase
extends RefCounted
## Base mínima de pruebas: métodos test_* con aserciones; before_each/after_each opcionales.

var failures: Array[String] = []
var current_test := ""
## Si es true, los errores que registre el motor durante la prueba no la hacen fallar.
var allow_engine_errors := false


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		fail("se esperaba verdadero. %s" % msg)


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		fail("se esperaba falso. %s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if not deep_equal(actual, expected):
		fail("se esperaba %s y se obtuvo %s. %s" % [var_to_str(expected), var_to_str(actual), msg])


func assert_ne(actual: Variant, other: Variant, msg: String = "") -> void:
	if deep_equal(actual, other):
		fail("no debía ser %s. %s" % [var_to_str(other), msg])


func assert_almost(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		fail("se esperaba %f ± %f y se obtuvo %f. %s" % [expected, eps, actual, msg])


func assert_between(actual: float, lo: float, hi: float, msg: String = "") -> void:
	if actual < lo or actual > hi:
		fail("se esperaba un valor entre %s y %s; se obtuvo %s. %s" % [lo, hi, actual, msg])


func assert_has(container: Variant, value: Variant, msg: String = "") -> void:
	var ok := false
	if typeof(container) == TYPE_DICTIONARY:
		ok = container.has(value)
	elif typeof(container) == TYPE_STRING:
		ok = str(container).contains(str(value))
	else:
		ok = value in container
	if not ok:
		fail("%s no contiene %s. %s" % [str(container).left(200), var_to_str(value), msg])


static func deep_equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	if (ta == TYPE_INT or ta == TYPE_FLOAT) and (tb == TYPE_INT or tb == TYPE_FLOAT):
		return is_equal_approx(float(a), float(b))
	if ta == TYPE_ARRAY or ta >= TYPE_PACKED_BYTE_ARRAY:
		if not (tb == TYPE_ARRAY or tb >= TYPE_PACKED_BYTE_ARRAY) or a.size() != b.size():
			return false
		for i in a.size():
			if not deep_equal(a[i], b[i]):
				return false
		return true
	if ta == TYPE_DICTIONARY:
		if tb != TYPE_DICTIONARY or a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not deep_equal(a[k], b[k]):
				return false
		return true
	if (ta == TYPE_STRING or ta == TYPE_STRING_NAME) and (tb == TYPE_STRING or tb == TYPE_STRING_NAME):
		return str(a) == str(b)
	return ta == tb and a == b


## Carpeta temporal única bajo user:// para pruebas que escriben archivos.
static func temp_dir(name: String) -> String:
	var path := "user://pruebas/%s_%d_%d" % [name, Time.get_ticks_usec(), randi()]
	DirAccess.make_dir_recursive_absolute(path)
	return path


static func remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d in DirAccess.get_directories_at(path):
		remove_tree(path.path_join(d))
	for f in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
