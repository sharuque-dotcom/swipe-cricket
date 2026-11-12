shader_type spatial;
render_mode cull_disabled;
// Thousands of spectators from one quad strip: each cell is a seat with a shirt colour.
uniform float excite = 0.0;
uniform float columns = 1500.0;
uniform float rows = 30.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 g = UV * vec2(columns, rows);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float h = hash(cell);
	float h2 = hash(cell + 17.0);
	vec3 shirt = mix(vec3(0.10, 0.25, 0.70), vec3(0.95, 0.75, 0.10), step(0.45, h));
	shirt = mix(shirt, vec3(0.90, 0.90, 0.92), step(0.72, h));
	shirt = mix(shirt, vec3(0.80, 0.15, 0.15), step(0.90, h));
	float occupied = step(h2, 0.86);
	vec3 seat = vec3(0.16, 0.20, 0.30);
	float bob = 0.5 + 0.5 * sin(TIME * (2.0 + 6.0 * excite) + h * 60.0);
	float body = smoothstep(0.12, 0.2, f.x) * smoothstep(0.88, 0.8, f.x) * smoothstep(0.05 + 0.2 * (1.0 - bob * excite), 0.3, f.y);
	vec3 col = mix(seat, shirt * (0.75 + 0.25 * bob), body * occupied);
	// Head.
	float head = 1.0 - smoothstep(0.10, 0.16, distance(f, vec2(0.5, 0.2)));
	col = mix(col, vec3(0.55, 0.38, 0.28), head * occupied);
	// Aisles and tier breaks.
	float aisle = step(fract(UV.x * 40.0), 0.035);
	col = mix(col, vec3(0.45, 0.46, 0.50), aisle);
	col = mix(col, vec3(0.30, 0.31, 0.36), step(abs(UV.y - 0.5), 0.02));
	ALBEDO = col * col * 1.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
