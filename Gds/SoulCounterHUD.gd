extends Label

# Anexa a um nó Label ao lado do ícone circular da Alma no teu HUD.
# Estilo pensado para combinar com a barra de vida roxa/dourada:
# texto branco, contorno escuro grosso, leve brilho roxo ao apanhar.

# Cores — ajusta se o roxo do teu HUD for ligeiramente diferente
const COLOR_TEXT := Color(1, 1, 1)                # branco, igual ao "100%" da barra de vida
const COLOR_OUTLINE := Color(0.12, 0.05, 0.2)     # roxo quase-preto, para o contorno
const COLOR_GLOW := Color(0.75, 0.55, 1.0)        # lilás claro, para o pulse ao apanhar

func _ready() -> void:
	# tipografia consistente com o resto do HUD
	add_theme_color_override("font_color", COLOR_TEXT)
	add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	add_theme_constant_override("outline_size", 6)
	add_theme_font_size_override("font_size", 22)

	SoulManager.souls_changed.connect(_on_souls_changed)
	_update_text(SoulManager.total_souls)


func _on_souls_changed(total: int, delta: int) -> void:
	_update_text(total)
	if delta > 0:
		_pulse()


func _update_text(total: int) -> void:
	text = str(total)   # só o número — o ícone ao lado já mostra que é "Almas"


func _pulse() -> void:
	if tween:
		tween.kill()
	var original_color := get_theme_color("font_color")

	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08)
	t.parallel().tween_method(_set_font_color, original_color, COLOR_GLOW, 0.08)
	t.tween_property(self, "scale", Vector2.ONE, 0.18)
	t.parallel().tween_method(_set_font_color, COLOR_GLOW, original_color, 0.18)
	tween = t


func _set_font_color(c: Color) -> void:
	add_theme_color_override("font_color", c)


var tween: Tween
