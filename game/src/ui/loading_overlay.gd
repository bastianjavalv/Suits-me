class_name LoadingOverlay
extends Control
## Pantalla «Preparando gráficos…»: cubre el juego mientras App precompila los sombreadores (GLES3, el
## renderizador del NRO de Switch, compila cada sombreador la primera vez que se dibuja).

var _bar: ProgressBar
var _detail: Label


func _ready() -> void:
	name = "PantallaDeCarga"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(UiTheme.BG_SOLID, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := UiKit.vbox(20)
	box.custom_minimum_size = Vector2(820, 0)
	center.add_child(box)
	var title := UiKit.title("Atelier de las Eras", UiTheme.SIZE_HUGE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var label := UiKit.label("Preparando gráficos…", UiTheme.SIZE_BODY, UiTheme.GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.add_theme_stylebox_override("background", UiTheme.box(UiTheme.CARD, UiTheme.MUTED, 1, 0))
	_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.GOLD, UiTheme.GOLD, 0, 0))
	box.add_child(_bar)
	_detail = UiKit.label("Se compilan los sombreadores en cada arranque; tarda unos segundos.", UiTheme.SIZE_SMALL,
		UiTheme.MUTED, true)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_detail)


func set_progress(value: float, detail: String = "") -> void:
	_bar.value = clampf(value, 0.0, 1.0)
	if not detail.is_empty():
		_detail.text = detail


func progress() -> float:
	return _bar.value
