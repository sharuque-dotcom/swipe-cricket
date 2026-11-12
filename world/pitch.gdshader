shader_type spatial;
// The pitch strip, painted from a top-down photo. The photo is placed so its stump lines sit
// exactly on the 3D stumps (z = 0 and z = bowler_z); the grass fringe is part of the image.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float half_width = 1.63;    // half the photo's width in metres, fringe included
uniform float z_start = -21.34;     // world z at the top of the photo (bowler end)
uniform float z_end = 1.22;         // world z at the bottom of the photo (batter end)
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = vec2((wp.x + half_width) / (2.0 * half_width), (wp.z - z_start) / (z_end - z_start));
	vec3 col = texture(albedo_tex, uv).rgb;
	// The photo is pale and already lit; scale it down to a real clay albedo.
	ALBEDO = col * 0.56;
	ROUGHNESS = 0.95;
	SPECULAR = 0.08;
}
