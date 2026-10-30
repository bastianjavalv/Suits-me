class_name UiTheme
extends RefCounted
## Tema visual: paneles oscuros translúcidos con filete dorado, texto marfil, Playfair Display
## para títulos y Jost para el texto. El foco del mando es un borde dorado grueso y bien visible.

const BG := Color(0.075, 0.068, 0.082, 0.86)
const BG_SOLID := Color(0.075, 0.068, 0.082, 0.97)
const CARD := Color(0.13, 0.12, 0.14, 0.92)
const CARD_HOVER := Color(0.19, 0.17, 0.2, 0.95)
const GOLD := Color(0.79, 0.66, 0.38)
const IVORY := Color(0.94, 0.91, 0.85)
const MUTED := Color(0.68, 0.64, 0.6)
const OK := Color(0.55, 0.78, 0.55)
const WARN := Color(0.93, 0.74, 0.35)
const INFO := Color(0.62, 0.72, 0.9)

const BODY_FONT := preload("res://assets/fonts/Jost-Variable.ttf")
const TITLE_FONT := preload("res://assets/fonts/PlayfairDisplay-Variable.ttf")

## Tamaños base para 1920×1080; en portátil (1280×720) se escalan con el lienzo, por eso el
## texto más pequeño (22 px) sigue midiendo unos 15 px reales, el mínimo legible que nos fijamos.
const SIZE_SMALL := 22
const SIZE_BODY := 26
const SIZE_TITLE := 44
const SIZE_HUGE := 76


static func make(text_scale: float = 1.0) -> Theme:
	var t := Theme.new()
	var body := FontVariation.new()
	body.base_font = BODY_FONT
	body.variation_opentype = {"wght": 420}
	var bold := FontVariation.new()
	bold.base_font = BODY_FONT
	bold.variation_opentype = {"wght": 600}
	t.default_font = body
	t.default_font_size = roundi(SIZE_BODY * text_scale)
	for type in ["Label", "Button", "CheckBox", "OptionButton", "LineEdit", "RichTextLabel", "PopupMenu"]:
		t.set_color("font_color", type, IVORY)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("default_color", "RichTextLabel", IVORY)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_font_size("normal_font_size", "RichTextLabel", roundi(SIZE_BODY * text_scale))
	t.set_font_size("bold_font_size", "RichTextLabel", roundi(SIZE_BODY * text_scale))
	t.set_stylebox("normal", "Button", box(CARD, Color(1, 1, 1, 0.08), 1))
	t.set_stylebox("hover", "Button", box(CARD_HOVER, Color(1, 1, 1, 0.18), 1))
	t.set_stylebox("pressed", "Button", box(CARD_HOVER, GOLD, 2))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), GOLD, 4))
	t.set_stylebox("disabled", "Button", box(Color(0.1, 0.1, 0.1, 0.6), Color(1, 1, 1, 0.05), 1))
	for type in ["CheckBox", "OptionButton"]:
		t.set_stylebox("normal", type, box(CARD, Color(1, 1, 1, 0.08), 1))
		t.set_stylebox("hover", type, box(CARD_HOVER, Color(1, 1, 1, 0.18), 1))
		t.set_stylebox("focus", type, box(Color(0, 0, 0, 0), GOLD, 4))
		t.set_stylebox("pressed", type, box(CARD_HOVER, GOLD, 2))
	t.set_stylebox("panel", "Panel", box(BG, Color(GOLD, 0.55), 1))
	t.set_stylebox("panel", "PanelContainer", box(BG, Color(GOLD, 0.55), 1, 18))
	t.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.2), 1))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0.4), GOLD, 3))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 14)
	t.set_constant("v_separation", "GridContainer", 14)
	return t


static func box(bg: Color, border: Color, width: int, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(margin)
	return s


static func title_font(size: int, weight: int = 600) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = TITLE_FONT
	f.variation_opentype = {"wght": weight}
	return f
