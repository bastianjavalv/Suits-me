// Tejido opaco PBR procedural. Ver docs/08-pipeline-de-arte.md para los parámetros de cada tejido.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/tela_comun.gdshaderinc"

global uniform float giro_reciente;

uniform vec4 color_principal : source_color = vec4(0.8, 0.78, 0.75, 1.0);
uniform vec4 color_secundario : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform vec4 color_trama : source_color = vec4(0.92, 0.9, 0.86, 1.0);
uniform int ligamento_modo = 0;         // 0 tafetán, 1 sarga, 2 raso, 3 punto, -1 sin ligamento
uniform int estampado = 0;
uniform float escala_hilo = 140.0;      // hilos visibles por metro (estilizado)
uniform float escala_estampado = 8.0;   // repeticiones por metro
uniform float rugosidad : hint_range(0.0, 1.0) = 0.8;
uniform float metalico : hint_range(0.0, 1.0) = 0.0;
uniform float anisotropia : hint_range(-1.0, 1.0) = 0.0;
uniform vec2 flujo_anisotropia = vec2(1.0, 0.0);
uniform float brillo_borde : hint_range(0.0, 1.0) = 0.0;
uniform float tinte_borde : hint_range(0.0, 1.0) = 0.5;
uniform float relieve : hint_range(0.0, 2.0) = 0.6;
uniform float capa_brillo : hint_range(0.0, 1.0) = 0.0;
uniform float mezcla_trama : hint_range(0.0, 1.0) = 0.0;  // denim: hilo blanco de la trama visible
uniform int acabado = 0;                // 0 normal, 1 lentejuelas, 2 cuero, 3 pelo/terciopelo, 4 brocado metálico
uniform float costura_intensidad : hint_range(0.0, 1.0) = 1.0;
uniform float vaiven : hint_range(0.0, 1.0) = 0.0;  // 1 en faldas: el bajo se mece al girar
instance uniform float contorno = 0.9;
instance uniform float largo = 0.6;
instance uniform float cintura_local = 0.1;

varying vec3 pos_local;

void vertex() {
	pos_local = VERTEX;
	if (vaiven > 0.0) {
		float caida = max(0.0, cintura_local - VERTEX.y);
		float a = giro_reciente * vaiven * caida * caida * 0.8;
		VERTEX.xz = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * VERTEX.xz;
	}
}

void fragment() {
	vec2 p = UV * escala_hilo;
	float filtro = 1.0 - smoothstep(0.35, 0.9, max(fwidth(p).x, fwidth(p).y));
	vec3 base = color_principal.rgb;
	float mezcla = estampado > 0 ? estampado_valor(estampado, UV, UV2, escala_estampado) : 0.0;
	base = mix(base, color_secundario.rgb, mezcla);
	vec2 n2 = vec2(0.0);
	float metal = metalico;
	float rough = rugosidad;
	if (ligamento_modo >= 0) {
		float e = 0.06;
		vec2 h0 = ligamento(p, ligamento_modo);
		float hx = ligamento(p + vec2(e, 0.0), ligamento_modo).x;
		float hy = ligamento(p + vec2(0.0, e), ligamento_modo).x;
		n2 = vec2(h0.x - hx, h0.x - hy) / e * 0.18 * relieve * filtro;
		if (mezcla_trama > 0.0) {
			float trama = (1.0 - h0.y) * filtro;
			base = mix(base, color_trama.rgb * (0.85 + 0.15 * vnoise(p * 0.05)), trama * mezcla_trama);
		}
		base *= 0.9 + 0.1 * mix(1.0, h0.x, filtro);
		base *= 0.94 + 0.12 * vnoise(UV * 9.0);
	}
	if (acabado == 1) { // lentejuelas: discos con inclinación aleatoria que destellan
		vec2 q = UV * 160.0;
		q.x += 0.5 * mod(floor(q.y), 2.0);
		vec2 c = floor(q);
		vec2 g = fract(q) - 0.5;
		vec2 tilt = (hash22(c) - 0.5) * 1.6;
		float disco = 1.0 - smoothstep(0.42, 0.48, length(g));
		n2 = mix(n2, tilt, disco * filtro);
		metal = mix(metal, 0.9, disco);
		rough = mix(rough, 0.18, disco);
	} else if (acabado == 2) { // cuero: grano Voronoi
		float d = voronoi(UV * 900.0);
		float dx = voronoi(UV * 900.0 + vec2(0.05, 0.0)) - d;
		float dy = voronoi(UV * 900.0 + vec2(0.0, 0.05)) - d;
		n2 += vec2(dx, dy) * 4.0 * relieve * filtro;
		base *= 0.92 + 0.08 * d;
	} else if (acabado == 3) { // pelo: terciopelo, lana cardada, piel sintética
		float f = vnoise(UV * 700.0) * 0.6 + vnoise(UV * 160.0) * 0.4;
		n2 += (vec2(vnoise(UV * 700.0 + 3.1), vnoise(UV * 700.0 + 7.7)) - 0.5) * 0.5 * relieve * filtro;
		base *= 0.85 + 0.25 * f;
	} else if (acabado == 4) { // brocado: motivo en hilo metálico
		float motivo = estampado_valor(9, UV, UV2, escala_estampado);
		metal = mix(metal, 0.85, motivo);
		rough = mix(rough, 0.35, motivo);
		base = mix(base, color_secundario.rgb, motivo);
	}
	vec2 cs = costuras(UV, UV2, contorno, largo);
	base *= 1.0 - 0.18 * cs.x * costura_intensidad;
	base = mix(base, base * 1.25 + 0.04, cs.y * 0.5 * costura_intensidad);
	n2 += vec2(cs.x * 0.35 * costura_intensidad, 0.0);
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.4;
	NORMAL_MAP = normalize(vec3(n2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	if (anisotropia != 0.0) {
		ANISOTROPY = anisotropia;
		ANISOTROPY_FLOW = flujo_anisotropia;
	}
	RIM = brillo_borde;
	RIM_TINT = tinte_borde;
	CLEARCOAT = capa_brillo;
	CLEARCOAT_ROUGHNESS = 0.15;
}
