// Terra del camp: gespa artificial amb franges, soroll i desgast, les línies del camp,
// el formigó del voltant, el carrer Galícia amb la rotonda i l'herba seca de fora.
// Port de FS_GROUND (reference/web/index.html, línies 1278–1342) adaptat al camp real de
// l'Iluro (docs/decisions/0006). Colors de la foto del camp (7/11/2026): la gespa és d'un
// verd apagat, i a fora, al costat de la vorada, hi ha una franja groga d'un metre.
// De prop es veu el gra de la fibra, i les franges dels rotlles canvien amb la direcció de
// la mirada (la fibra fa un pèl de caiguda), com a la gespa artificial.
// La llum la posa Godot (sol de tarda o focus de nit); aquí hi ha el color i les línies.
// Coordenades: el món de Godot (x, z) és el pla (x, y) de la simulació. Les zones les
// posa src/game/stadium/stadium.gd a partir de StadiumLayout.
shader_type spatial;

uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;
// Formigó al voltant de la gespa: fins a x = ±apron_x, del passeig (walk_y) a l'est.
uniform float apron_x = 53.7;
uniform float walk_y = -37.5;
uniform float east_y = 33.3;
// Carrer Galícia: vorera, calçada (street_y0..street_y1) i vorera fins a les cases.
uniform float sidewalk_y = -40.0;
uniform float street_y0 = -42.5;
uniform float street_y1 = -51.5;
uniform float houses_y = -54.5;
// Rotonda: centre (x, y) i radi.
uniform vec3 roundabout = vec3(61.7, -47.0, 9.0);
// Zona pavimentada de les casetes del club: x0, y0, x1, y1.
uniform vec4 huts_area = vec4(53.7, -37.5, 71.7, -0.5);

const float HL = 45.7;
const float HW = 27.5;
const float GHW = 1.83;
const float CR = 14.63;
const float DR = 19.63;
const float L23 = 22.8;
const float PS = 6.475;
// Mitja amplada de les línies (7,5 cm).
const float LINE_HW = 0.0375;

varying vec2 wp;
varying vec3 w3;

void vertex() {
	w3 = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wp = w3.xz;
}

// Cobertura d'una línia de mitja amplada hw a distància d (metres). Quan la línia és més
// prima que un píxel, s'eixampla i s'aclareix: no parpelleja. ref: aa()
float aa(float d, float hw, float fw) {
	float w = max(hw, fw * 0.7);
	return (1.0 - smoothstep(w - fw * 0.6, w + fw * 0.6, d)) * (hw / w);
}

// ref: lines()
float field_lines(vec2 p, float fw) {
	float hw = LINE_HW;
	float m = 0.0;
	float ax = abs(p.x);
	float ay = abs(p.y);
	if (ay <= HW + 0.04) m = max(m, aa(abs(ax - HL), hw, fw));
	if (ax <= HL + 0.04) m = max(m, aa(abs(ay - HW), hw, fw));
	if (ay <= HW) {
		m = max(m, aa(ax, hw, fw));
		m = max(m, aa(abs(ax - L23), hw, fw));
	}
	float qx = HL - ax;
	if (qx >= -0.04) {
		float dc;
		float dd;
		float par;
		if (ay <= GHW) {
			dc = abs(qx - CR);
			dd = abs(qx - DR);
			par = ay;
		} else {
			vec2 v = vec2(max(qx, 0.0), ay - GHW);
			float l = length(v);
			dc = abs(l - CR);
			dd = abs(l - DR);
			par = GHW + atan(v.y, max(v.x, 1e-4)) * DR;
		}
		m = max(m, aa(dc, hw, fw));
		// Cercle discontinu de 5 m: trams de 3 m cada 3,3 m.
		m = max(m, aa(dd, hw, fw) * (1.0 - step(0.3, mod(par + 0.15, 3.3))));
		// Marques de la línia de fons a 5 i 10 m del pal.
		if (qx <= 0.3) {
			m = max(m, aa(abs(ay - GHW - 5.0), hw, fw));
			m = max(m, aa(abs(ay - GHW - 10.0), hw, fw));
		}
		// Punt de penal.
		m = max(m, aa(length(vec2(qx - PS, p.y)), 0.075, fw));
	}
	// Punt central.
	m = max(m, aa(length(p), 0.1, fw));
	return m;
}

float wear(vec2 p, vec2 c, float r) {
	vec2 d = p - c;
	return exp(-dot(d, d) / (r * r));
}

// Junta entre lloses de mida s (0 a la junta, 1 al mig).
float joints(vec2 p, float s, float fw) {
	vec2 q = abs(fract(p / s) - 0.5) * s;
	float j = min(s * 0.5 - q.x, s * 0.5 - q.y);
	return smoothstep(0.0, 0.02 + fw, j);
}

void fragment() {
	vec2 p = wp;
	float ax = abs(p.x);
	// Tot el que fa servir derivades va abans de les branques.
	float fw = (length(dFdx(p)) + length(dFdy(p))) * 0.7 + 1e-5;
	float n1 = texture(noise_tex, p * 0.5).r;
	float n2 = texture(noise_tex, p * 0.045).g;
	float n3 = texture(noise_tex, p * 0.012).b;
	// Gra fi (fibra, herba): només de prop, on no fa moiré.
	float near = 1.0 - smoothstep(0.012, 0.06, fw);
	float grain = (texture(noise_tex, p * 2.7).r - 0.5) * 0.7 + (texture(noise_tex, p * 7.9).r - 0.5);
	grain *= near;
	float ln = field_lines(p, fw);
	float slab = joints(p, 2.0, fw);
	float tile = joints(p, 0.5, fw);
	// Línia discontínua del mig del carrer (no a la rotonda).
	float mid = (street_y0 + street_y1) * 0.5;
	float dash = aa(abs(p.y - mid), 0.06, fw) * step(0.5, fract(p.x / 6.0));

	// Colors en sRGB, com a la web; es passen a lineal al final.
	vec3 col;
	float turf = 0.0;
	bool in_pitch = ax <= HL && abs(p.y) <= HW;
	bool run_off = ax <= HL + 4.5 && p.y >= -HW - 4.0 && p.y <= HW + 4.5;
	bool apron = ax <= apron_x && p.y >= walk_y && p.y <= east_y;
	bool huts = p.x >= huts_area.x && p.x <= huts_area.z && p.y >= huts_area.y && p.y <= huts_area.w;
	float rd = length(p - roundabout.xy);
	bool island = rd < roundabout.z * 0.45;
	bool street = (p.y <= street_y0 && p.y >= street_y1) || rd < roundabout.z;
	bool sidewalk = (p.y < sidewalk_y && p.y > street_y0) || (p.y < street_y1 && p.y > houses_y)
		|| (rd < roundabout.z + 2.5 && !street);
	bool verge = p.y < walk_y && p.y >= sidewalk_y;
	if (run_off) {
		// Rotlles de 4,57 m: la fibra cau cap a +x o −x, i es veuen més clars o més foscos
		// segons d'on es miren.
		float roll = mod(floor((p.x + HL) / 4.57), 2.0) * 2.0 - 1.0;
		vec3 v = normalize(CAMERA_POSITION_WORLD - w3);
		float sheen = roll * v.x / max(length(v.xz), 0.2);
		col = vec3(0.335, 0.43, 0.29) * (1.0 + 0.035 * sheen);
		// Franja groga al costat de la vorada.
		float edge = min(min(HL + 4.5 - ax, p.y + HW + 4.0), HW + 4.5 - p.y);
		float yellow = 1.0 - smoothstep(1.2 - fw, 1.2 + fw, edge);
		col = mix(col, vec3(0.86, 0.79, 0.16), yellow);
		col *= 0.93 + 0.08 * n1 + 0.08 * (n2 - 0.5) + 0.06 * (n3 - 0.5) + 0.09 * grain;
		// Desgast: centre, punts de penal, porteries i córners curts.
		float w = 0.10 * wear(p, vec2(0.0), 6.0)
			+ 0.17 * wear(vec2(ax, p.y), vec2(HL - 3.5, 0.0), 5.0)
			+ 0.09 * wear(vec2(ax, p.y), vec2(HL - 11.0, 0.0), 8.0)
			+ 0.13 * wear(vec2(ax, abs(p.y)), vec2(HL, 11.83), 2.5);
		col = mix(col, vec3(0.47, 0.5, 0.36), w * (0.7 + 0.6 * n2) * (1.0 - yellow));
		if (ax <= HL + 0.1 && abs(p.y) <= HW + 0.1) {
			// La pintura de les línies, una mica gastada.
			col = mix(col, vec3(0.93, 0.94, 0.91) * (0.95 + 0.05 * grain), ln);
		}
		turf = 1.0;
	} else if (apron || huts) {
		// Formigó amb juntes cada 2 m.
		col = vec3(0.56, 0.55, 0.51) * (0.82 + 0.22 * n1 + 0.1 * n2);
		col *= 0.93 + 0.07 * slab;
	} else if (island) {
		col = vec3(0.27, 0.38, 0.18) * (0.75 + 0.3 * n2 + 0.2 * n1);
	} else if (street) {
		col = vec3(0.23, 0.23, 0.24) * (0.85 + 0.2 * n1 + 0.1 * n2);
		if (rd > roundabout.z) {
			col = mix(col, vec3(0.86), dash);
		}
	} else if (sidewalk) {
		col = vec3(0.64, 0.62, 0.58) * (0.86 + 0.16 * n1) * (0.9 + 0.1 * tile);
	} else if (verge) {
		// Franja de terra amb herba on hi ha els arbres.
		col = mix(vec3(0.36, 0.31, 0.22), vec3(0.29, 0.35, 0.19), smoothstep(0.3, 0.7, n2));
		col *= 0.85 + 0.2 * n1 + 0.15 * grain;
	} else {
		// Herba del Maresme: verd sec, amb clapes grans i suaus més grogues o més verdes
		// (soroll de cel·les grans, sense el quadriculat del fi), i el gra de l'herba de prop.
		float big = texture(noise_tex, p * 0.004 + 0.3).b;
		float mid = texture(noise_tex, p * 0.019 + 0.7).b;
		float patch = big * 0.6 + mid * 0.4;
		col = mix(vec3(0.43, 0.42, 0.28), vec3(0.33, 0.39, 0.22), smoothstep(0.2, 0.8, patch));
		col *= 0.94 + 0.08 * (n1 - 0.5) + 0.05 * (n2 - 0.5) + 0.16 * grain;
	}
	ALBEDO = pow(col, vec3(2.2));
	// La gespa artificial fa una mica de brillantor (a contrallum); la resta, gens.
	ROUGHNESS = mix(0.95, 0.82 - 0.05 * n1, turf);
	SPECULAR = mix(0.15, 0.22, turf);
}
