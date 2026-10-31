extends SceneTree
## Capturas por época y medición de rendimiento de una escena compleja.
##   xvfb-run godot --path game -s res://tools/capturas_rendimiento.gd -- --salida=DIR --modo=sobremesa|portatil [--cuadros=600]
## Los números dependen del equipo: en un contenedor sin GPU (renderizado por software) NO
## representan el rendimiento en Nintendo Switch. Las métricas de geometría sí son independientes.

const ESCAPARATE := {
	"medieval": ["med_hopalanda_verde", "med_tocado_conico", "med_poulaines", "med_cinturon_ancho"],
	"belle_epoque": ["be_blusa_jamon", "be_falda_campana", "be_pamela_plumas", "be_recogido", "be_botines", "be_sombrilla"],
	"anos20": ["a20_vestido_cuentas", "a20_cloche", "a20_bob", "a20_sautoir", "a20_zapatos_correa", "a20_maquillaje"],
	"anos30": ["a30_vestido_bies", "a30_ondas", "a30_guantes_largos", "a30_sandalias_plata"],
	"anos40": ["a40_chaqueta_peplum", "a40_falda_corola", "a40_rulos", "a40_zapatos_cuna"],
	"anos50": ["a50_vestido_coctel", "a50_salones_aguja", "a50_coleta", "a50_gafas_gato", "a50_guantes_cortos", "a50_bolso_rigido"],
	"anos60": ["a60_vestido_espacial", "a60_botas_blancas", "a60_casquete", "a60_cardado", "a60_maquillaje"],
	"anos80": ["a80_chaqueta_poder", "a80_falda_tubo", "a80_melena_voluminosa", "a80_aros", "a80_salones_color"],
	"anos90": ["a90_camisa_cuadros", "a90_vaqueros", "a90_botas_cordones", "a90_liso", "a90_gafas_ovaladas"],
}
const COMPLEJO := ["a50_vestido_coctel", "a50_chaqueta_tweed", "a20_cloche", "a40_rulos", "a20_sautoir", "a30_guantes_largos",
	"a50_bolso_rigido", "med_cinturon_ancho", "a50_gafas_gato", "be_sombrilla", "a50_salones_aguja", "a20_maquillaje"]


func _initialize() -> void:
	var out := "user://capturas"
	var mode := "sobremesa"
	var frames := 600
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--salida="):
			out = a.trim_prefix("--salida=")
		elif a.begins_with("--modo="):
			mode = a.trim_prefix("--modo=")
		elif a.begins_with("--cuadros="):
			frames = int(a.trim_prefix("--cuadros="))
	DirAccess.make_dir_recursive_absolute(out)
	var tmp := "user://pruebas_integracion/capturas_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(tmp)
	var game := root.get_node("Game")
	game.initialize("res://data", tmp, tmp.path_join("galeria"))
	root.get_node("Platform").force_mode(mode)
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await _wait(8)
	app.host.visible = false
	var res: Vector2i = Vector2i(app.profile["resolucion"][0], app.profile["resolucion"][1])
	root.size = res
	DisplayServer.window_set_size(res)
	await _wait(4)
	for era_id in ESCAPARATE:
		app.set_stage(game.era_by_id[era_id]["escenario"])
		var slots := {}
		for id in ESCAPARATE[era_id]:
			slots[game.catalog.get_item(id)["categoria"]] = id
		game.outfit.load_dict(slots, game.catalog)
		app.view.yaw = 22.0
		app.view._yaw_shown = 22.0
		app.rig.reset()
		await _wait(10)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("era_%s_%s.png" % [era_id, mode]))
		print("captura ", era_id)
	# Escena compleja para medir.
	app.set_stage("memphis_neon")
	var slots2 := {}
	for id in COMPLEJO:
		slots2[game.catalog.get_item(id)["categoria"]] = id
	game.outfit.load_dict(slots2, game.catalog)
	await _wait(30)
	var probe := PerfProbe.new()
	var t0 := Time.get_ticks_usec()
	for i in frames:
		app.view.rotate_by(1.2)
		await process_frame
		var now := Time.get_ticks_usec()
		probe.add((now - t0) / 1000.0,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		t0 = now
	var report := probe.report()
	report["modo"] = mode
	report["resolucion"] = [res.x, res.y]
	report["escena"] = app.view.stats()
	report["prendas"] = slots2.size()
	report["adaptador"] = RenderingServer.get_video_adapter_name()
	report["renderizador"] = RenderingServer.get_current_rendering_method()
	report["fecha"] = Time.get_datetime_string_from_system(true)
	report["nota"] = "Medición en el equipo indicado en 'adaptador'. Un renderizador por software (llvmpipe) no representa el rendimiento de Nintendo Switch."
	var f := FileAccess.open(out.path_join("rendimiento_%s.json" % mode), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t", true))
	f.close()
	print(JSON.stringify(report))
	quit()


func _wait(n: int) -> void:
	for i in n:
		await process_frame
