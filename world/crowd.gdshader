shader_type spatial;
render_mode cull_disabled;
// Thousands of spectators from one quad strip. Each cell is a seat: shirt, skin tone, head,
// a few flags, shade under the roof, and stairways. `excite` makes them jump.
// Colours match the stadium photo at the bowler's end (mostly blue and yellow).
uniform float excite = 0.0;
uniform float columns = 3800.0;
uniform float rows = 72.0;
uniform float roof_shade = 0.38;   // rows nearer the top than this sit in the roof's shadow

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 g = UV * vec2(columns, rows);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float h = hash(cell);
	float h2 = hash(cell + 17.0);
	float h3 = hash(cell + 53.0);

	vec3 shirt = vec3(0.10, 0.26, 0.72);
	shirt = mix(shirt, vec3(0.96, 0.78, 0.12), step(0.45, h));
	shirt = mix(shirt, vec3(0.92, 0.92, 0.94), step(0.74, h));
	shirt = mix(shirt, vec3(0.82, 0.16, 0.16), step(0.88, h));
	shirt = mix(shirt, vec3(0.12, 0.55, 0.28), step(0.96, h));
	vec3 skin = mix(vec3(0.42, 0.27, 0.18), vec3(0.72, 0.52, 0.38), h3);
	float occupied = step(h2, 0.9);

	float bob = 0.5 + 0.5 * sin(TIME * (2.0 + 7.0 * excite) + h * 60.0);
	float lift = 0.18 * bob * excite;
	vec3 seat = vec3(0.14, 0.17, 0.24);
	float body = smoothstep(0.10, 0.18, f.x) * smoothstep(0.90, 0.82, f.x)
			* smoothstep(0.36 - lift, 0.46 - lift, f.y);
	vec3 col = mix(seat, shirt * (0.8 + 0.2 * bob), body * occupied);
	float head = 1.0 - smoothstep(0.13, 0.19, distance(f, vec2(0.5, 0.26 - lift)));
	col = mix(col, skin, head * occupied);

	// A few flags waved above the crowd.
	float flag_cell = step(0.985, hash(floor(g / vec2(3.0, 1.0)) + 7.0));
	float wave = sin(TIME * 5.0 + h * 20.0) * 0.08;
	float flag = flag_cell * step(0.05, f.y + wave) * step(f.y + wave, 0.32) * step(0.2, f.x) * step(f.x, 0.95);
	col = mix(col, mix(vec3(1.0, 0.55, 0.12), vec3(0.15, 0.55, 0.22), step(0.5, h3)), flag);

	// Stairways and the walkway between tiers.
	float stairs = step(fract(UV.x * 48.0), 0.018);
	col = mix(col, vec3(0.50, 0.50, 0.54), stairs);
	col = mix(col, vec3(0.26, 0.27, 0.32), step(abs(UV.y - 0.52), 0.018));

	// Upper rows sit in the roof's shadow; lower rows catch the sun.
	float shade = smoothstep(roof_shade, roof_shade - 0.18, UV.y);
	col *= mix(1.08, 0.55, shade);

	// Softer colours: at a distance a crowd reads as speckle, not stripes.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 0.7);
	ALBEDO = col * col * 1.3;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
