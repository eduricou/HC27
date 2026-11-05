// Tanques LED: anuncis que llueixen i passen a l'anunci següent cada 5 s, amb la
// quadrícula de LED. ref: FS_TEX, uMode 2, i uScroll de glRender() (línies 1353 i 1566)
// UV: x en unitats de textura (1 = 64 m, 8 anuncis), y de 0 (dalt) a 1 (baix).
shader_type spatial;

global uniform float led_scroll;
global uniform float night;
uniform sampler2D ads : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Píxels de la textura per LED.
uniform float led_px = 3.0;
uniform vec2 tex_size = vec2(4096.0, 64.0);

void fragment() {
	vec2 uv = vec2(UV.x + led_scroll, UV.y);
	vec3 c = texture(ads, uv).rgb;
	// Quadrícula: es veu de prop i s'esvaeix de lluny (si no, fa moaré).
	vec2 px = UV * tex_size / led_px;
	vec2 g = fract(px);
	vec2 fw = fwidth(px);
	float grid_dark = max(step(0.7, g.x), step(0.7, g.y)) * 0.35;
	float fade = 1.0 - smoothstep(0.25, 0.6, max(fw.x, fw.y));
	float dim = mix(0.12, grid_dark, fade);
	c *= 1.0 - dim;
	ALBEDO = c * 0.08;
	ROUGHNESS = 0.35;
	SPECULAR = 0.4;
	EMISSION = c * mix(0.95, 1.25, night);
}
