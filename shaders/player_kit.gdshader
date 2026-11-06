// Equipació pintada sobre el cos base (Quaternius, CC0). De cada vèrtex, la textura vdata
// (un píxel per vèrtex, llegit amb VERTEX_ID) en dona la posició en repòs (xyz, metres,
// espai del model, postura de T) i la part del cos (a: 0 cap, 1 tronc, 2 braç, 3 cama).
// On acaba cada peça de roba es decideix aquí amb la posició en repòs, que s'interpola
// suaument; és la mateixa regla que KitMesh.classify(). La malla (amb els LOD) no canvia.
// Els colors són del material (un per equip i porter); la pell i el dorsal, de cada
// jugador (instance uniform). ref: drawPlayer() (equipacions de la web)
shader_type spatial;

uniform sampler2D vdata : filter_nearest;
uniform sampler2D skin_light : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D skin_dark : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
// Dígits 0–9 en una fila (assets/textures/players/digits.png): blanc sobre transparent.
uniform sampler2D digits : filter_linear_mipmap;

// 0 = Iluro (meitat de dalt shirt2), 1 = Polo (franja shirt2 amb band al mig),
// 2 = porter (espatlles shirt2, mànigues llargues i guants).
uniform int style = 0;
uniform vec3 shirt : source_color = vec3(0.94, 0.49, 0.10);
uniform vec3 shirt2 : source_color = vec3(1.0);
uniform vec3 band : source_color = vec3(0.78, 0.06, 0.18);
uniform vec3 collar : source_color = vec3(0.07);
uniform vec3 shorts : source_color = vec3(0.09);
uniform vec3 socks : source_color = vec3(0.95);
uniform vec3 shoes : source_color = vec3(0.08);
uniform vec3 gloves : source_color = vec3(0.95);
uniform vec3 num_color : source_color = vec3(0.07);
// Línies de la roba en repòs (les posa PlayerRig a partir de KitMesh.landmarks()).
uniform float waist_y = 1.0;
uniform float collar_y = 1.46;
uniform float collar_r = 0.085;
uniform float neck_z = -0.04;
uniform float chest_y = 1.25;
uniform float band_y = 1.33;
uniform float sleeve_x = 0.35;
uniform float wrist_x = 0.68;
uniform float shorts_y = 0.78;
uniform float socks_y = 0.48;
uniform float ankle_y = 0.1;

// 0 = pell clara, 1 = pell fosca (barreja de les dues textures del model).
instance uniform float skin_tone = 0.2;
instance uniform int number = 10;

varying vec3 rest;
// Sense interpolar: la part del cos de tot el triangle.
varying flat int part;

void vertex() {
	vec4 d = texelFetch(vdata, ivec2(VERTEX_ID % 1024, VERTEX_ID / 1024), 0);
	rest = d.xyz;
	part = int(d.a + 0.5);
}

// Dígit d a la posició (u, v) de 0 a 1 dins la seva casella.
float digit(int d, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(digits, vec2((float(d) + uv.x) / 10.0, uv.y)).a;
}

// Dorsal a l'esquena (el model mira cap a +Z): caselles de 15 cm x 20 cm.
float back_number(vec3 p, float top) {
	if (p.z > neck_z - 0.04) {
		return 0.0;
	}
	float v = (top - p.y) / 0.2;
	float u = -p.x / 0.15;
	if (number >= 10) {
		return max(digit(number / 10, vec2(u + 1.0, v)), digit(number % 10, vec2(u, v)));
	}
	return digit(number, vec2(u + 0.5, v));
}

void fragment() {
	vec3 skin = mix(texture(skin_light, UV).rgb, texture(skin_dark, UV).rgb, skin_tone);
	vec3 col = skin;
	float cloth = 1.0;
	vec3 p = rest;
	if (part == 1) {
		if (p.y < waist_y) {
			col = shorts;
		} else {
			if (style == 0) {
				col = p.y > chest_y ? shirt2 : shirt;
			} else if (style == 1) {
				col = shirt;
				if (abs(p.y - band_y) < 0.05) col = shirt2;
				if (abs(p.y - band_y) < 0.02) col = band;
			} else {
				col = p.y > chest_y + 0.08 ? shirt2 : shirt;
			}
			// Coll: un anell estret al voltant del coll i una V al davant (el porter, coll
			// rodó: sota la samarreta porta el peto).
			float r = length(vec2(p.x, p.z - neck_z));
			bool front = p.z > neck_z + 0.03;
			float vline = collar_y - 0.08 + abs(p.x) * 1.2;
			bool in_v = style != 2 && front && abs(p.x) < 0.065 && p.y > vline;
			if (in_v && p.y > vline + 0.025) {
				col = skin;
				cloth = 0.0;
			} else if ((r < collar_r && p.y > collar_y - 0.02) || in_v) {
				col = collar;
			}
			float top = style == 0 ? chest_y - 0.04 : band_y - 0.08;
			col = mix(col, num_color, back_number(p, top));
		}
	} else if (part == 2) {
		float ax = abs(p.x);
		if (ax < sleeve_x) {
			col = style == 0 ? shirt2 : shirt;
		} else if (ax > wrist_x) {
			col = style == 2 ? gloves : skin;
			cloth = style == 2 ? 1.0 : 0.0;
		} else {
			// Avantbraç: pell, o màniga llarga del porter.
			col = style == 2 ? shirt : skin;
			cloth = style == 2 ? 1.0 : 0.0;
		}
	} else if (part == 3) {
		if (p.y > shorts_y) {
			col = shorts;
		} else if (p.y > socks_y) {
			cloth = 0.0;
		} else if (p.y > ankle_y) {
			col = socks;
		} else {
			col = shoes;
		}
	} else {
		cloth = 0.0;
	}
	ALBEDO = col;
	// La roba és llisa: el relleu dels músculs només es deixa veure una mica.
	NORMAL_MAP = mix(texture(normal_tex, UV).xyz, vec3(0.5, 0.5, 1.0), cloth * 0.7);
	ROUGHNESS = mix(0.55, 0.75, cloth);
	SPECULAR = mix(0.4, 0.3, cloth);
}
