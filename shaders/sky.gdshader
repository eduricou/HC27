// Cel de tarda i de nit, amb les muntanyes del fons (amb llumetes de nit) i estrelles.
// Port de FS_SKY (reference/web/index.html, línies 1256–1276), sense el parpelleig de
// les estrelles: amb TIME, Godot hauria de refer el mapa de reflexos a cada fotograma.
shader_type sky;

global uniform float night;
// Direcció cap al sol, en coordenades de Godot (la posa src/game/stadium/stadium.gd).
uniform vec3 sun_dir = vec3(-0.82, 0.51, -0.26);

float hs(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	float e = d.y;
	float az = atan(d.x, -d.z);
	float t = pow(clamp(e, 0.0, 1.0), 0.45);
	vec3 day = mix(vec3(0.93, 0.84, 0.69), vec3(0.31, 0.53, 0.80), t);
	float sg = max(dot(d, normalize(sun_dir)), 0.0);
	day += vec3(1.0, 0.85, 0.6) * pow(sg, 60.0) * 0.7 + vec3(1.0, 0.78, 0.5) * pow(sg, 6.0) * 0.18;
	vec3 nig = mix(vec3(0.10, 0.12, 0.19), vec3(0.012, 0.02, 0.05), t)
		+ vec3(0.26, 0.15, 0.08) * exp(-max(e, 0.0) * 16.0) * 0.55;
	vec3 col = mix(day, nig, night);
	if (night > 0.5 && e > 0.04 && !AT_CUBEMAP_PASS) {
		float h = hs(floor(vec2(az * 260.0, e * 260.0)));
		if (h > 0.9965) {
			col += vec3(0.75) * (h - 0.9965) * 280.0 * 0.8;
		}
	}
	// Serralada del Maresme a l'horitzó.
	float r = 0.034 + 0.017 * sin(az * 2.1 + 0.7) + 0.010 * sin(az * 5.3 + 2.1) + 0.005 * sin(az * 11.7);
	if (e < r) {
		vec3 hill = mix(vec3(0.47, 0.56, 0.58), vec3(0.34, 0.43, 0.45), clamp((r - e) * 30.0, 0.0, 1.0));
		col = mix(hill, vec3(0.02, 0.03, 0.05), night);
		if (night > 0.5 && !AT_CUBEMAP_PASS) {
			if (hs(floor(vec2(az * 420.0, e * 900.0))) > 0.982 && e < r - 0.004) {
				col += vec3(1.0, 0.75, 0.42) * 0.75;
			}
		}
	}
	if (e < 0.0) {
		vec3 ground = mix(vec3(0.24, 0.31, 0.21), vec3(0.02, 0.03, 0.03), night);
		col = mix(col, ground, clamp(-e * 25.0, 0.0, 1.0));
	}
	COLOR = pow(col, vec3(2.2));
}
