// Públic dret (SpectatorMesh, MultiMesh). La peça va al color del vèrtex (r) i els colors,
// a INSTANCE_CUSTOM: x = samarreta/jaqueta, y = pantalons, z = pell i cabell, w = fase
// (0–1). Cada color és un índex d'una paleta. Es belluguen una mica sempre i salten quan
// hi ha xuts i gols (crowd_jump, de 0 a 1). ref: FS_TEX, uMode 1 (línies 1349–1352)
shader_type spatial;

global uniform float crowd_jump;

const vec3 TOPS[16] = {
	vec3(0.94, 0.49, 0.10), vec3(0.96, 0.96, 0.95), vec3(0.94, 0.49, 0.10), vec3(0.07, 0.07, 0.08),
	vec3(0.23, 0.35, 0.55), vec3(0.54, 0.16, 0.16), vec3(0.18, 0.42, 0.23), vec3(0.85, 0.76, 0.48),
	vec3(0.27, 0.27, 0.27), vec3(0.72, 0.72, 0.72), vec3(0.48, 0.31, 0.6), vec3(0.16, 0.5, 0.53),
	vec3(0.96, 0.96, 0.95), vec3(0.08, 0.14, 0.29), vec3(0.08, 0.14, 0.29), vec3(0.78, 0.06, 0.18)
};
const vec3 JACKETS[5] = {
	vec3(0.17, 0.18, 0.21), vec3(0.35, 0.24, 0.17), vec3(0.24, 0.29, 0.37), vec3(0.43, 0.12, 0.13),
	vec3(0.29, 0.31, 0.25)
};
const vec3 TROUSERS[5] = {
	vec3(0.23, 0.31, 0.43), vec3(0.16, 0.16, 0.18), vec3(0.72, 0.66, 0.53), vec3(0.43, 0.44, 0.45),
	vec3(0.2, 0.27, 0.37)
};
const vec3 SKINS[5] = {
	vec3(0.96, 0.8, 0.68), vec3(0.89, 0.7, 0.55), vec3(0.78, 0.57, 0.42), vec3(0.6, 0.41, 0.28),
	vec3(0.4, 0.26, 0.18)
};
const vec3 HAIRS[6] = {
	vec3(0.12, 0.09, 0.07), vec3(0.3, 0.2, 0.12), vec3(0.55, 0.4, 0.24), vec3(0.62, 0.6, 0.57),
	vec3(0.85, 0.84, 0.82), vec3(0.2, 0.15, 0.1)
};

varying flat int kind;
varying float rel_y;
varying flat vec4 pick;

void vertex() {
	float ph = INSTANCE_CUSTOM.w;
	// Només una part del públic salta (com a la web, step(0.3, fase)).
	float amp = 0.008 + crowd_jump * 0.2 * step(0.3, ph);
	VERTEX.y += max(sin(TIME * (3.0 + ph * 4.0) + ph * 6.28), -0.2) * amp;
	// Una mica de balanceig del tronc.
	VERTEX.x += sin(TIME * (0.7 + ph) + ph * 9.0) * 0.012 * COLOR.g;
	kind = int(COLOR.r * 8.0);
	rel_y = COLOR.g;
	pick = INSTANCE_CUSTOM;
}

void fragment() {
	int top = int(pick.x * 255.0 + 0.5);
	int low = int(pick.y * 255.0 + 0.5);
	int look = int(pick.z * 255.0 + 0.5);
	vec3 shirt = TOPS[top % 16];
	// Amb jaqueta (si el bit 4 hi és), la jaqueta pels braços i el tronc; la samarreta
	// es veu al mig del pit.
	bool has_jacket = (top / 16) % 2 == 1;
	vec3 jacket = has_jacket ? JACKETS[(top / 32) % 5] : shirt;
	vec3 col;
	if (kind == 0) {
		col = SKINS[look % 5];
	} else if (kind == 1) {
		col = HAIRS[(look / 5) % 6];
	} else if (kind == 3) {
		col = jacket;
	} else if (kind == 4) {
		col = TROUSERS[low % 5];
	} else if (kind == 5) {
		col = vec3(0.12, 0.115, 0.11);
	} else if (kind == 6) {
		col = vec3(0.94, 0.49, 0.10);
	} else {
		col = shirt;
	}
	ALBEDO = pow(col, vec3(2.2)) * (0.85 + 0.15 * rel_y);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
