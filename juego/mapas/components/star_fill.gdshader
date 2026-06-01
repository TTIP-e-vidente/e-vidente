shader_type canvas_item;

uniform float fill_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (UV.x > fill_amount) {
		tex.a = 0.0;
	}
	COLOR = tex;
}
