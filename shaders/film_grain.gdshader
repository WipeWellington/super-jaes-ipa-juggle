// 1930s film look: flickering grain, vignette and the odd vertical scratch.
shader_type canvas_item;

uniform float grain_strength = 0.10;
uniform float vignette_strength = 0.45;
uniform float fps = 16.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * fps);
	float n = rand(floor(UV * vec2(420.0, 260.0)) + frame * 1.37) - 0.5;
	float grain_a = abs(n) * grain_strength;
	vec3 grain_c = n > 0.0 ? vec3(1.0, 0.96, 0.86) : vec3(0.18, 0.11, 0.05);

	float d = distance(UV, vec2(0.5));
	float flicker = 0.9 + 0.1 * rand(vec2(frame, 7.0));
	float vig_a = smoothstep(0.35, 0.8, d) * vignette_strength * flicker;

	float sx = rand(vec2(frame, 3.0));
	float scratch_on = step(0.92, rand(vec2(frame, 5.0)));
	float scratch_a = scratch_on * (1.0 - smoothstep(0.0, 0.0015, abs(UV.x - sx))) * 0.35;

	vec3 dark = vec3(0.16, 0.10, 0.04);
	float a = 1.0 - (1.0 - grain_a) * (1.0 - vig_a) * (1.0 - scratch_a);
	vec3 c = (grain_c * grain_a + dark * (vig_a + scratch_a)) / max(grain_a + vig_a + scratch_a, 0.0001);
	COLOR = vec4(c, a);
}
