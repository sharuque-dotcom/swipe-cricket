shader_type spatial;
// Mown outfield: alternating stripes and rings, darker beyond the rope.
uniform vec3 centre = vec3(0.0, 0.0, -10.06);
uniform float boundary = 65.0;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(wp.xz - centre.xz);
	float stripe = step(0.5, fract(wp.x / 11.0));
	float ring = step(0.5, fract(r / 9.0));
	vec3 col = mix(vec3(0.060, 0.250, 0.050), vec3(0.085, 0.330, 0.062), abs(stripe - ring));
	// Worn square around the pitch.
	float sq = (1.0 - smoothstep(9.0, 12.0, abs(wp.x))) * (1.0 - smoothstep(13.0, 15.0, abs(wp.z - centre.z)));
	col = mix(col, vec3(0.130, 0.300, 0.075), sq * 0.6);
	float outside = smoothstep(boundary - 0.2, boundary + 0.6, r);
	col = mix(col, vec3(0.030, 0.130, 0.032), outside);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
