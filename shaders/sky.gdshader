// Cel de tarda i de nit, amb estrelles i les muntanyes llunyanes de l'horitzó.
// Port de FS_SKY (reference/web/index.html, línies 1256–1276), sense el parpelleig de
// les estrelles: amb TIME, Godot hauria de refer el mapa de reflexos a cada fotograma.
// Al voltant del camp no hi ha edificis (ho diu l'usuari, que el coneix): només muntanyes
// de lluny, sense pobles ni llums, en dues carenes (la de davant més fosca i verda, la del
// fons més alta i blavosa per la distància).
shader_type sky;

global uniform float night;
// Direcció cap al sol, en coordenades de Godot (la posa src/game/stadium/stadium.gd).
uniform vec3 sun_dir = vec3(-0.82, 0.51, -0.26);
// Color de la boira de l'entorn (stadium.gd, DAY i NIGHT): la base de les muntanyes s'hi fon.
const vec3 FOG_DAY = vec3(0.74, 0.78, 0.8);
const vec3 FOG_NIGHT = vec3(0.07, 0.09, 0.14);

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
	// Muntanyes: més altes cap a −y de la simulació (az = 0, darrere les banquetes, el fons
	// de la vista TV) i més baixes cap a la banda de la càmera TV.
	vec3 fog = mix(FOG_DAY, FOG_NIGHT, night);
	float side = 0.6 + 0.4 * cos(az);
	float far_r = side * (0.075 + 0.025 * sin(az * 1.7 + 0.3) + 0.015 * sin(az * 4.1 + 1.3)
		+ 0.007 * sin(az * 9.7 + 2.2) + 0.003 * sin(az * 21.0 + 0.5));
	float near_r = side * (0.035 + 0.018 * sin(az * 2.6 + 2.4) + 0.010 * sin(az * 6.3 + 0.2)
		+ 0.005 * sin(az * 14.9 + 1.7) + 0.002 * sin(az * 31.0));
	if (e < far_r) {
		vec3 far_col = mix(vec3(0.46, 0.54, 0.64), vec3(0.045, 0.055, 0.085), night);
		// Com més avall, més boira (perspectiva aèria).
		float haze = 1.0 - clamp(e / far_r, 0.0, 1.0);
		col = mix(far_col, fog, 0.12 + 0.3 * haze);
	}
	if (e < near_r) {
		vec3 near_col = mix(vec3(0.28, 0.35, 0.26), vec3(0.024, 0.03, 0.042), night);
		float haze = 1.0 - clamp(e / near_r, 0.0, 1.0);
		col = mix(near_col, fog, 0.05 + 0.32 * haze);
	}
	if (e < 0.0) {
		// Per sota de l'horitzó (més enllà del terra), la boira.
		col = mix(col, fog, clamp(-e * 25.0, 0.0, 1.0));
	}
	COLOR = pow(col, vec3(2.2));
}
