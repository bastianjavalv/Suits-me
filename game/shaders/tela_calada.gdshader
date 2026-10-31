// Tejidos calados o translúcidos: encaje, tul, gasa, flecos y velos (transparencia por tramado).
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/tela_comun.gdshaderinc"

global uniform float giro_reciente;

uniform vec4 color_principal : source_color = vec4(0.95, 0.93, 0.9, 1.0);
uniform int tipo = 0;                   // 0 encaje, 1 tul, 2 gasa, 3 flecos, 4 velo
uniform float opacidad : hint_range(0.0, 1.0) = 0.8;
uniform float escala = 90.0;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.7;
uniform float metalico : hint_range(0.0, 1.0) = 0.0;
uniform float vaiven : hint_range(0.0, 1.0) = 0.0;
instance uniform float cintura_local = 0.1;

void vertex() {
	if (vaiven > 0.0) {
		float caida = max(0.0, cintura_local - VERTEX.y);
		float a = giro_reciente * vaiven * caida * caida * 1.2;
		VERTEX.xz = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * VERTEX.xz;
	}
}

void fragment() {
	vec2 p = UV * escala;
	float a = opacidad;
	if (tipo == 0) { // encaje: red hexagonal con flores opacas
		vec2 g = fract(p) - 0.5;
		float r = length(g);
		float ang = atan(g.y, g.x);
		float flor = 1.0 - smoothstep(0.24 + 0.08 * cos(6.0 * ang), 0.3 + 0.08 * cos(6.0 * ang), r);
		vec2 h = abs(fract(p * 3.0) - 0.5);
		float red = 1.0 - smoothstep(0.05, 0.1, min(h.x, h.y));
		a = max(flor, red * 0.85);
	} else if (tipo == 1) { // tul: malla fina
		vec2 h = abs(fract(p * 2.0) - 0.5);
		a = opacidad * (0.5 + 0.5 * (1.0 - smoothstep(0.06, 0.16, min(h.x, h.y))));
	} else if (tipo == 3) { // flecos: hebras verticales
		float hebra = 1.0 - smoothstep(0.25, 0.45, abs(fract(UV.x * escala) - 0.5));
		a = hebra;
	}
	ALBEDO = color_principal.rgb * (0.92 + 0.08 * vnoise(UV * 40.0));
	ROUGHNESS = rugosidad;
	METALLIC = metalico;
	ALPHA = a;
	ALPHA_HASH_SCALE = 1.0;
}
