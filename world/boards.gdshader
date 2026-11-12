shader_type spatial;
render_mode cull_disabled;
// LED advertising boards around the rope: glowing panels with slowly scrolling colour
// sweeps, in the purple-blue of the stadium photo. No text or logos.
uniform float speed = 0.012;

float hash(float p) {
	return fract(sin(p * 91.345) * 47453.5453);
}

void fragment() {
	float x = UV.x + TIME * speed;
	float n = floor(x * 36.0);
	float h = hash(n);
	vec3 a = mix(vec3(0.20, 0.22, 0.75), vec3(0.62, 0.20, 0.72), step(0.5, h));
	a = mix(a, vec3(0.95, 0.30, 0.45), step(0.8, h));
	a = mix(a, vec3(0.98, 0.75, 0.15), step(0.92, h));
	float local = fract(x * 36.0);
	// Each panel: a bright sweep and a soft white patch, inside a dark frame.
	float sweep = smoothstep(0.0, 0.5, local) * smoothstep(1.0, 0.5, local);
	vec3 c = mix(a * 0.45, a, 0.5 + 0.5 * sweep);
	float glow_patch = step(0.35, local) * step(local, 0.65) * step(0.3, UV.y) * step(UV.y, 0.7);
	c = mix(c, vec3(0.92, 0.94, 1.0), glow_patch * 0.55 * step(0.6, h));
	float frame = step(local, 0.01) + step(UV.y, 0.06) + step(0.94, UV.y);
	c = mix(c, vec3(0.04), clamp(frame, 0.0, 1.0));
	ALBEDO = c * c * 0.5;
	EMISSION = c * c * 0.8;
	ROUGHNESS = 0.6;
	SPECULAR = 0.2;
}
