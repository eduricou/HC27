// Façanes amb finestres (casa del club, hospital i blocs de pisos). El blau de la
// textura marca el vidre: de dia reflecteix el cel i de nit se n'encén una part.
// ref: FS_TEX, uMode 3 (línies 1357–1363)
shader_type spatial;

global uniform float night;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Finestres per repetició de textura (per triar quines s'encenen).
uniform vec2 cells = vec2(8.0, 10.0);
uniform float lit_ratio = 0.62;

float hs(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 t = texture(tex, UV);
	// El blau #2f55e0 en lineal: r ≈ 0,03 i b ≈ 0,75.
	float win = step(0.45, t.b) * step(t.r, 0.12);
	float lit = step(1.0 - lit_ratio, hs(floor(UV * cells)));
	vec3 glass = mix(vec3(0.04, 0.065, 0.1), vec3(0.01, 0.012, 0.02), night);
	ALBEDO = mix(t.rgb, glass, win);
	ROUGHNESS = mix(0.9, 0.12, win);
	SPECULAR = mix(0.3, 0.7, win);
	EMISSION = vec3(1.0, 0.63, 0.24) * 1.4 * win * lit * night;
}
