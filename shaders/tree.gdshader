// Fullatge dels arbres (TreeMesh): el color base va al vèrtex (més fosc a sota de cada
// massa) i el soroll del món fa les clapes de fulles. La llum embolcalla una mica (les
// copes no tenen la cara fosca negra) i passa una mica a contrallum. A la silueta, el
// soroll hi fa forats perquè no sembli una esfera llisa. El vent mou més la part alta.
// De nit, la llum dels focus que rebota al camp arriba als arbres de prop, sobretot a la
// cara que mira cap al camp: si no, serien siluetes negres.
shader_type spatial;
render_mode diffuse_lambert_wrap;

global uniform float night;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float sway = 0.05;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = sway * max(VERTEX.y - 1.0, 0.0);
	VERTEX.x += sin(TIME * 0.8 + w.x * 0.15 + w.z * 0.1) * k;
	VERTEX.z += sin(TIME * 0.63 + w.z * 0.13 + w.x * 0.05) * k * 0.6;
	wpos = w;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float tri(vec3 p, vec3 n, float s, int ch) {
	vec3 a = abs(n);
	a /= a.x + a.y + a.z;
	vec4 x = texture(noise_tex, p.yz * s);
	vec4 y = texture(noise_tex, p.xz * s);
	vec4 z = texture(noise_tex, p.xy * s);
	vec4 v = x * a.x + y * a.y + z * a.z;
	return ch == 0 ? v.r : v.g;
}

void fragment() {
	float clumps = tri(wpos, wnorm, 0.35, 1);
	float leaves = tri(wpos, wnorm, 1.6, 0);
	vec3 col = COLOR.rgb * (0.72 + 0.45 * clumps) * (0.85 + 0.3 * leaves);
	col = pow(col, vec3(2.2));
	ALBEDO = col;
	BACKLIGHT = col * 0.35;
	float near = 1.0 - smoothstep(35.0, 130.0, length(wpos.xz));
	float facing = 0.45 + 0.55 * clamp(dot(wnorm.xz, -normalize(wpos.xz + vec2(1e-3))), 0.0, 1.0);
	EMISSION = col * vec3(1.0, 0.96, 0.88) * night * near * facing * 0.55;
	ROUGHNESS = 0.92;
	SPECULAR = 0.12;
	// Forats a la silueta: com més de cantell, més n'hi ha.
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALPHA = step(rim * rim * 1.15, leaves * 0.6 + clumps * 0.4);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
