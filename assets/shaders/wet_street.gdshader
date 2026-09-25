shader_type canvas_item;
// Rain-slicked asphalt: noise puddles that catch a shimmering smear of the
// night's colours. Works in the Compatibility renderer (no screen reads).

uniform sampler2D puddle_noise : repeat_enable, filter_linear;
uniform vec4 asphalt : source_color = vec4(0.09, 0.095, 0.11, 1.0);
uniform vec4 sheen_a : source_color = vec4(1.0, 0.67, 0.29, 1.0);
uniform vec4 sheen_b : source_color = vec4(0.22, 0.89, 1.0, 1.0);
uniform float world_scale = 0.0016;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv = world * world_scale;
	float n = texture(puddle_noise, uv).r;
	float grit = texture(puddle_noise, uv * 9.0).r;
	float puddle = smoothstep(0.6, 0.66, n) * 0.8;
	vec3 base = asphalt.rgb * (0.85 + grit * 0.3);
	// Reflections: vertical streaks drifting slowly with the rain.
	float streak = sin(world.x * 0.045 + TIME * 0.6) * 0.5 + 0.5;
	float ripple = sin((world.y + TIME * 60.0) * 0.08 + grit * 6.0) * 0.5 + 0.5;
	vec3 sheen = mix(sheen_a.rgb, sheen_b.rgb, streak) * (0.05 + 0.05 * ripple);
	vec3 col = mix(base, base * 0.7 + sheen, puddle);
	COLOR = vec4(col, 1.0);
}
