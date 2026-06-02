shader_type canvas_item;

uniform vec2 mouse_pos = vec2(0.5);
uniform float strength = 0.25;
uniform float radius = 0.6;

void vertex() {
	vec2 center = vec2(0.5);
	vec2 dir = mouse_pos - center;

	float dist = distance(UV, mouse_pos);
	float effect = smoothstep(radius, 0.0, dist);

	VERTEX.xy += dir * effect * strength * 200.0;
}