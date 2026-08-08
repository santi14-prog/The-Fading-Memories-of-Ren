extends Control
## Menu de Opções
## Anexa este script ao nó raiz OptionsMenu (Control).
## Estrutura esperada:
## OptionsMenu (Control)
## ├── ColorRect
## ├── CenterContainer (Full Rect)
## │   └── PanelContainer
## │       └── MarginContainer
## │           └── VBoxContainer
## │               ├── Label (título)
## │               └── TabContainer
## │                   ├── Geral
## │                   ├── Audio
## │                   ├── Graficos
## │                   ├── Controlos
## │                   └── Extras
## └── BtnBack (Button)
##
## A barra de tabs nativa é escondida; em vez dela é criado um menu
## vertical de botões (um por tab), estilizado como o BtnBack, que
## troca a tab ativa ao clicar.
##
## Qualquer Button colocado dentro do CONTEÚDO de uma tab também é
## automaticamente reorganizado numa coluna centrada com o mesmo
## hover/click animado (marcadores < >).
##
## A tab "Audio" recebe automaticamente 3 sliders de volume
## (Geral/Música/Efeitos), ligados ao SettingsManager (autoload).
##
## Enquanto a tab "Audio" estiver ativa, o menu vertical de seleção
## de tabs é escondido (para dar destaque aos sliders); volta a
## aparecer assim que se muda para outra tab.

signal closed

# Paleta — alinhada com o pause menu (moldura dourada) e o roxo de hover do menu principal
const COLOR_BG_OVERLAY := Color(0.03, 0.03, 0.05, 0.65)
const COLOR_PANEL_BG := Color(0.07, 0.06, 0.1, 0.92)
const COLOR_BORDER := Color(0.75, 0.58, 0.18)  # dourado, tom da moldura do pause
const COLOR_TITLE := Color(0.92, 0.8, 0.5)
const COLOR_TEXT := Color(0.85, 0.85, 0.9)
const COLOR_HOVER := Color(0.6, 0.45, 1.0)  # mesmo roxo do v_box_container.gd
const COLOR_OUTLINE := Color(0.05, 0.05, 0.08, 0.9)

const PANEL_MIN_SIZE := Vector2(560, 460)
const CORNER_RADIUS := 6
const TITLE_FONT_SIZE := 30

# Botões (estilo + animação de hover/click)
const BUTTON_FONT_SIZE := 26
const TAB_FONT_SIZE := 32
const BUTTON_SEPARATION := 28
const MARKER_PADDING := 14.0
const MARKER_SLIDE := 8.0

# Nome da tab que, quando ativa, esconde o menu vertical de seleção
const AUDIO_TAB_NAME := "Audio"

# Nomes de exibição corretos das tabs (o nome do nó pode não ter acentos)
const TAB_TITLE_OVERRIDES := {
	"Geral": "Geral",
	"Audio": "Áudio",
	"Graficos": "Gráficos",
	"Controlos": "Controlos",
	"Extras": "Extras",
}

# Opcional: arrasta uma fonte pixel (a mesma usada no pause menu) para manter consistência
@export var pixel_font: Font
@export var hover_sound: AudioStream
@export var click_sound: AudioStream

@onready var color_rect: ColorRect = $ColorRect
@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Label
@onready var tab_container: TabContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TabContainer
@onready var btn_back: Button = $BtnBack
@onready var sfx_player: AudioStreamPlayer = get_tree().current_scene.find_child("SfxPlayer", true, false)

# Referência ao container do menu vertical de seleção de tabs, criado em
# _build_tab_selector(). Guardada aqui para poder ser escondida/mostrada.
var _tab_selector_container: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	move_child(color_rect, 0)

	_style_background()
	_style_panel()
	_style_title()
	_build_tab_selector()
	_organize_tab_buttons()
	_build_audio_tab()
	_position_back_button()
	_setup_button(btn_back)

	btn_back.pressed.connect(_on_btn_back_pressed)

	tab_container.tab_changed.connect(_on_tab_changed)

	# Força sempre a primeira tab como ponto de partida, em vez de confiar no
	# valor de current_tab gravado na cena (que reflete a última tab aberta
	# no editor, e pode fazer o seletor começar escondido sem motivo).
	tab_container.current_tab = 0
	_on_tab_changed(tab_container.current_tab)


## Nota: este menu já não reage ao Esc de propósito — só o botão "Voltar"
## fecha. O PauseMenu (por baixo) é que sabe que este menu está aberto e
## ignora o Esc enquanto isso, por isso aqui não é preciso fazer nada com ele.


func _on_btn_back_pressed() -> void:
	closed.emit()
	queue_free()


func _on_tab_changed(tab_idx: int) -> void:
	if not _tab_selector_container:
		return
	var tab_node := tab_container.get_child(tab_idx)
	_tab_selector_container.visible = tab_node.name != AUDIO_TAB_NAME


func _style_background() -> void:
	color_rect.anchor_left = 0.0
	color_rect.anchor_top = 0.0
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	color_rect.offset_left = 0.0
	color_rect.offset_top = 0.0
	color_rect.offset_right = 0.0
	color_rect.offset_bottom = 0.0
	color_rect.color = COLOR_BG_OVERLAY
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP


func _style_panel() -> void:
	panel.custom_minimum_size = PANEL_MIN_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(COLOR_PANEL_BG.r, COLOR_PANEL_BG.g, COLOR_PANEL_BG.b, 0.0)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(0)
	style.set_corner_radius_all(CORNER_RADIUS)
	style.set_expand_margin_all(0)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)


func _style_title() -> void:
	title_label.add_theme_color_override("font_color", COLOR_TITLE)
	title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if pixel_font:
		title_label.add_theme_font_override("font", pixel_font)


func _build_tab_selector() -> void:
	# esconde a barra de tabs nativa e cria um menu vertical próprio no lugar dela
	tab_container.tabs_visible = false

	var parent_container := tab_container.get_parent()
	var tab_index := tab_container.get_index()

	var center := CenterContainer.new()
	parent_container.add_child(center)
	parent_container.move_child(center, tab_index)

	var selector := VBoxContainer.new()
	selector.add_theme_constant_override("separation", BUTTON_SEPARATION)
	selector.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(selector)

	for i in tab_container.get_child_count():
		var btn := Button.new()
		var raw_title := tab_container.get_tab_title(i)
		btn.text = TAB_TITLE_OVERRIDES.get(raw_title, raw_title)
		selector.add_child(btn)
		_setup_button(btn, TAB_FONT_SIZE)
		var tab_index_captured := i
		btn.pressed.connect(func(): tab_container.current_tab = tab_index_captured)

	# guarda a referência para podermos esconder/mostrar este menu depois
	_tab_selector_container = center


func _organize_tab_buttons() -> void:
	# para cada tab, recolhe todos os Buttons (a qualquer profundidade),
	# remove-os dos pais originais e recoloca-os numa coluna centrada.
	for tab in tab_container.get_children():
		var buttons := _collect_buttons(tab)
		if buttons.is_empty():
			continue

		for btn in buttons:
			btn.get_parent().remove_child(btn)

		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		tab.add_child(center)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", BUTTON_SEPARATION)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		center.add_child(vbox)

		for btn in buttons:
			vbox.add_child(btn)
			_setup_button(btn)


func _collect_buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child in node.get_children():
		if child is Button:
			found.append(child)
		else:
			found.append_array(_collect_buttons(child))
	return found


func _build_audio_tab() -> void:
	var audio_tab := tab_container.get_node_or_null("Audio")
	if not audio_tab:
		return

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	audio_tab.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 32)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	_add_volume_slider(vbox, "Geral", SettingsManager.BUS_MASTER)
	_add_volume_slider(vbox, "Música", SettingsManager.BUS_MUSIC)
	_add_volume_slider(vbox, "Efeitos", SettingsManager.BUS_SFX)


func _add_volume_slider(parent: VBoxContainer, label_text: String, bus_name: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 22)
	if pixel_font:
		label.add_theme_font_override("font", pixel_font)
	row.add_child(label)

	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(280, 24)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01

	var current_db: float = clamp(SettingsManager.get_bus_volume(bus_name), -40.0, 0.0)
	slider.value = db_to_linear(current_db)

	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.15, 0.13, 0.18, 0.9)
	groove.border_color = COLOR_BORDER
	groove.set_border_width_all(1)
	groove.set_corner_radius_all(4)
	groove.content_margin_top = 6
	groove.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", groove)

	var fill := StyleBoxFlat.new()
	fill.bg_color = COLOR_HOVER
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)

	row.add_child(slider)

	slider.value_changed.connect(func(value: float):
		var db := linear_to_db(max(value, 0.0001))
		SettingsManager.set_bus_volume(bus_name, db)
	)
	slider.drag_ended.connect(func(_value_changed: bool):
		SettingsManager.save_settings()
	)


func _position_back_button() -> void:
	if btn_back.text.strip_edges().is_empty():
		btn_back.text = "Voltar"

	btn_back.custom_minimum_size = Vector2(160, 48)
	btn_back.anchor_left = 0.5
	btn_back.anchor_right = 0.5
	btn_back.anchor_top = 1.0
	btn_back.anchor_bottom = 1.0
	btn_back.offset_left = -80
	btn_back.offset_right = 80
	btn_back.offset_top = -80
	btn_back.offset_bottom = -32


func _play_sound(stream: AudioStream) -> void:
	if stream and sfx_player:
		sfx_player.stream = stream
		sfx_player.play()


func _setup_button(btn: Button, font_size_override: int = BUTTON_FONT_SIZE) -> void:
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("focus", empty)

	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_HOVER)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	btn.add_theme_constant_override("outline_size", 4)

	if font_size_override > 0:
		btn.add_theme_font_size_override("font_size", font_size_override)
	if pixel_font:
		btn.add_theme_font_override("font", pixel_font)

	var font_size := btn.get_theme_font_size("font_size")
	if font_size <= 0:
		font_size = font_size_override

	var marker_left := Label.new()
	var marker_right := Label.new()
	marker_left.text = "<"
	marker_right.text = ">"

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
	# ambos ancorados ao próprio botão, sem depender da largura do texto.
	marker_left.anchor_left = 0.0
	marker_left.anchor_right = 0.0
	marker_left.offset_right = -MARKER_PADDING
	marker_left.offset_left = -MARKER_PADDING - marker_width

	marker_right.anchor_left = 1.0
	marker_right.anchor_right = 1.0
	marker_right.offset_left = MARKER_PADDING
	marker_right.offset_right = MARKER_PADDING + marker_width

	var rest_left_a := marker_left.offset_left
	var rest_left_b := marker_left.offset_right
	var rest_right_a := marker_right.offset_left
	var rest_right_b := marker_right.offset_right

	var tween: Tween

	var animate := func(target_alpha: float, active: bool) -> void:
		@warning_ignore("unassigned_variable")
		if tween:
			@warning_ignore("unassigned_variable")
			tween.kill()
		@warning_ignore("confusable_capture_reassignment")
		tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var offset := MARKER_SLIDE if active else 0.0
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
