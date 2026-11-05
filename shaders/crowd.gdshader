// Públic de la grada: un quad per persona (MultiMesh) amb una cel·la de l'atles
// assets/textures/stadium/crowd.png. Es belluguen una mica sempre i salten quan hi ha
// xuts i gols (crowd_jump, de 0 a 1). ref: FS_TEX, uMode 1 (línies 1349–1352)
// INSTANCE_CUSTOM: x = cel·la de l'atles, y = fase (0–1).
shader_type spatial;
render_mode cull_disabled;

global uniform float crowd_jump;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 grid = vec2(8.0, 8.0);

void vertex() {
	float ph = INSTANCE_CUSTOM.y;
	// Només una part del públic salta (com a la web, step(0.3, fase)).
	float amp = 0.015 + crowd_jump * 0.22 * step(0.3, ph);
	VERTEX.y += max(sin(TIME * (3.0 + ph * 4.0) + ph * 6.28), -0.2) * amp;
	float c = INSTANCE_CUSTOM.x;
	UV = (vec2(mod(c, grid.x), floor(c / grid.x)) + UV) / grid;
}

void fragment() {
	vec4 t = texture(atlas, UV);
	ALBEDO = t.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.9;
	// Il·luminació suau: el quad és pla, i així no queda negre quan el sol és darrere.
	BACKLIGHT = vec3(0.35);
}
