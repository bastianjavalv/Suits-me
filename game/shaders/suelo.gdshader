// Suelos procedurales de los escenarios: liso, losas de piedra, parqué en espiga, ajedrezado y brillante.
shader_type spatial;

#include "res://shaders/tela_comun.gdshaderinc"

uniform vec4 color_a : source_color = vec4(0.4, 0.38, 0.35, 1.0);
uniform vec4 color_b : source_color = vec4(0.3, 0.28, 0.26, 1.0);
uniform int modo = 0;           // 0 liso, 1 losas, 2 espiga, 3 ajedrez, 4 brillante
uniform float escala = 2.0;     // repeticiones por metro
uniform float rugosidad : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	vec2 p = UV * escala;
	vec3 c = color_a.rgb;
	float rough = rugosidad;
	float junta = 0.0;
	if (modo == 1) {
		vec2 g = vec2(p.x + 0.5 * mod(floor(p.y), 2.0), p.y);
		vec2 f = fract(g);
		junta = 1.0 - smoothstep(0.0, 0.03, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		c = mix(color_a.rgb, color_b.rgb, hash12(floor(g)) * 0.6 + vnoise(p * 6.0) * 0.4);
	} else if (modo == 2) {
		vec2 q = vec2(p.x + p.y, p.y - p.x) * 0.7071;
		float fila = floor(q.y * 2.0);
		float tabla = floor(q.x * 0.5 + 0.5 * mod(fila, 2.0));
		c = mix(color_a.rgb, color_b.rgb, hash12(vec2(tabla, fila)) * 0.7) * (0.92 + 0.08 * vnoise(vec2(q.x * 40.0, q.y * 2.0)));
		junta = 1.0 - smoothstep(0.0, 0.04, abs(fract(q.y * 2.0) - 0.5) * 2.0 - 0.94);
	} else if (modo == 3) {
		float k = mod(floor(p.x) + floor(p.y), 2.0);
		c = mix(color_a.rgb, color_b.rgb, k);
		rough = 0.35;
	} else if (modo == 4) {
		c = color_a.rgb;
		rough = 0.08;
	}
	ALBEDO = c * (1.0 - 0.35 * junta);
	ROUGHNESS = rough;
	SPECULAR = modo == 4 ? 0.8 : 0.4;
}
