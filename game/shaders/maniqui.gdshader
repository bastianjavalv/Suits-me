// Superficie del maniquí de exhibición con zonas de maquillaje pintado (solo en la cabeza).
shader_type spatial;

uniform vec4 color_piel : source_color = vec4(0.62, 0.59, 0.55, 1.0);
uniform float rugosidad : hint_range(0.0, 1.0) = 0.6;
uniform bool es_cabeza = false;
uniform vec4 labios : source_color = vec4(0.62, 0.12, 0.16, 0.0);     // alfa = intensidad
uniform vec4 sombra : source_color = vec4(0.36, 0.3, 0.38, 0.0);
uniform vec4 colorete : source_color = vec4(0.86, 0.5, 0.48, 0.0);
uniform float delineado : hint_range(0.0, 1.0) = 0.0;
uniform float rabillo : hint_range(0.0, 1.0) = 0.0;                   // delineado en «ojo de gato»
uniform float cejas : hint_range(0.0, 1.0) = 0.25;
uniform vec4 color_cejas : source_color = vec4(0.42, 0.36, 0.32, 1.0);

float elipse(vec2 q, vec2 c, vec2 r) {
	return 1.0 - smoothstep(0.65, 1.0, length((q - c) / r));
}

void fragment() {
	vec3 c = color_piel.rgb;
	if (es_cabeza) {
		vec2 q = UV2;
		for (int i = 0; i < 2; i++) {
			float s = i == 0 ? -1.0 : 1.0;
			float ojo_x = 0.5 + s * 0.052;
			c = mix(c, sombra.rgb, sombra.a * elipse(q, vec2(ojo_x, 0.585), vec2(0.03, 0.03)));
			float linea = (1.0 - smoothstep(0.003, 0.006, abs(q.y - 0.556 - rabillo * max(0.0, (q.x - ojo_x) * s) * 0.6)))
				* step(abs(q.x - ojo_x - s * 0.006 * rabillo), 0.024 + 0.012 * rabillo);
			c = mix(c, vec3(0.06, 0.05, 0.05), delineado * linea);
			float ceja = (1.0 - smoothstep(0.003, 0.0065, abs(q.y - 0.64 - 0.012 * sin(3.14159 * clamp((q.x - ojo_x) * s / 0.05 + 0.5, 0.0, 1.0)))))
				* step(abs(q.x - ojo_x), 0.028);
			c = mix(c, color_cejas.rgb, cejas * ceja);
			c = mix(c, colorete.rgb, colorete.a * 0.6 * elipse(q, vec2(0.5 + s * 0.095, 0.46), vec2(0.04, 0.05)));
		}
		c = mix(c, labios.rgb, labios.a * elipse(q, vec2(0.5, 0.292), vec2(0.03, 0.02)));
	}
	ALBEDO = c;
	ROUGHNESS = rugosidad;
	RIM = 0.2;
	RIM_TINT = 0.5;
}
