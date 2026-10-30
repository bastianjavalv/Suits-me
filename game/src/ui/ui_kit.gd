class_name UiKit
extends RefCounted
## Constructores pequeños de controles para las pantallas.


static func label(text: String, size: int = UiTheme.SIZE_BODY, color: Color = UiTheme.IVORY, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func title(text: String, size: int = UiTheme.SIZE_TITLE) -> Label:
	var l := label(text, size, UiTheme.IVORY)
	l.add_theme_font_override("font", UiTheme.title_font(size))
	return l


static func button(text: String, on_press: Callable, min_size: Vector2 = Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(on_press)
	return b


static func rich(bbcode: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.focus_mode = Control.FOCUS_NONE
	return r


static func panel(margin: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BG, Color(UiTheme.GOLD, 0.55), 1, margin))
	return p


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = true
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


static func spacer(h: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL if h == 0.0 else Control.SIZE_FILL
	return c


## Insignia de estado de una afirmación de la enciclopedia.
static func claim_badge(state: String) -> String:
	match state:
		"verificado":
			return "[color=#8cc68c]✔ verificado[/color]"
		"discutido":
			return "[color=#eebc5a]⚠ discutido[/color]"
	return "[color=#9fb7e6]◇ interpretación[/color]"


static func swatch(c1: Color, c2: Color, size: Vector2) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2.lerp(c1, 0.35))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 1)
	tex.width = 64
	tex.height = 64
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = size
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
