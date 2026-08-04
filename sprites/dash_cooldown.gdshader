shader_type canvas_item;

// 1.0 = dash acabado de usar (roda branca completa)
// 0.0 = dash pronto a usar (roda invisível)
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float angle = atan(uv.x, -uv.y); // 0 = topo (12h), cresce em sentido horário
	if (angle < 0.0) {
		angle += 2.0 * PI;
	}
	float normalized_angle = angle / (2.0 * PI);

	vec4 tex_color = texture(TEXTURE, UV);

	if (normalized_angle > progress) {
		tex_color.a = 0.0;
	}

	tex_color.a *= 0.35;
	COLOR = tex_color;
}
