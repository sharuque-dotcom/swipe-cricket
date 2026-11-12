shader_type spatial;
render_mode cull_disabled;
// Advertising boards around the rope: blocks of flat colour.
float hash(float p) {
	return fract(sin(p * 91.345) * 47453.5453);
}

void fragment() {
	float n = floor(UV.x * 44.0);
	float h = hash(n);
	vec3 c = mix(vec3(0.05, 0.20, 0.55), vec3(0.85, 0.12, 0.18), step(0.5, h));
	c = mix(c, vec3(0.98, 0.78, 0.10), step(0.8, h));
	c = mix(c, vec3(0.95), step(0.93, h));
	float edge = step(fract(UV.x * 44.0), 0.02);
	float band = step(0.25, UV.y) * step(UV.y, 0.75);
	c = mix(c * 0.55, c, band);
	vec3 o = mix(c, vec3(0.1), edge);
	ALBEDO = o * o;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
