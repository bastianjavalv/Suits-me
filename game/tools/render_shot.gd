extends SceneTree
## Herramienta de capturas: construye una escena de estudio con el maniquí y guarda un PNG.
##   xvfb-run godot --path game -s res://tools/render_shot.gd -- --salida=ruta.png [--yaw=30] [--pose=id]

func _initialize() -> void:
	var out := "user://captura.png"
	var yaw := 20.0
	var plano := "cuerpo"
	var pose_id := ""
	var outfit_ids: Array = []
	var size := Vector2i(960, 1080)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--salida="):
			out = a.trim_prefix("--salida=")
		elif a.begins_with("--yaw="):
			yaw = float(a.trim_prefix("--yaw="))
		elif a.begins_with("--plano="):
			plano = a.trim_prefix("--plano=")
		elif a.begins_with("--pose="):
			pose_id = a.trim_prefix("--pose=")
		elif a.begins_with("--conjunto="):
			outfit_ids = a.trim_prefix("--conjunto=").split(",")
	root.size = size
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.15, 0.17)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.environment.ambient_light_energy = 0.45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment.tonemap_exposure = 0.9
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.1
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -120, 0)
	fill.light_energy = 0.45
	world.add_child(fill)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6, 6)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.28, 0.27)
	fm.roughness = 0.8
	floor.material_override = fm
	world.add_child(floor)
	var catalog := Catalog.new()
	catalog.load_files(["res://tests/fixtures/prendas_muestra.json"])
	var fabric_doc := JsonUtil.load_object("res://data/tejidos.json", [])
	var view := OutfitView.new()
	world.add_child(view)
	view.setup(catalog, fabric_doc.get("tejidos", {}), {"segmentos_radiales": 48, "anillos_por_metro": 40})
	var slots := {}
	for id in outfit_ids:
		var it := catalog.get_item(id)
		if not it.is_empty():
			slots[it["categoria"]] = id
	view.show_outfit(slots)
	print("Piezas: ", view.stats())
	view.yaw = yaw
	view._yaw_shown = yaw
	var m: Mannequin = view.mannequin
	if not pose_id.is_empty():
		var doc := JsonUtil.load_object("res://data/poses.json", [])
		for p in doc.get("poses", []):
			if p["id"] == pose_id:
				m.apply_pose(Mannequin.pose_from_json(p), 0.0)
	var cam := Camera3D.new()
	cam.fov = 30
	var target := Vector3(0, 0.9, 0)
	cam.position = Vector3(0, 0.95, 4.3)
	if plano == "cabeza":
		target = Vector3(0, 1.66, 0)
		cam.position = Vector3(0, 1.68, 0.75)
	elif plano == "torso":
		target = Vector3(0, 1.2, 0)
		cam.position = Vector3(0, 1.25, 2.0)
	cam.look_at_from_position(cam.position, target)
	world.add_child(cam)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("Captura guardada: ", out, " ", img.get_size())
	quit()
