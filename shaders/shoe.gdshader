// Sabatilles (ShoeMesh): els colors els tria cada jugador; els dibuixos es fan aquí a
// partir de la posició dins la sabatilla, que porta el color del vèrtex: r = costat (0,5
// al mig, 1 a fora), g = del taló a la punta, b = alçada, a = 1 a la sola.
shader_type spatial;

instance uniform vec3 upper : source_color = vec3(0.11);
instance uniform vec3 accent : source_color = vec3(0.95);
instance uniform vec3 sole : source_color = vec3(0.93);

varying vec4 shoe;

void vertex() {
	shoe = COLOR;
}

// 1 entre a i b, amb les vores suavitzades segons la mida del píxel.
float band(float x, float a, float b) {
	float w = fwidth(x);
	return smoothstep(a - w, a + w, x) - smoothstep(b - w, b + w, x);
}

void fragment() {
	float side = abs(shoe.r - 0.5) * 2.0;
	bool outer = shoe.r > 0.5;
	float t = shoe.g;
	float h = shoe.b;
	vec3 col = upper;
	float rough = 0.55;
	if (shoe.a > 0.5) {
		// Sola: la goma de sota, més fosca.
		col = mix(sole * 0.3, sole, smoothstep(0.04, 0.09, h));
		rough = 0.75;
	} else {
		// Tres ratlles en diagonal als costats.
		float u = t + h * 0.45;
		float stripes = band(u, 0.47, 0.5) + band(u, 0.53, 0.56) + band(u, 0.59, 0.62);
		stripes *= smoothstep(0.55, 0.75, side) * (1.0 - smoothstep(0.8, 0.9, h));
		col = mix(col, accent, clamp(stripes, 0.0, 1.0));
		// Taló i punta reforçats, una mica més foscos.
		float cap = smoothstep(0.86, 0.92, t) + 1.0 - smoothstep(0.08, 0.14, t);
		col = mix(col, col * 0.62, clamp(cap, 0.0, 1.0) * 0.7);
		// Cordons: al mig de dalt, fets de bandes transversals.
		float laces = (1.0 - smoothstep(0.14, 0.2, side)) * band(t, 0.35, 0.64);
		laces *= smoothstep(0.42, 0.5, h);
		float lace = smoothstep(0.55, 0.7, abs(fract(t * 36.0) - 0.5) * 2.0);
		col = mix(col, mix(col * 0.7, accent, lace), laces);
		// Pestanya del taló, del color de les ratlles.
		col = mix(col, accent, (1.0 - smoothstep(0.04, 0.07, t)) * smoothstep(0.7, 0.8, h));
		// Logotip petit al costat de fora del taló.
		if (outer) {
			col = mix(col, accent, band(t, 0.13, 0.2) * band(h, 0.35, 0.5) * smoothstep(0.7, 0.8, side));
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
