shader_type canvas_item;
// Blood creeping in from the screen edges as the player loses health:
// ragged, noise-edged, deepening with `amount` (0..1 of health missing).
// At 1 HP it throbs with the heartbeat (`pulse`). Draws nothing at amount 0.

uniform float amount = 0.0;
uniform float pulse = 0.0;
uniform vec4 core : source_color = vec4(0.42, 0.02, 0.04, 1.0);
uniform vec4 rim : source_color = vec4(0.25, 0.0, 0.02, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 c = UV - 0.5;
	float edge = max(abs(c.x) * 1.0, abs(c.y) * 1.15) * 2.0;     // 0 centre, 1 edge
	float n = vnoise(UV * vec2(9.0, 6.0)) * 0.6 + vnoise(UV * vec2(23.0, 17.0)) * 0.4;
	float reach = amount * (0.24 + 0.06 * pulse);
	float t = smoothstep(1.0 - reach - 0.08, 1.0 - reach + 0.1, edge + (n - 0.5) * 0.22);
	vec4 col = mix(core, rim, smoothstep(0.0, 1.0, (edge - (1.0 - reach)) * 4.0));
	COLOR = vec4(col.rgb, t * clamp(amount * 1.1, 0.0, 0.62));
}
