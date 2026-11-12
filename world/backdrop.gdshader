shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
// The far stand from a photo: roof, floodlights and a packed crowd, on a flat card behind the
// boards at the bowler's end. Sides fade into the built-in stands; the top fades into the sky.
uniform sampler2D photo : source_color, filter_linear_mipmap, repeat_disable;
uniform float side_fade = 0.12;
uniform float top_fade = 0.22;
uniform vec3 tint = vec3(1.0, 1.0, 1.0);

void fragment() {
	vec4 c = texture(photo, UV);
	float sides = smoothstep(0.0, side_fade, UV.x) * smoothstep(1.0, 1.0 - side_fade, UV.x);
	// The photo's sky is pale; fade it out so the game's sky shows above the roof.
	float sky = smoothstep(0.0, top_fade, UV.y);
	// Add back some contrast and colour the hazy photo lost.
	vec3 rgb = c.rgb * tint;
	float l = dot(rgb, vec3(0.299, 0.587, 0.114));
	rgb = mix(vec3(l), rgb, 1.25);
	rgb = clamp((rgb - 0.5) * 1.18 + 0.47, 0.0, 1.0);
	ALBEDO = rgb;
	ALPHA = sides * sky;
}
