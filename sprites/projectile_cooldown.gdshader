shader_type canvas_item;

// 1.0 = projétil acabou de ser usado
// 0.0 = projétil pronto a usar
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);

	float angle = atan(uv.x, -uv.y);
	if (angle < 0.0) {
		angle += 2.0 * PI;
	}

	float normalized_angle = angle / (2.0 * PI);

	vec4 tex_color = texture(TEXTURE, UV);

	if (normalized_angle > progress) {
		tex_color.a = 0.0;
	}

	// Mesma transparência do dash
	tex_color.a *= 0.5;

	COLOR = tex_color;
}