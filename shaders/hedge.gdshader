// Bardissa (llorer o xiprer retallat): verd fosc amb taques de fulles, en coordenades del
// món perquè els trams no es repeteixin igual.
shader_type spatial;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 dark = vec3(0.10, 0.19, 0.08);
uniform vec3 light = vec3(0.24, 0.38, 0.16);

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = abs(wn.y) > 0.5 ? wp.xz : (abs(wn.x) > 0.5 ? wp.zy : wp.xy);
	float n = texture(noise_tex, uv * 0.9).r * 0.55 + texture(noise_tex, uv * 0.11).g * 0.45;
	vec3 col = mix(dark, light, smoothstep(0.25, 0.8, n));
	// Una mica més clar a dalt, on toca més el sol.
	col *= 0.85 + 0.25 * clamp(wn.y, 0.0, 1.0);
	ALBEDO = pow(col, vec3(2.2));
	ROUGHNESS = 1.0;
	SPECULAR = 0.08;
}
