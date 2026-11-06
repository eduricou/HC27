// Ombra de contacte de la pilota: una taca fosca i difuminada a terra, just a sota, que
// s'esvaeix quan la pilota s'aixeca (BallView). La de veritat la fan els llums.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 0.4;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = strength * (1.0 - smoothstep(0.2, 1.0, d));
}
