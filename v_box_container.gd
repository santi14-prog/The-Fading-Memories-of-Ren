extends BoxContainer

# Cores — ajusta ao teu tema (o roxo que já usas nas bordas, por exemplo)
const COLOR_NORMAL := Color(0.85, 0.85, 0.9)
const COLOR_HOVER := Color(0.6, 0.45, 1.0)
const MARKER_OFFSET := 10.0

# Tamanho dos botões — ajusta estes valores ao gosto
const BUTTON_MIN_HEIGHT := 64.0
const BUTTON_FONT_SIZE := 34   # tamanho do texto do próprio botão (0 = não mexe)

# Espaçamento entre botões — exportável para poderes definir um valor
# diferente por nó no Inspector (ex: maior no HBoxContainer Sim/Não)
@export var button_separation: int = 40

# Contorno do texto — melhora a leitura contra fundos claros
const OUTLINE_COLOR := Color(0.05, 0.05, 0.08, 0.9)
const OUTLINE_SIZE := 6

# Sons — arrasta os ficheiros no Inspector deste nó
@export var hover_sound: AudioStream
@export var click_sound: AudioStream

@onready var sfx_player: AudioStreamPlayer = get_tree().current_scene.find_child("SfxPlayer", true, false)

@export var pixel_font: Font

func _ready() -> void:
	add_theme_constant_override("separation", button_separation)
	alignment = BoxContainer.ALIGNMENT_CENTER
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

	# encolhe o botão ao tamanho do texto (em vez de esticar até à borda
	# do container) e centra-o — é isto que aproxima as setas do texto,
	# já que elas se ancoram às bordas do próprio botão
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# aumenta o botão: altura mínima maior + texto maior
	btn.custom_minimum_size.y = BUTTON_MIN_HEIGHT
	if BUTTON_FONT_SIZE > 0:
		btn.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)

	var font_size := btn.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = 32

	_add_animated_button_markers(btn, font_size)


func _add_animated_button_markers(btn: Button, font_size: int) -> void:
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
		marker.anchor_top = 0.0
		marker.anchor_bottom = 1.0
		marker.offset_top = 0.0
		marker.offset_bottom = 0.0
		btn.add_child(marker)

	var marker_width: float = marker_left.get_minimum_size().x

	# marker_left encosta à borda esquerda do botão, marker_right à direita —
	# ambos ancorados ao próprio botão, sem depender do layout já estar calculado
	marker_left.anchor_left = 0.0
	marker_left.anchor_right = 0.0
	marker_left.offset_right = -MARKER_OFFSET
	marker_left.offset_left = -MARKER_OFFSET - marker_width

	marker_right.anchor_left = 1.0
	marker_right.anchor_right = 1.0
	marker_right.offset_left = MARKER_OFFSET
	marker_right.offset_right = MARKER_OFFSET + marker_width

	var rest_left_a := marker_left.offset_left
	var rest_left_b := marker_left.offset_right
	var rest_right_a := marker_right.offset_left
	var rest_right_b := marker_right.offset_right

	var tween: Tween
	var slide := 8.0  # quanto deslizam para fora no hover

	var animate := func(target_alpha: float, active: bool) -> void:
		if tween:
			tween.kill()
		tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var offset := slide if active else 0.0
		tween.tween_property(marker_left, "modulate:a", target_alpha, 0.15)
		tween.tween_property(marker_right, "modulate:a", target_alpha, 0.15)
		tween.tween_property(marker_left, "offset_left", rest_left_a - offset, 0.15)
		tween.tween_property(marker_left, "offset_right", rest_left_b - offset, 0.15)
		tween.tween_property(marker_right, "offset_left", rest_right_a + offset, 0.15)
		tween.tween_property(marker_right, "offset_right", rest_right_b + offset, 0.15)

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
