class_name Defs
extends RefCounted
## Constantes compartidas por los sistemas del juego.

## Categorías de prenda = ranuras del conjunto, en orden de presentación.
const CATEGORIES: Array[String] = [
	"vestido", "parte_superior", "parte_inferior", "abrigo", "calzado", "tocado", "peinado",
	"maquillaje", "joyeria", "guantes", "bolso", "cinturon", "gafas", "complemento",
]

const CATEGORY_NAMES := {
	"vestido": "Vestidos",
	"parte_superior": "Partes de arriba",
	"parte_inferior": "Faldas y pantalones",
	"abrigo": "Abrigos y capas",
	"calzado": "Calzado",
	"tocado": "Sombreros y tocados",
	"peinado": "Peinados",
	"maquillaje": "Maquillaje",
	"joyeria": "Joyería",
	"guantes": "Guantes",
	"bolso": "Bolsos",
	"cinturon": "Cinturones",
	"gafas": "Gafas",
	"complemento": "Complementos de mano",
}

## Ranuras que cuentan como complementos para el criterio de creatividad.
const ACCESSORY_SLOTS: Array[String] = ["tocado", "joyeria", "guantes", "bolso", "cinturon", "gafas", "complemento"]

const SEASONS: Array[String] = ["primavera", "verano", "otono", "invierno"]
const SEASON_NAMES := {"primavera": "Primavera", "verano": "Verano", "otono": "Otoño", "invierno": "Invierno"}

const CURRENCIES: Array[String] = ["monedas", "gemas"]

## Origen de cada prenda del juego (para no confundir piezas reales con interpretaciones).
const PIECE_TYPES := {
	"interpretacion_de_epoca": "Diseño original del juego inspirado en la época",
	"reproduccion_historica": "Reproducción de una pieza histórica documentada",
	"original_del_juego": "Diseño original del juego sin referente histórico concreto",
}

const ATTRIBUTION_STATES := {
	"sin_atribucion": "Sin atribución: diseño original del juego",
	"documentada": "Atribución documentada en las fuentes citadas",
	"desconocida": "Autoría desconocida",
}

## Estado de verificación de cada afirmación de la enciclopedia.
const CLAIM_STATES := {
	"verificado": "Verificado en las fuentes citadas",
	"discutido": "Dato discutido entre fuentes",
	"interpretacion": "Interpretación, no un hecho documentado",
}

const COLOR_FAMILIES: Array[String] = [
	"blanco", "negro", "gris", "beige", "marron", "rojo", "naranja", "amarillo", "verde", "azul",
	"morado", "rosa", "dorado", "plateado",
]

const COLOR_FAMILY_NAMES := {
	"blanco": "Blanco y marfil", "negro": "Negro", "gris": "Gris", "beige": "Beige y crudo",
	"marron": "Marrón", "rojo": "Rojo", "naranja": "Naranja", "amarillo": "Amarillo", "verde": "Verde",
	"azul": "Azul", "morado": "Morado", "rosa": "Rosa", "dorado": "Dorado", "plateado": "Plateado",
}

const ID_PATTERN := "^[a-z0-9_]+$"


static func is_valid_id(id: String) -> bool:
	var re := RegEx.new()
	re.compile(ID_PATTERN)
	return re.search(id) != null


static func is_hex_color(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var s: String = value
	return s.length() == 7 and s.begins_with("#") and s.substr(1).is_valid_hex_number(false)
