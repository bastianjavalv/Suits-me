class_name Economy
extends RefCounted
## Economía local. En modo ilimitado (el predeterminado) monedas y gemas son infinitas:
## toda compra se aprueba y nunca se descuenta saldo. No hay pagos reales ni conexión.

signal changed

const MAX_LEDGER := 200

var unlimited: bool = true
var balances: Dictionary = {"monedas": 0, "gemas": 0}
var ledger: Array = []  ## [{t, concepto, moneda, valor}]


func configure(config: Dictionary) -> void:
	unlimited = str(config.get("modo", "ilimitado")) == "ilimitado"
	var start: Dictionary = config.get("saldo_inicial", {})
	for cur in Defs.CURRENCIES:
		balances[cur] = int(start.get(cur, 0))


func balance(currency: String) -> int:
	return int(balances.get(currency, 0))


func display_balance(currency: String) -> String:
	return "∞" if unlimited else str(balance(currency))


func can_afford(currency: String, amount: int) -> bool:
	return unlimited or balance(currency) >= amount


## Registra un gasto. Devuelve false solo si el modo finito no tiene saldo suficiente.
func spend(currency: String, amount: int, concept: String, now: float) -> bool:
	if not Defs.CURRENCIES.has(currency) or amount < 0:
		return false
	if not can_afford(currency, amount):
		return false
	if not unlimited:
		balances[currency] = balance(currency) - amount
	ledger.append({"t": now, "concepto": concept, "moneda": currency, "valor": amount})
	if ledger.size() > MAX_LEDGER:
		ledger = ledger.slice(ledger.size() - MAX_LEDGER)
	changed.emit()
	return true


func grant(currency: String, amount: int) -> void:
	if not unlimited and Defs.CURRENCIES.has(currency) and amount > 0:
		balances[currency] = balance(currency) + amount
		changed.emit()


func to_dict() -> Dictionary:
	return {"ilimitado": unlimited, "saldos": balances.duplicate(), "movimientos": ledger.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	unlimited = bool(d.get("ilimitado", true))
	var saved: Dictionary = d.get("saldos", {})
	for cur in Defs.CURRENCIES:
		balances[cur] = int(saved.get(cur, 0))
	ledger = d.get("movimientos", []).duplicate(true)
	changed.emit()
