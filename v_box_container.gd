extends BoxContainer

# Cores — ajusta ao teu tema (o roxo que já usas nas bordas, por exemplo)
const COLOR_NORMAL := Color(0.85, 0.85, 0.9)
const COLOR_HOVER := Color(0.6, 0.45, 1.0)
const MARKER_OFFSET := 24.0

# Tamanho dos botões — ajusta estes valores ao gosto
const BUTTON_MIN_HEIGHT := 64.0
const BUTTON_FONT_SIZE := 34   # tamanho do texto do próprio botão (0 = não mexe)

# Espaçamento entre botões — fixo, para não depender do tema por defeito
const BUTTON_SEPARATION := 40

# Contorno do texto — melhora a leitura contra fundos claros
const OUTLINE_COLOR := Color(0.05, 0.05, 0.08, 0.9)
const OUTLINE_SIZE := 6

# Sons — arrasta os ficheiros no Inspector deste nó
@export var hover_sound: AudioStream
@export var click_sound: AudioStream

@onready var sfx_player: AudioStreamPlayer = get_tree().current_scene.find_child("SfxPlayer", true, false)

@export var pixel_font: Font

func _ready() -> void:
	add_theme_constant_override("separation", BUTTON_SEPARATION)
	for btn in get_children():
		if btn is Button:
			_setup_button(btn)


func _play_sound(stream: AudioStream) -> void:
	if stream and sfx_player:
		sfx_player.stream = stream
		sfx_player.play()


func _setup_button(btn: Button) -> void:
	# remove fundo/borda em todos os estados -> fica transparente
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)

	btn.add_theme_color_override("font_color", COLOR_NORMAL)
	btn.add_theme_color_override("font_hover_color", COLOR_HOVER)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	# contorno para destacar o texto do fundo (floresta clara/escura)
	btn.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	btn.add_theme_constant_override("outline_size", OUTLINE_SIZE)

	# aumenta o botão: altura mínima maior + texto maior
	btn.custom_minimum_size.y = BUTTON_MIN_HEIGHT
	if BUTTON_FONT_SIZE > 0:
		btn.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)

	# tamanho de letra igual ao do botão (ou define um fixo, ex: 32)
	var font := btn.get_theme_font("font")
	var font_size := btn.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 32

	var marker_left := Label.new()
	var marker_right := Label.new()
	marker_left.text = "‹"
	marker_right.text = "›"

	for marker in [marker_left, marker_right]:
		marker.add_theme_color_override("font_color", COLOR_HOVER)
		marker.add_theme_font_size_override("font_size", font_size)
		if pixel_font:
			marker.add_theme_font_override("font", pixel_font)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		marker.modulate.a = 0.0
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(marker)

	# espera um frame para o botão ter o tamanho final calculado pelo VBoxContainer
	await get_tree().process_frame

	var text_width: float = font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var marker_size := marker_left.get_minimum_size()
	var center_x: float = btn.size.x / 2.0
	var center_y: float = btn.size.y / 2.0
	var padding := 14.0  # espaço entre o texto e o marcador

	var left_rest_x: float = center_x - text_width / 2.0 - marker_size.x - padding
	var right_rest_x: float = center_x + text_width / 2.0 + padding

	marker_left.position = Vector2(left_rest_x, center_y - marker_size.y / 2.0)
	marker_right.position = Vector2(right_rest_x, center_y - marker_size.y / 2.0)

	var tween: Tween
	var slide := 8.0  # quanto deslizam para fora no hover

	var animate := func(target_alpha: float, active: bool) -> void:
		@warning_ignore("unassigned_variable")
		if tween:
			@warning_ignore("unassigned_variable")
			tween.kill()
		@warning_ignore("confusable_capture_reassignment")
		tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var offset := slide if active else 0.0
		tween.tween_property(marker_left, "modulate:a", target_alpha, 0.15)
		tween.tween_property(marker_right, "modulate:a", target_alpha, 0.15)
		tween.tween_property(marker_left, "position:x", left_rest_x - offset, 0.15)
		tween.tween_property(marker_right, "position:x", right_rest_x + offset, 0.15)

	btn.mouse_entered.connect(func():
		animate.call(1.0, true)
		_play_sound(hover_sound)
	)
	btn.mouse_exited.connect(func(): animate.call(0.0, false))
	btn.button_down.connect(func():
		animate.call(1.0, false)
		_play_sound(click_sound)
	)
	btn.button_up.connect(func(): animate.call(1.0, true))
