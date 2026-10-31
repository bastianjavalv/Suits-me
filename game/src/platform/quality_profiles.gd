class_name QualityProfiles
extends RefCounted
## Perfiles gráficos "sobremesa" y "portatil" (res://data/config/calidad.json) y su aplicación.

const REQUIRED_KEYS: Array[String] = [
	"resolucion", "escala_3d", "escala_min", "escala_max", "msaa", "fxaa", "sombra_tamano",
	"sombra_filtro", "lod_umbral", "fps_objetivo", "segmentos_radiales", "anillos_por_metro", "textura_tejido",
]

var profiles: Dictionary = {}
var errors: Array[String] = []


func load_file(path: String) -> void:
	var doc := JsonUtil.load_object(path, errors)
	profiles = doc.get("perfiles", {})
	for mode in ["sobremesa", "portatil"]:
		if not profiles.has(mode):
			errors.append("%s: falta el perfil '%s'" % [path, mode])
			continue
		for k in REQUIRED_KEYS:
			if not profiles[mode].has(k):
				errors.append("%s: el perfil '%s' no define '%s'" % [path, mode, k])


func get_profile(mode: String) -> Dictionary:
	return profiles.get(mode, profiles.get("sobremesa", {}))


static func resolve_mode(setting: String, platform_mode: String) -> String:
	return setting if setting == "sobremesa" or setting == "portatil" else platform_mode


## Aplica el perfil al viewport principal y a los ajustes globales de sombras.
static func apply(viewport: Viewport, p: Dictionary) -> void:
	if p.is_empty():
		return
	var msaa := int(p["msaa"])
	viewport.msaa_3d = Viewport.MSAA_4X if msaa >= 4 else (Viewport.MSAA_2X if msaa >= 2 else Viewport.MSAA_DISABLED)
	# El renderizador Compatibility (GLES3, el del port homebrew de Switch) no tiene FXAA.
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.scaling_3d_scale = float(p["escala_3d"])
	viewport.mesh_lod_threshold = float(p["lod_umbral"])
	RenderingServer.directional_shadow_atlas_set_size(int(p["sombra_tamano"]), true)
	var filter := int(p["sombra_filtro"])
	RenderingServer.directional_soft_shadow_filter_set_quality(filter as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality(filter as RenderingServer.ShadowQuality)
	Engine.max_fps = int(p["fps_objetivo"]) if DisplayServer.get_name() != "headless" else 0
