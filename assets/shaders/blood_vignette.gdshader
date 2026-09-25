shader_type canvas_item;
// Low health as an INK BLEED (Brief 3): ink creeping in from the screen
// edges like a spill soaking into paper — feathered, fibrous, with a darker
// tide line at its front — deepening with `amount` (0..1 of health missing).
// At 1 HP it throbs with the heartbeat (`pulse`). Red blood style tints it
// red; Noir (and Gore off) is pure ink. Draws nothing at amount 0.

uniform float amount = 0.0;
uniform float pulse = 0.0;
uniform vec4 core : source_color = vec4(0.30, 0.02, 0.04, 1.0);
uniform vec4 rim : source_color = vec4(0.12, 0.0, 0.02, 1.0);

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 c = UV - 0.5;
	float edge = max(abs(c.x) * 1.0, abs(c.y) * 1.15) * 2.0;     // 0 centre, 1 edge
	// Domain-warped noise: the front feathers into fibres like wet paper.
	vec2 warp = vec2(fbm(UV * 6.0), fbm(UV * 6.0 + 7.3));
	float n = fbm(UV * vec2(11.0, 8.0) + warp * 2.2);
	float fibres = vnoise(UV * vec2(90.0, 3.0)) * 0.5 + vnoise(UV * vec2(3.0, 90.0)) * 0.5;
	float reach = amount * (0.26 + 0.06 * pulse);
	float front = edge + (n - 0.5) * 0.34 + (fibres - 0.5) * 0.05;
	float t = smoothstep(1.0 - reach - 0.05, 1.0 - reach + 0.07, front);
	// The tide line: ink pools darker right at the front.
	float tide = smoothstep(0.06, 0.0, abs(front - (1.0 - reach) - 0.02)) * 0.35;
	vec4 col = mix(core, rim, clamp((front - (1.0 - reach)) * 5.0, 0.0, 1.0));
	col.rgb *= 1.0 - tide;
	COLOR = vec4(col.rgb, clamp(t + tide * t, 0.0, 1.0) * clamp(amount * 1.15, 0.0, 0.7));
}
