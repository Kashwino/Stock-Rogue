shader_type canvas_item;
// Screen post-process: vignette + film grain always (when enabled), chromatic
// aberration on damage, red pulse and desaturation at 1 HP.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.42;
uniform float grain = 0.05;
uniform float aberration = 0.0;     // 0..1, spikes on damage
uniform float danger = 0.0;         // 0..1, 1 HP state
uniform float pulse = 0.0;          // 0..1, heartbeat

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float off = aberration * 0.006;
	vec3 col;
	col.r = texture(screen_tex, uv + c * off * 2.0).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * off * 2.0).b;
	// Desaturate towards the edge of death.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), danger * 0.55);
	float d = length(c * vec2(1.25, 1.0));
	float v = smoothstep(0.35, 0.95, d);
	col *= 1.0 - v * vignette;
	// Red heartbeat creeping in from the edges.
	col = mix(col, vec3(0.55, 0.02, 0.02), v * danger * (0.35 + 0.45 * pulse));
	float g = hash(uv * vec2(1280.0, 720.0) + fract(TIME) * 91.0) - 0.5;
	col += g * grain;
	COLOR = vec4(col, 1.0);
}
