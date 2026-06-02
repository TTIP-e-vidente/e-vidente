shader_type canvas_item;

uniform float fade_size = 0.15;

void fragment() {
	vec2 uv = UV;

	float top = smoothstep(0.0, fade_size, uv.y);
	float bottom = smoothstep(1.0, 1.0 - fade_size, uv.y);

	float alpha = top * bottom;

	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - alpha);
}