// Cotxes aparcats (CarMesh, MultiMesh): la carrosseria (`painted`) agafa el color de cada
// cotxe (INSTANCE_CUSTOM.rgb); la resta (vidres, rodes, llums), el color del vèrtex.
shader_type spatial;

uniform bool painted = true;
uniform float roughness = 0.3;
uniform float metallic = 0.0;

varying vec3 col;

void vertex() {
	col = painted ? INSTANCE_CUSTOM.rgb : COLOR.rgb;
}

void fragment() {
	ALBEDO = pow(col, vec3(2.2));
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
