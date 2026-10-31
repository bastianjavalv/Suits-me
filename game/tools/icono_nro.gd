extends SceneTree
## Genera el icono del NRO de Switch (JPEG de 256×256, sin transparencia) a partir de res://icon.svg:
##   godot --headless --path game -s res://tools/icono_nro.gd -- --salida=/ruta/icono.jpg

const SIZE := 256
## Fondo que sustituye la transparencia de las esquinas redondeadas del SVG.
const BACKGROUND := Color(0.118, 0.106, 0.141)


func _initialize() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--salida="):
			out = arg.trim_prefix("--salida=")
	if out.is_empty():
		printerr("Falta --salida=<ruta del JPEG>")
		quit(2)
		return
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	var image := Image.new()
	var err := image.load_svg_from_string(svg, 1.0)
	if err != OK:
		printerr("No se pudo leer res://icon.svg: ", error_string(err))
		quit(1)
		return
	if image.get_width() != SIZE or image.get_height() != SIZE:
		image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var flat := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	flat.fill(BACKGROUND)
	image.convert(Image.FORMAT_RGBA8)
	flat.blend_rect(image, Rect2i(0, 0, SIZE, SIZE), Vector2i.ZERO)
	flat.convert(Image.FORMAT_RGB8)
	err = flat.save_jpg(out, 0.92)
	if err != OK:
		printerr("No se pudo guardar ", out, ": ", error_string(err))
		quit(1)
		return
	print("icono: ", out)
	quit(0)
