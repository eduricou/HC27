// Xarxa: quadrícula de fils sense textura (UV en metres), per a les porteries i les
// tanques. Les porteries es deformen quan hi entra la pilota. ref: drawGoal3D(), bulge()
// Malla: UV = posició sobre la xarxa en metres; UV2 = (y, z) de la simulació;
// COLOR.r = quant es pot deformar el vèrtex (0 als laterals, 1 al fons).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 net_color : source_color = vec4(0.92, 0.94, 0.92, 1.0);
// Mida de la malla i gruix del fil, en metres.
uniform float cell = 0.1;
uniform float thread = 0.007;
// Opacitat del vel entre fils.
uniform float haze = 0.05;
// Sacseig després d'un gol: porteria activa (0/1), costat (−1/1), y del xut i temps.
uniform float rip_on = 0.0;
uniform float rip_side = 1.0;
uniform float rip_y = 0.0;
uniform float rip_t = 0.0;

void vertex() {
	if (rip_on > 0.5) {
		float y = UV2.x;
		float z = UV2.y;
		float t = rip_t;
		float b = 0.45 * exp(-t * 1.6) * abs(sin(t * 8.0 + 0.4))
			* exp(-((y - rip_y) * (y - rip_y) + (z - 0.7) * (z - 0.7)) / 1.1);
		VERTEX.x += rip_side * b * COLOR.r;
	}
}

float thread_cov(float d, float hw, float fw) {
	float w = max(hw, fw * 0.7);
	return (1.0 - smoothstep(w - fw * 0.6, w + fw * 0.6, d)) * (hw / w);
}

void fragment() {
	vec2 q = UV / cell;
	vec2 d = abs(fract(q + 0.5) - 0.5) * cell;
	vec2 fw = fwidth(UV) + 1e-5;
	float a = max(thread_cov(d.x, thread * 0.5, fw.x), thread_cov(d.y, thread * 0.5, fw.y));
	// De lluny la malla es fa més petita que un píxel: es passa a un vel uniforme.
	float far = smoothstep(cell * 0.25, cell * 0.7, max(fw.x, fw.y));
	a = mix(a, min(1.0, 2.0 * thread / cell), far);
	ALBEDO = net_color.rgb;
	ALPHA = clamp(a + haze, 0.0, 1.0) * net_color.a;
	ROUGHNESS = 0.8;
}
