// Terra de l'estadi: gespa artificial amb franges, soroll i desgast, les línies del camp,
// el voral de formigó i l'herba de fora. Port de FS_GROUND (reference/web/index.html,
// línies 1278–1342). La llum la posa Godot (sol de tarda o projectors de nit), i aquí
// només hi ha el color, la brillantor i les línies.
// Coordenades: el món de Godot (x, z) és el pla (x, y) de la simulació.
shader_type spatial;

uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;

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

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
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

void fragment() {
	vec2 p = wp;
	float ax = abs(p.x);
	// Tot el que fa servir derivades va abans de les branques.
	float fw = (length(dFdx(p)) + length(dFdy(p))) * 0.7 + 1e-5;
	float n1 = texture(noise_tex, p * 0.5).r;
	float n2 = texture(noise_tex, p * 0.045).g;
	float n3 = texture(noise_tex, p * 0.012).b;
	float ln = field_lines(p, fw);

	// Colors en sRGB, com a la web; es passen a lineal al final.
	vec3 col;
	float turf = 0.0;
	bool in_pitch = ax <= HL && abs(p.y) <= HW;
	bool run_off = ax <= HL + 4.5 && p.y >= -HW - 4.0 && p.y <= HW + 4.5;
	bool apron = ax <= HL + 8.0 && p.y >= -HW - 9.0 && p.y <= HW + 8.5;
	if (run_off) {
		float stripe = mod(floor((p.x + HL) / 4.57), 2.0);
		col = in_pitch
			? mix(vec3(0.165, 0.50, 0.245), vec3(0.150, 0.468, 0.228), stripe)
			: vec3(0.135, 0.42, 0.215);
		col *= 0.88 + 0.18 * n1 + 0.12 * (n2 - 0.5) + 0.08 * (n3 - 0.5);
		// Desgast: centre, punts de penal, porteries i córners curts.
		float w = 0.10 * wear(p, vec2(0.0), 6.0)
			+ 0.17 * wear(vec2(ax, p.y), vec2(HL - 3.5, 0.0), 5.0)
			+ 0.09 * wear(vec2(ax, p.y), vec2(HL - 11.0, 0.0), 8.0)
			+ 0.13 * wear(vec2(ax, abs(p.y)), vec2(HL, 11.83), 2.5);
		col = mix(col, vec3(0.40, 0.47, 0.27), w * (0.7 + 0.6 * n2));
		if (ax <= HL + 0.1 && abs(p.y) <= HW + 0.1) {
			col = mix(col, vec3(0.95, 0.96, 0.94), ln);
		}
		turf = 1.0;
	} else if (apron) {
		// Voral de formigó amb juntes cada 2 m.
		col = vec3(0.50, 0.52, 0.50) * (0.82 + 0.22 * n1 + 0.1 * n2);
		float j = min(abs(fract(p.x * 0.5) - 0.5), abs(fract(p.y * 0.5) - 0.5));
		col *= 0.93 + 0.07 * smoothstep(0.0, 0.02 + fw, j);
	} else {
		col = vec3(0.20, 0.33, 0.17) * (0.7 + 0.35 * n2 + 0.25 * n1);
	}
	ALBEDO = pow(col, vec3(2.2));
	// La gespa artificial fa una mica de brillantor (a contrallum); el formigó i l'herba, gens.
	ROUGHNESS = mix(0.95, 0.88 - 0.06 * n1, turf);
	SPECULAR = mix(0.15, 0.18, turf);
}
