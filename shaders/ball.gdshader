// Pilota d'hoquei: plàstic blanc amb la costura de les dues meitats i la marca del
// fabricant a banda i banda, perquè es vegi com gira. Una mica d'emissió la fa destacar
// sobre la gespa. Les marques van en coordenades de la pilota (giren amb ella).
shader_type spatial;

uniform vec3 base : source_color = vec3(0.96, 0.95, 0.91);
uniform vec3 seam : source_color = vec3(0.62, 0.63, 0.62);
uniform vec3 mark : source_color = vec3(0.93, 0.42, 0.08);
uniform float glow = 0.18;

varying vec3 n_ball;

void vertex() {
	n_ball = NORMAL;
}

void fragment() {
	vec3 n = normalize(n_ball);
	vec3 col = base;
	float s = 1.0 - smoothstep(0.03, 0.06, abs(n.y));
	col = mix(col, seam, s);
	// La marca: una franja curta a cada costat de la costura.
	float m = smoothstep(0.86, 0.9, abs(n.x)) * (1.0 - smoothstep(0.22, 0.27, abs(n.y)));
	col = mix(col, mark, m);
	ALBEDO = col;
	ROUGHNESS = 0.4;
	EMISSION = col * glow;
}
