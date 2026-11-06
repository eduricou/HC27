// Cabells, barba i celles: la textura de Quaternius (CC0) dona el relleu dels flocs i el
// color el posa cada jugador (instance uniform), d'una de les tonalitats de Constants.HAIRS.
shader_type spatial;

uniform sampler2D tex : source_color, filter_linear_mipmap;
instance uniform vec3 hair_color : source_color = vec3(0.17, 0.11, 0.08);

void fragment() {
	vec3 t = texture(tex, UV).rgb;
	float l = dot(t, vec3(0.3, 0.59, 0.11));
	ALBEDO = hair_color * (0.4 + 1.2 * l);
	ROUGHNESS = 0.65;
	SPECULAR = 0.35;
}
