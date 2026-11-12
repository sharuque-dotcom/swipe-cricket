shader_type spatial;
// Mown outfield like on TV: wide stripes across the ground with a faint checker, real grass
// detail from a photo tile, a dotted 30-yard circle, a worn square around the pitch and darker
// grass past the rope. Stripe colours were sampled from the grass photo.
uniform vec3 centre = vec3(0.0, 0.0, -10.06);
uniform float boundary = 65.0;
uniform float inner_circle = 27.4;
uniform float stripe_width = 6.5;
uniform float detail_size = 4.0;   // metres covered by one tile of the grass photo
uniform sampler2D detail : hint_default_white, filter_linear_mipmap, repeat_enable;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Mirrored tiling hides the tile seams.
vec2 mirror(vec2 uv) {
	vec2 f = fract(uv * 0.5) * 2.0;
	return 1.0 - abs(1.0 - f);
}

void fragment() {
	vec2 p = wp.xz;
	float r = length(p - centre.xz);
	// Bands across the pitch (stacked towards the bowler on screen) and a softer cross set.
	float band = step(0.5, fract((p.y - centre.z) / stripe_width));
	float cross_band = step(0.5, fract(p.x / stripe_width));
	vec3 light = vec3(0.110, 0.235, 0.028);
	vec3 deep = vec3(0.046, 0.118, 0.012);
	vec3 col = mix(deep, light, band);
	col *= 0.93 + 0.07 * cross_band;

	// Photo grass blades, faded out with distance so far grass doesn't shimmer.
	float dist = length(wp - CAMERA_POSITION_WORLD);
	vec3 blades = texture(detail, mirror(p / detail_size)).rgb * 2.0;
	col *= mix(blades, vec3(1.0), smoothstep(14.0, 55.0, dist));
	// Large soft patches so the field isn't perfectly uniform.
	col *= 0.9 + 0.18 * noise(p * 0.35);

	// Worn square around the pitch: lighter, drier grass.
	float sq = (1.0 - smoothstep(7.0, 11.0, abs(p.x))) * (1.0 - smoothstep(13.0, 16.0, abs(p.y - centre.z)));
	col = mix(col, col * vec3(1.35, 1.15, 1.25) + vec3(0.02, 0.012, 0.0), sq * 0.5);

	// Dotted 30-yard circle.
	float ring = 1.0 - smoothstep(0.06, 0.12, abs(r - inner_circle));
	float ang = atan(p.y - centre.z, p.x - centre.x);
	float dots = step(0.5, fract(ang * inner_circle / 1.6));
	col = mix(col, vec3(0.8), ring * dots * 0.85);

	// Past the rope: shaded grass up to the boards.
	float outside = smoothstep(boundary - 0.2, boundary + 0.8, r);
	col = mix(col, deep * 0.6, outside);

	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
