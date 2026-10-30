// Funciones comunes de los tejidos procedurales de Atelier de las Eras.
// Coordenadas: UV en metros (arco, altura); UV2.x = 0 espalda, 0.5 centro delantero; UV2.y = 0 bajo, 1 parte superior.

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Distancia al centro de celda más cercano (Voronoi simple 3x3).
float voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(i + g);
			d = min(d, length(g + o - f));
		}
	}
	return d;
}

// Altura del ligamento en coordenadas de hilo p. modo: 0 tafetán, 1 sarga 3/1, 2 raso, 3 punto.
// devuelve (altura, urdimbre_visible)
vec2 ligamento(vec2 p, int modo) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	float urdimbre;
	if (modo == 1) {
		urdimbre = mod(c.x - c.y, 4.0) < 3.0 ? 1.0 : 0.0;
	} else if (modo == 2) {
		urdimbre = mod(c.x * 2.0 + c.y, 5.0) < 0.5 ? 0.0 : 1.0;
	} else if (modo == 3) {
		float v = fract(p.y * 0.5 + abs(f.x - 0.5));
		return vec2(sin(3.14159 * v) * sin(3.14159 * f.x), 1.0);
	} else {
		urdimbre = mod(c.x + c.y, 2.0);
	}
	float hu = sin(3.14159 * f.x) * (0.65 + 0.35 * sin(3.14159 * f.y));
	float ht = sin(3.14159 * f.y) * (0.65 + 0.35 * sin(3.14159 * f.x));
	return vec2(mix(ht, hu, urdimbre), urdimbre);
}

// Patrón de estampado sobre UV en metros: devuelve la mezcla (0 = color principal, 1 = secundario).
float estampado_valor(int tipo, vec2 uv, vec2 uv2, float escala) {
	vec2 p = uv * escala;
	vec2 w = fwidth(p) + 1e-4;
	if (tipo == 1) { // lunares
		vec2 g = fract(p + vec2(0.5 * mod(floor(p.y), 2.0), 0.0)) - 0.5;
		return 1.0 - smoothstep(0.22 - w.x, 0.22 + w.x, length(g));
	} else if (tipo == 2) { // rayas verticales
		return smoothstep(0.5 - w.x, 0.5 + w.x, fract(p.x)) * (1.0 - smoothstep(1.0 - w.x, 1.0, fract(p.x)));
	} else if (tipo == 3) { // cuadros vichy
		float a = step(0.5, fract(p.x));
		float b = step(0.5, fract(p.y));
		return (a + b) * 0.5;
	} else if (tipo == 4) { // tartán
		float sx = step(0.62, fract(p.x)) * 0.6 + step(0.9, fract(p.x * 3.0)) * 0.4;
		float sy = step(0.62, fract(p.y)) * 0.6 + step(0.9, fract(p.y * 3.0)) * 0.4;
		return clamp(max(sx, sy) * 0.85 + sx * sy * 0.3, 0.0, 1.0);
	} else if (tipo == 5) { // floral
		vec2 g = fract(p) - 0.5;
		float r = length(g);
		float a = atan(g.y, g.x);
		float petalo = 0.26 + 0.09 * cos(5.0 * a);
		float flor = 1.0 - smoothstep(petalo - 0.02, petalo + 0.02, r);
		return max(flor, 0.0);
	} else if (tipo == 6) { // geométrico art déco (abanicos escalonados)
		vec2 g = vec2(fract(p.x), fract(p.y + 0.5 * mod(floor(p.x), 2.0)));
		float r = length(g - vec2(0.5, 0.0));
		float arco = step(0.5, fract(r * 6.0)) * step(r, 0.5);
		return arco;
	} else if (tipo == 7) { // op art: ajedrez deformado
		vec2 q = p + 0.35 * sin(p.yx * 1.7);
		return step(0.0, sin(3.14159 * q.x) * sin(3.14159 * q.y));
	} else if (tipo == 8) { // bloques de color en retícula (inspiración neoplasticista)
		float x = uv2.x;
		float y = uv2.y;
		float lineas = step(abs(x - 0.42), 0.006) + step(abs(x - 0.6), 0.006) + step(abs(y - 0.62), 0.008) + step(abs(y - 0.3), 0.008);
		return clamp(lineas, 0.0, 1.0);
	} else if (tipo == 9) { // damasco
		vec2 g = abs(fract(p) - 0.5);
		float m = length(g - vec2(0.14, 0.22)) - 0.12;
		m = min(m, length(g - vec2(0.0, 0.05)) - 0.1);
		return 1.0 - smoothstep(-0.01, 0.01, m);
	} else if (tipo == 10) { // leopardo
		float d = voronoi(p * 1.3);
		return smoothstep(0.18, 0.24, d) * (1.0 - smoothstep(0.32, 0.38, d));
	} else if (tipo == 11) { // pata de gallo
		vec2 c = floor(p * 4.0);
		vec2 f = fract(p * 4.0);
		float cuadro = mod(c.x + c.y, 2.0);
		float diagonal = step(f.x + f.y, 1.0);
		return mod(cuadro + diagonal * step(1.0, mod(c.x, 2.0)), 2.0);
	} else if (tipo == 12) { // raya diplomática
		return smoothstep(0.94 - w.x, 0.94 + w.x, fract(p.x));
	}
	return 0.0;
}

// Costuras: espalda, costados y pespunte del bajo. Devuelve (surco 0..1, puntada 0..1).
vec2 costuras(vec2 uv, vec2 uv2, float contorno, float largo) {
	float x = fract(uv2.x);
	float dx = min(min(abs(x - 0.25), abs(x - 0.75)), min(x, 1.0 - x)) * contorno;
	float surco = 1.0 - smoothstep(0.0008, 0.0025, dx);
	float bajo = uv2.y * largo;
	float pespunte = (1.0 - smoothstep(0.0006, 0.0014, abs(bajo - 0.012))) * step(0.45, fract(uv.x * 260.0));
	float lateral = (1.0 - smoothstep(0.0005, 0.0012, abs(dx - 0.004))) * step(0.45, fract(uv.y * 260.0));
	return vec2(surco, max(pespunte, lateral));
}
