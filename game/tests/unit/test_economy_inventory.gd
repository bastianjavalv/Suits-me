extends TestCase

const DATA := "res://tests/fixtures/data"


func _catalog() -> Catalog:
	var c := Catalog.new()
	c.load_files([DATA + "/prendas/prueba.json"])
	return c


func test_economia_ilimitada_nunca_rechaza_ni_descuenta() -> void:
	var eco := Economy.new()
	eco.configure({"modo": "ilimitado"})
	for i in 1000:
		assert_true(eco.spend("gemas", 999999, "prueba", float(i)))
	assert_eq(eco.balance("gemas"), 0, "el saldo no se toca en modo ilimitado")
	assert_eq(eco.display_balance("monedas"), "∞")
	assert_eq(eco.display_balance("gemas"), "∞")
	assert_true(eco.can_afford("monedas", 2147483647))
	assert_eq(eco.ledger.size(), Economy.MAX_LEDGER, "el historial de movimientos está acotado")


func test_economia_finita_para_pruebas() -> void:
	var eco := Economy.new()
	eco.configure({"modo": "finito", "saldo_inicial": {"monedas": 100, "gemas": 1}})
	assert_true(eco.spend("monedas", 60, "a", 0.0))
	assert_false(eco.spend("monedas", 60, "b", 0.0))
	assert_eq(eco.balance("monedas"), 40)
	assert_false(eco.spend("diamantes", 1, "moneda inexistente", 0.0))
	assert_false(eco.spend("monedas", -5, "negativo", 0.0))


func test_economia_persiste() -> void:
	var eco := Economy.new()
	eco.spend("monedas", 10, "compra", 5.0)
	var copy := Economy.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(eco.to_dict())))
	assert_true(copy.unlimited)
	assert_eq(copy.ledger.size(), 1)


func test_adquisiciones_permanentes_sin_duplicados() -> void:
	var c := _catalog()
	var eco := Economy.new()
	var inv := Inventory.new()
	assert_eq(inv.acquire(c, eco, "a_vestido_negro", 1.0), Inventory.Result.ACQUIRED)
	assert_eq(inv.acquire(c, eco, "a_vestido_negro", 2.0), Inventory.Result.ALREADY_OWNED)
	assert_eq(inv.acquire(c, eco, "no_existe", 2.0), Inventory.Result.UNKNOWN_ITEM)
	assert_eq(inv.owned_ids(), ["a_vestido_negro"])
	assert_eq(eco.ledger.size(), 1, "comprar algo que ya tienes no cobra")
	assert_eq(inv.acquire_all(c, eco, 3.0), c.size() - 1)
	assert_eq(inv.acquire_all(c, eco, 4.0), 0)


func test_economia_finita_sin_saldo_no_entrega_la_prenda() -> void:
	var c := _catalog()
	var eco := Economy.new()
	eco.configure({"modo": "finito", "saldo_inicial": {"monedas": 0, "gemas": 0}})
	var inv := Inventory.new()
	assert_eq(inv.acquire(c, eco, "a_collar_perlas", 1.0), Inventory.Result.CANNOT_AFFORD)
	assert_false(inv.owns("a_collar_perlas"))


func test_favoritas_y_huerfanas_se_conservan() -> void:
	var c := _catalog()
	var inv := Inventory.new()
	inv.load_dict({"adquiridas": {"a_vestido_marfil": 1.0, "prenda_retirada": 2.0},
		"favoritas": ["a_vestido_marfil", "prenda_retirada"]}, c)
	assert_true(inv.owns("a_vestido_marfil"))
	assert_false(inv.owns("prenda_retirada"), "no se ofrece en el juego si ya no existe")
	assert_has(inv.to_dict()["adquiridas"], "prenda_retirada", "pero no se pierde al volver a guardar")
	assert_true(inv.toggle_favorite("a_zapatos_dorados"))
	assert_false(inv.toggle_favorite("a_zapatos_dorados"))
	assert_true(inv.is_favorite("a_vestido_marfil"))
