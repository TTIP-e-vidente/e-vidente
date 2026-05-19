shader_type canvas_item;

uniform float circle_size : hint_range(0.0, 1.0) = 0.3;
uniform float edge_blur : hint_range(0.0, 1.0) = 0.25;
uniform float blur_radius : hint_range(0.0, 0.02) = 0.008;

void fragment() {

	vec2 center = vec2(0.5, 0.5);

	float dist = distance(center, UV);

	// máscara circular suave
	float mask = smoothstep(
		circle_size - edge_blur,
		circle_size,
		dist
	);

	// BLUR REAL
	vec4 blur = vec4(0.0);

	blur += texture(TEXTURE, UV + vec2(-blur_radius, 0.0));
	blur += texture(TEXTURE, UV + vec2( blur_radius, 0.0));
	blur += texture(TEXTURE, UV + vec2(0.0, -blur_radius));
	blur += texture(TEXTURE, UV + vec2(0.0,  blur_radius));

	blur += texture(TEXTURE, UV + vec2(-blur_radius, -blur_radius));
	blur += texture(TEXTURE, UV + vec2( blur_radius, -blur_radius));
	blur += texture(TEXTURE, UV + vec2(-blur_radius,  blur_radius));
	blur += texture(TEXTURE, UV + vec2( blur_radius,  blur_radius));

	blur /= 8.0;

	vec4 original = texture(TEXTURE, UV);

	// mezcla entre original y blur
	vec4 final_color = mix(original, blur, 1.0 - mask);

	final_color.a *= mask;

	COLOR = final_color;
}