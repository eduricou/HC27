// Pins pinyers fets de quads creuats (com a la web) amb una mica de vent. La normal es
// tomba cap amunt perquè els quads no es vegin plans a contrallum. ref: makePine()
// UV.y: 0 a dalt i 1 a baix (el peu del tronc no es mou).
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float sway = 0.12;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = (1.0 - UV.y) * (1.0 - UV.y);
	VERTEX.x += sin(TIME * 0.7 + w.x * 0.09 + w.z * 0.05) * sway * k;
	VERTEX.z += sin(TIME * 0.53 + w.z * 0.11) * sway * 0.6 * k;
}

void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = t.rgb;
	// Els quads vistos de cantell es fan transparents: si no, fan una ratlla.
	ALPHA = t.a * smoothstep(0.08, 0.3, abs(dot(NORMAL, VIEW)));
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, 0.6));
}
