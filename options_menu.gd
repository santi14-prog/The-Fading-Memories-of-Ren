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
## A tab "Geral" recebe automaticamente idioma, modo de ecrã,
## resolução, V-Sync, limite de FPS e mostrar FPS, ligados ao
## SettingsManager (autoload), mais um botão de restaurar
## predefinições.
##
## A tab "Audio" recebe automaticamente 3 sliders de volume
## (Geral/Música/Efeitos), ligados ao SettingsManager (autoload).
##
## A tab "Controlos" recebe automaticamente uma lista de ações
## remapeáveis (move_left, move_right, jump, dash, attack,
## ranged_attack, aim_up, aim_down) — clicar no botão da tecla entra
## em modo de escuta e a próxima tecla premida fica associada a essa
## ação. Esc durante a escuta cancela o remapeamento em vez de
## fechar o menu. As alterações são guardadas em
## "user://keybinds.cfg" e recarregadas sempre que este menu abre.
##
## Enquanto as tabs "Geral", "Audio" ou "Controlos" estiverem ativas,
## o menu vertical de seleção de tabs é escondido (para dar destaque
## ao conteúdo); volta a aparecer assim que se muda para outra tab.
##
## Este menu fecha com o botão "Voltar" ou com a tecla Esc, com uma
## animação de fade + scale-down do painel antes de ser removido.

signal closed

# Paleta — alinhada com o pause menu (moldura dourada) e o roxo de hover do menu principal
const COLOR_BG_OVERLAY := Color(0.03, 0.03, 0.05, 0.85)
const COLOR_PANEL_BG := Color(0.07, 0.06, 0.1, 0.92)
const COLOR_BORDER := Color(0.75, 0.58, 0.18)  # dourado, tom da moldura do pause
const COLOR_TITLE := Color(0.92, 0.8, 0.5)
const COLOR_TEXT := Color(0.85, 0.85, 0.9)
const COLOR_HOVER := Color(0.6, 0.45, 1.0)  # mesmo roxo do v_box_container.gd
const COLOR_OUTLINE := Color(0.05, 0.05, 0.08, 0.9)

const PANEL_MIN_SIZE := Vector2(560, 460)
const CORNER_RADIUS := 6
const TITLE_FONT_SIZE := 46

# Botões (estilo + animação de hover/click)
const BUTTON_FONT_SIZE := 26
const TAB_FONT_SIZE := 32
const BUTTON_SEPARATION := 28
const MARKER_PADDING := 14.0
const MARKER_SLIDE := 8.0

# Animação de saída (igual em espírito à do pause menu)
const CLOSE_ANIM_TIME := 0.3
const CLOSE_SCALE := Vector2(0.9, 0.9)

# Nomes das tabs que, quando ativas, escondem o menu vertical de seleção
const HIDDEN_SELECTOR_TABS := ["Geral", "Audio", "Controlos"]

# Nomes de exibição corretos das tabs (o nome do nó pode não ter acentos)
const TAB_TITLE_OVERRIDES := {
	"Geral": "Geral",
	"Audio": "Áudio",
	"Graficos": "Gráficos",
	"Controlos": "Controlos",
	"Extras": "Extras",
}

# --- Tab "Controlos" ---
const KEYBINDS_SAVE_PATH := "user://keybinds.cfg"
const REBINDABLE_ACTIONS := [
	"move_left", "move_right", "jump", "dash", "attack", "ranged_attack", "aim_up", "aim_down"
]
const ACTION_LABELS := {
	"move_left": "Mover Esquerda",
	"move_right": "Mover Direita",
	"jump": "Saltar",
	"dash": "Dash",
	"attack": "Ataque Corpo a Corpo",
	"ranged_attack": "Ataque à Distância",
	"aim_up": "Mirar Cima",
	"aim_down": "Mirar Baixo",
}

# --- Tab "Geral" ---
const LANGUAGE_CODES := ["pt", "en", "es"]
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720)]
const FPS_LIMIT_VALUES := [30, 60, 120, 144, 0]  # 0 = Sem Limite

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
var _closing: bool = false

# Estado do remapeamento de teclas (tab "Controlos")
var _rebinding_action: String = ""
var _rebinding_button: Button = null

# Teclas originais (predefinições do projeto), capturadas antes de carregar
# o keybinds.cfg, para poder restaurar mais tarde. action -> keycode
var _default_keybinds: Dictionary = {}
# Referências aos botões de tecla de cada ação, para atualizar o texto
# quando se restauram as predefinições. action -> Button
var _rebind_buttons: Dictionary = {}

# Diálogo de conflito ("esta tecla já está atribuída a X") e estado do
# remapeamento que fica pendente enquanto o jogador decide.
var _conflict_dialog: ConfirmationDialog = null
var _pending_rebind_action: String = ""
var _pending_rebind_keycode: int = -1
var _pending_conflict_action: String = ""
var _pending_rebind_button: Button = null

# Referências aos controlos da tab "Geral", para atualizar o valor
# selecionado quando se restauram as predefinições.
var _language_option: OptionButton
var _screen_mode_option: OptionButton
var _resolution_option: OptionButton
var _vsync_option: OptionButton
var _fps_limit_option: OptionButton
var _show_fps_option: OptionButton
var _custom_cursor_option: OptionButton


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

	# A mesma fonte pixel usada pelo menu passa para o contador de FPS.
	if pixel_font:
		SettingsManager.fps_font = pixel_font

	_build_tab_selector()
	_organize_tab_buttons()
	_build_general_tab()
	_build_audio_tab()
	_capture_default_keybinds()
	_build_controls_tab()
	_position_back_button()
	_setup_button(btn_back)

	btn_back.pressed.connect(_on_btn_back_pressed)

	if not SettingsManager.language_changed.is_connected(_on_language_changed):
		SettingsManager.language_changed.connect(_on_language_changed)

	tab_container.tab_changed.connect(_on_tab_changed)

	# Força sempre uma tab de partida onde o seletor vertical fica visível,
	# em vez de confiar no valor de current_tab gravado na cena (que reflete
	# a última tab aberta no editor). Como "Geral" é a primeira tab e esconde
	# o seletor, abrir sempre no índice 0 saltava direto para o conteúdo de
	# "Geral" sem mostrar o menu de seleção — por isso procura-se a primeira
	# tab que NÃO esconde o seletor.
	tab_container.current_tab = _get_default_tab_index()
	_on_tab_changed(tab_container.current_tab)
	_refresh_all_translations()


func _on_language_changed(_language_code: String = "") -> void:
	if not is_inside_tree():
		return
	_refresh_all_translations()


func _exit_tree() -> void:
	if SettingsManager.language_changed.is_connected(_on_language_changed):
		SettingsManager.language_changed.disconnect(_on_language_changed)


func _refresh_all_translations() -> void:
	# Elementos fixos do menu.
	title_label.text = SettingsManager.translate("options_title")
	btn_back.text = SettingsManager.translate("back")

	# Tabs do menu vertical.
	if _tab_selector_container:
		var selector_buttons := _tab_selector_container.find_children(
			"*", "Button", true, false
		)
		for i in range(mini(selector_buttons.size(), tab_container.get_child_count())):
			var selector_button: Button = selector_buttons[i] as Button
			if selector_button:
				selector_button.text = _tab_key_for_index(i)

	_refresh_general_text()
	_refresh_audio_text()
	_refresh_controls_text()
	_refresh_tab_content_text()
	_refresh_conflict_dialog()


func _tab_key_for_index(index: int) -> String:
	match index:
		0:
			return SettingsManager.translate("general")
		1:
			return SettingsManager.translate("audio")
		2:
			return SettingsManager.translate("graphics")
		3:
			return SettingsManager.translate("controls")
		4:
			return SettingsManager.translate("extras")
	return tab_container.get_tab_title(index)


func _refresh_audio_text() -> void:
	var audio_tab: Control = tab_container.get_node_or_null("Audio") as Control
	if not audio_tab:
		return

	var labels := audio_tab.find_children("*", "Label", true, false)
	var wanted := [
		SettingsManager.translate("audio"),
		SettingsManager.translate("master"),
		SettingsManager.translate("music"),
		SettingsManager.translate("sfx")
	]

	for label in labels:
		var l: Label = label as Label
		if not l:
			continue
		var key: String = str(l.get_meta("translation_key", ""))
		if key != "":
			l.text = SettingsManager.translate(key)


func _refresh_controls_text() -> void:
	var controls_tab: Control = tab_container.get_node_or_null("Controlos") as Control
	if not controls_tab:
		return

	var labels := controls_tab.find_children("*", "Label", true, false)
	for node in labels:
		var label: Label = node as Label
		if not label:
			continue
		var key: String = str(label.get_meta("translation_key", ""))
		if key != "":
			label.text = SettingsManager.translate(key)

	var buttons := controls_tab.find_children("*", "Button", true, false)
	for node in buttons:
		var button: Button = node as Button
		if not button:
			continue
		var key: String = str(button.get_meta("translation_key", ""))
		if key != "":
			button.text = SettingsManager.translate(key)


func _refresh_tab_content_text() -> void:
	# Títulos criados dinamicamente em qualquer tab.
	for node in tab_container.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if not label:
			continue
		var key: String = str(label.get_meta("translation_key", ""))
		if key != "":
			label.text = SettingsManager.translate(key)


func _refresh_conflict_dialog() -> void:
	if not _conflict_dialog:
		return

	_conflict_dialog.title = SettingsManager.translate("key_conflict_title")
	_conflict_dialog.get_ok_button().text = SettingsManager.translate("continue")
	_conflict_dialog.get_cancel_button().text = SettingsManager.translate("cancel")

	if _pending_rebind_action != "" and _pending_conflict_action != "":
		var key_name := _key_display_name(_pending_rebind_keycode)
		var this_label := SettingsManager.translate(_pending_rebind_action)
		var conflict_label := SettingsManager.translate(_pending_conflict_action)
		_conflict_dialog.dialog_text = SettingsManager.translate(
			"key_conflict_message"
		) % [key_name, conflict_label, this_label, conflict_label]


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return

	# Enquanto o diálogo de conflito de teclas está aberto, ignora outros
	# inputs aqui (o próprio diálogo trata do seu Esc/Enter).
	if _conflict_dialog and _conflict_dialog.visible:
		return

	# Enquanto se está à espera de uma tecla para remapear uma ação, qualquer
	# tecla premida é capturada aqui — Esc cancela o remapeamento em vez de
	# fechar o menu.
	if _rebinding_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if keycode == KEY_ESCAPE:
				_rebinding_button.text = _get_action_key_display(_rebinding_action)
				_rebinding_action = ""
				_rebinding_button = null
			else:
				var conflict_action := _find_conflicting_action(_rebinding_action, keycode)
				if conflict_action != "":
					_show_rebind_conflict_dialog(_rebinding_action, keycode, conflict_action, _rebinding_button)
				else:
					_apply_rebind(_rebinding_action, keycode)
					_rebinding_button.text = _key_display_name(keycode)
				_rebinding_action = ""
				_rebinding_button = null
			get_viewport().set_input_as_handled()
		return

	# Fecha o menu de opções com Esc, tal como o botão "Voltar".
	var is_cancel: bool = event.is_action_pressed("ui_cancel")
	var is_escape_key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE

	if is_cancel or is_escape_key:
		_on_btn_back_pressed()
		get_viewport().set_input_as_handled()


func _on_btn_back_pressed() -> void:
	if _closing:
		return
	_closing = true
	btn_back.disabled = true

	panel.pivot_offset = panel.size / 2.0
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, CLOSE_ANIM_TIME)
	tween.tween_property(panel, "scale", CLOSE_SCALE, CLOSE_ANIM_TIME)
	await tween.finished

	closed.emit()
	queue_free()


func _get_default_tab_index() -> int:
	# Preferir "Gráficos/Graficos" para o menu abrir com o seletor visível.
	for i in tab_container.get_child_count():
		var tab_name := tab_container.get_child(i).name
		if tab_name == "Graficos" or tab_name == "Gráficos":
			return i

	for i in tab_container.get_child_count():
		if tab_container.get_child(i).name not in HIDDEN_SELECTOR_TABS:
			return i

	return 0


func _on_tab_changed(tab_idx: int) -> void:
	if not _tab_selector_container:
		return
	var tab_node := tab_container.get_child(tab_idx)
	var show_selector := tab_node.name not in HIDDEN_SELECTOR_TABS
	_tab_selector_container.visible = show_selector
	title_label.visible = show_selector


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
	style.content_margin_top = 4
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)

	# O TabContainer desenha o seu próprio fundo "panel" (opaco, do tema
	# base do Godot) atrás do conteúdo da tab ativa — sem isto, essa caixa
	# ficava visível mesmo com o PanelContainer transparente.
	tab_container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


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
		var tab_key := _tab_key_for_index(i)
		btn.text = tab_key
		btn.set_meta("translation_key", [
			"general", "audio", "graphics", "controls", "extras"
		][i] if i < 5 else "")
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


func _build_general_tab() -> void:
	var general_tab: Control = tab_container.get_node_or_null("Geral") as Control
	if not general_tab:
		return

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top -= 80
	center.offset_bottom -= 80
	general_tab.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var general_title := _build_tab_title(SettingsManager.translate("general"))
	general_title.set_meta("translation_key", "general")
	vbox.add_child(general_title)

	var title_spacer := Control.new()
	title_spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(title_spacer)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	# Idioma
	_language_option = _add_option_row(
		grid,
		_tr("language"),
		[_tr("portuguese"), _tr("english"), _tr("spanish")]
	)

	var lang_idx := LANGUAGE_CODES.find(SettingsManager.current_language)
	_language_option.selected = lang_idx if lang_idx != -1 else 0

	_language_option.item_selected.connect(func(idx: int):
		SettingsManager.set_language(LANGUAGE_CODES[idx])
		SettingsManager.save_settings()
	)

	# Modo de Ecrã
	_screen_mode_option = _add_option_row(
		grid,
		_tr("screen_mode"),
		[
			_tr("windowed"),
			_tr("borderless"),
			_tr("fullscreen")
		]
	)
	_screen_mode_option.selected = SettingsManager.screen_mode

	_screen_mode_option.item_selected.connect(func(idx: int):
		SettingsManager.set_screen_mode(idx)
		SettingsManager.save_settings()
	)

	# Resolução
	_resolution_option = _add_option_row(
		grid,
		_tr("resolution"),
		["1920 x 1080", "1280 x 720"]
	)
	_resolution_option.selected = (
		0 if SettingsManager.resolution == RESOLUTIONS[0] else 1
	)

	_resolution_option.item_selected.connect(func(idx: int):
		SettingsManager.set_resolution(RESOLUTIONS[idx])
		SettingsManager.save_settings()
	)

	# V-Sync
	_vsync_option = _add_option_row(
		grid,
		_tr("vsync"),
		[_tr("enabled"), _tr("disabled")]
	)
	_vsync_option.selected = 0 if SettingsManager.vsync_enabled else 1

	_vsync_option.item_selected.connect(func(idx: int):
		SettingsManager.set_vsync(idx == 0)
		SettingsManager.save_settings()
	)

	# Limite de FPS
	_fps_limit_option = _add_option_row(
		grid,
		_tr("fps_limit"),
		["30", "60", "120", "144", _tr("unlimited")]
	)

	var fps_idx := FPS_LIMIT_VALUES.find(SettingsManager.fps_limit)
	_fps_limit_option.selected = fps_idx if fps_idx != -1 else 1

	_fps_limit_option.item_selected.connect(func(idx: int):
		SettingsManager.set_fps_limit(FPS_LIMIT_VALUES[idx])
		SettingsManager.save_settings()
	)

	# Mostrar FPS
	_show_fps_option = _add_option_row(
		grid,
		_tr("show_fps"),
		[_tr("enabled"), _tr("disabled")]
	)
	_show_fps_option.selected = 0 if SettingsManager.show_fps else 1

	_show_fps_option.item_selected.connect(func(idx: int):
		SettingsManager.set_show_fps(idx == 0)
		SettingsManager.save_settings()
	)

	# Cursor Personalizado
	_custom_cursor_option = _add_option_row(
		grid,
		_tr("custom_cursor"),
		[_tr("enabled"), _tr("disabled")]
	)
	_custom_cursor_option.selected = 0 if SettingsManager.custom_cursor_enabled else 1

	_custom_cursor_option.item_selected.connect(func(idx: int):
		SettingsManager.set_custom_cursor(idx == 0)
		SettingsManager.save_settings()
	)

	var restore_spacer := Control.new()
	restore_spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(restore_spacer)

	var restore_btn := Button.new()
	restore_btn.text = _tr("restore_defaults")
	vbox.add_child(restore_btn)
	_setup_button(restore_btn, 22)

	restore_btn.pressed.connect(_on_restore_general_defaults_pressed)

	# Guarda referências para atualizar os textos quando o idioma mudar.
	restore_btn.set_meta("translation_key", "restore_defaults")
	general_tab.set_meta("general_restore_button", restore_btn)
	general_tab.set_meta("general_grid", grid)


func _add_option_row(
	grid: GridContainer,
	label_text: String,
	items: Array,
	translation_key: String = ""
) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	if translation_key != "":
		label.set_meta("translation_key", translation_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 26)
	if pixel_font:
		label.add_theme_font_override("font", pixel_font)
	grid.add_child(label)

	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(220, 48)
	for item in items:
		option.add_item(item)
	_style_option_button(option)
	grid.add_child(option)

	return option


func _style_option_button(option: OptionButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.13, 0.18, 0.9)
	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	option.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.border_color = COLOR_HOVER
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("focus", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(COLOR_HOVER.r, COLOR_HOVER.g, COLOR_HOVER.b, 0.3)
	option.add_theme_stylebox_override("pressed", pressed)

	option.add_theme_color_override("font_color", COLOR_TEXT)
	option.add_theme_color_override("font_hover_color", COLOR_HOVER)
	option.add_theme_font_size_override("font_size", 22)
	if pixel_font:
		option.add_theme_font_override("font", pixel_font)

	var popup := option.get_popup()
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = COLOR_PANEL_BG
	popup_style.border_color = COLOR_BORDER
	popup_style.set_border_width_all(1)
	popup_style.set_corner_radius_all(4)
	popup.add_theme_stylebox_override("panel", popup_style)
	popup.add_theme_color_override("font_color", COLOR_TEXT)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_accent_color", COLOR_HOVER)
	popup.add_theme_font_size_override("font_size", 20)
	if pixel_font:
		popup.add_theme_font_override("font", pixel_font)


func _tr(key: String) -> String:
	return SettingsManager.translate(key)

func _refresh_general_text() -> void:
	var general_tab := tab_container.get_node_or_null("Geral")
	if not general_tab:
		return

	var grid: GridContainer = general_tab.get_meta("general_grid", null) as GridContainer
	if not grid:
		return

	# O grid é composto por Label + OptionButton em pares.
	var labels := [
		_tr("language"),
		_tr("screen_mode"),
		_tr("resolution"),
		_tr("vsync"),
		_tr("fps_limit"),
		_tr("show_fps"),
		_tr("custom_cursor")
	]

	var option_items := [
		[_tr("portuguese"), _tr("english"), _tr("spanish")],
		[_tr("windowed"), _tr("borderless"), _tr("fullscreen")],
		["1920 x 1080", "1280 x 720"],
		[_tr("enabled"), _tr("disabled")],
		["30", "60", "120", "144", _tr("unlimited")],
		[_tr("enabled"), _tr("disabled")],
		[_tr("enabled"), _tr("disabled")]
	]

	for i in range(labels.size()):
		var label_node := grid.get_child(i * 2) as Label
		var option_node := grid.get_child(i * 2 + 1) as OptionButton

		if label_node:
			label_node.text = labels[i]

		if option_node:
			var previous := option_node.selected
			option_node.clear()

			for item in option_items[i]:
				option_node.add_item(item)

			option_node.selected = clampi(
				previous,
				0,
				maxi(0, option_node.item_count - 1)
			)

	var restore_btn: Button = general_tab.get_meta("general_restore_button", null) as Button
	if restore_btn:
		restore_btn.text = _tr("restore_defaults")


func _on_restore_general_defaults_pressed() -> void:
	SettingsManager.restore_general_defaults()

	_language_option.selected = LANGUAGE_CODES.find(
		SettingsManager.current_language
	)
	_screen_mode_option.selected = SettingsManager.screen_mode
	_resolution_option.selected = (
		0 if SettingsManager.resolution == RESOLUTIONS[0] else 1
	)
	_vsync_option.selected = 0 if SettingsManager.vsync_enabled else 1

	var fps_idx := FPS_LIMIT_VALUES.find(SettingsManager.fps_limit)
	_fps_limit_option.selected = fps_idx if fps_idx != -1 else 1

	_show_fps_option.selected = 0 if SettingsManager.show_fps else 1
	_custom_cursor_option.selected = 0 if SettingsManager.custom_cursor_enabled else 1

	_refresh_general_text()
	_play_sound(click_sound)


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

	var audio_title := _build_tab_title(SettingsManager.translate("audio"))
	audio_title.set_meta("translation_key", "audio")
	vbox.add_child(audio_title)

	_add_volume_slider(vbox, SettingsManager.translate("master"), SettingsManager.BUS_MASTER, "master")
	_add_volume_slider(vbox, SettingsManager.translate("music"), SettingsManager.BUS_MUSIC, "music")
	_add_volume_slider(vbox, SettingsManager.translate("sfx"), SettingsManager.BUS_SFX, "sfx")


func _add_volume_slider(parent: VBoxContainer, label_text: String, bus_name: String, translation_key: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.set_meta("translation_key", translation_key)
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


func _build_controls_tab() -> void:
	var controls_tab := tab_container.get_node_or_null("Controlos")
	if not controls_tab:
		return

	_load_keybinds()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top -= 170
	center.offset_bottom -= 170
	controls_tab.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := _build_tab_title(SettingsManager.translate("controls"))
	title.set_meta("translation_key", "controls")
	vbox.add_child(title)

	var title_spacer := Control.new()
	title_spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(title_spacer)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 18)
	# encolhe ao conteúdo e centra dentro do vbox, para ficar alinhado
	# com o título (que também está centrado, mas ocupa a largura toda)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	for action in REBINDABLE_ACTIONS:
		_add_rebind_row(grid, action)

	_add_fixed_row(grid, SettingsManager.translate("pause"), "Esc", "pause")

	var restore_spacer := Control.new()
	restore_spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(restore_spacer)

	var restore_btn := Button.new()
	restore_btn.text = SettingsManager.translate("restore_controls")
	restore_btn.set_meta("translation_key", "restore_controls")
	vbox.add_child(restore_btn)
	_setup_button(restore_btn, 22)
	restore_btn.pressed.connect(_on_restore_defaults_pressed)


func _add_rebind_row(grid: GridContainer, action: String) -> void:
	var label := Label.new()
	label.text = SettingsManager.translate(action)
	label.set_meta("translation_key", action)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 28)
	if pixel_font:
		label.add_theme_font_override("font", pixel_font)
	grid.add_child(label)

	var key_btn := Button.new()
	key_btn.custom_minimum_size = Vector2(170, 52)
	key_btn.text = _get_action_key_display(action)
	_style_rebind_button(key_btn)
	grid.add_child(key_btn)

	key_btn.pressed.connect(func(): _start_rebind(action, key_btn))
	_rebind_buttons[action] = key_btn


func _add_fixed_row(grid: GridContainer, label_text: String, key_text: String, translation_key: String = "") -> void:
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 28)
	if pixel_font:
		label.add_theme_font_override("font", pixel_font)
	grid.add_child(label)

	var key_label := Label.new()
	key_label.text = key_text
	key_label.custom_minimum_size = Vector2(170, 52)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.modulate.a = 0.6
	key_label.add_theme_color_override("font_color", COLOR_TEXT)
	key_label.add_theme_font_size_override("font_size", 28)
	if pixel_font:
		key_label.add_theme_font_override("font", pixel_font)
	grid.add_child(key_label)


func _build_tab_title(text: String) -> Label:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_font_size_override("font_size", 48)
	if pixel_font:
		title.add_theme_font_override("font", pixel_font)
	_add_title_glow(title)
	return title


func _add_title_glow(title: Label) -> void:
	# Halo dourado atrás do texto (sombra com offset 0, só o "outline" da
	# sombra cria o efeito de brilho à volta das letras), fixo, sem animação.
	var glow_color := Color(COLOR_TITLE.r, COLOR_TITLE.g, COLOR_TITLE.b, 0.85)
	title.add_theme_color_override("font_shadow_color", glow_color)
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 10)


func _style_rebind_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.13, 0.18, 0.9)
	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.border_color = COLOR_HOVER
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(COLOR_HOVER.r, COLOR_HOVER.g, COLOR_HOVER.b, 0.3)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_HOVER)
	btn.add_theme_font_size_override("font_size", 26)
	if pixel_font:
		btn.add_theme_font_override("font", pixel_font)


func _get_action_key_display(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return _key_display_name(keycode)
	return "—"


func _key_display_name(keycode: int) -> String:
	match keycode:
		KEY_SPACE:
			return "Espaço"
		KEY_ESCAPE:
			return "Esc"
		KEY_SHIFT:
			return "Shift"
		KEY_UP:
			return "Cima"
		KEY_DOWN:
			return "Baixo"
		KEY_LEFT:
			return "Esquerda"
		KEY_RIGHT:
			return "Direita"
		_:
			return OS.get_keycode_string(keycode)


func _start_rebind(action: String, btn: Button) -> void:
	if _rebinding_action != "":
		return
	_rebinding_action = action
	_rebinding_button = btn
	btn.text = "..."


func _apply_rebind(action: String, keycode: int) -> void:
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)
	_save_keybinds()


func _find_conflicting_action(action: String, keycode: int) -> String:
	# Procura se a tecla já está atribuída a outra ação remapeável.
	for other_action in REBINDABLE_ACTIONS:
		if other_action == action:
			continue
		for event in InputMap.action_get_events(other_action):
			if event is InputEventKey:
				var other_keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				if other_keycode == keycode:
					return other_action
	return ""


func _show_rebind_conflict_dialog(action: String, keycode: int, conflict_action: String, button: Button) -> void:
	_pending_rebind_action = action
	_pending_rebind_keycode = keycode
	_pending_conflict_action = conflict_action
	_pending_rebind_button = button

	if not _conflict_dialog:
		_conflict_dialog = ConfirmationDialog.new()
		_conflict_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_conflict_dialog)
		_style_conflict_dialog(_conflict_dialog)
		_conflict_dialog.confirmed.connect(_on_rebind_conflict_confirmed)
		_conflict_dialog.canceled.connect(_on_rebind_conflict_canceled)
		_conflict_dialog.close_requested.connect(_on_rebind_conflict_canceled)

	var key_name := _key_display_name(keycode)
	var this_label: String = SettingsManager.translate(action)
	var conflict_label: String = SettingsManager.translate(conflict_action)

	_conflict_dialog.dialog_text = SettingsManager.translate("key_conflict_message") % [
		key_name, conflict_label, this_label, conflict_label
	]
	_conflict_dialog.get_ok_button().text = SettingsManager.translate("continue")
	_conflict_dialog.get_cancel_button().text = SettingsManager.translate("cancel")
	_conflict_dialog.popup_centered()
	panel.visible = false


func _style_conflict_dialog(dialog: ConfirmationDialog) -> void:
	dialog.unresizable = true
	dialog.min_size = Vector2(320, 220)

	# Esconde o "X" de fechar do título tornando o ícone transparente —
	# ConfirmationDialog não expõe um get_close_button() nesta versão do
	# Godot, por isso a forma segura é sobrepor o ícone "close" do tema.
	var transparent_img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	transparent_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var transparent_icon := ImageTexture.create_from_image(transparent_img)
	dialog.add_theme_icon_override("close", transparent_icon)
	dialog.add_theme_icon_override("close_pressed", transparent_icon)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.border_color = COLOR_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(CORNER_RADIUS)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	panel_style.shadow_size = 14
	panel_style.content_margin_left = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 22
	dialog.add_theme_stylebox_override("panel", panel_style)

	dialog.add_theme_color_override("title_color", COLOR_TITLE)
	dialog.add_theme_font_size_override("title_font_size", 24)
	if pixel_font:
		dialog.add_theme_font_override("title_font", pixel_font)
	dialog.title = SettingsManager.translate("key_conflict_title")

	var message_label := dialog.get_label()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.custom_minimum_size = Vector2(280, 140)
	message_label.add_theme_color_override("font_color", COLOR_TEXT)
	message_label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	message_label.add_theme_constant_override("outline_size", 3)
	message_label.add_theme_font_size_override("font_size", 21)
	message_label.add_theme_constant_override("line_spacing", 8)
	if pixel_font:
		message_label.add_theme_font_override("font", pixel_font)

	# "Avançar" fica com um tom de aviso (avermelhado) para deixar claro que
	# é a opção que remove a tecla da outra ação; "Cancelar" mantém o dourado.
	_style_dialog_button(dialog.get_ok_button(), Color(0.78, 0.32, 0.26))
	_style_dialog_button(dialog.get_cancel_button(), COLOR_BORDER)


func _style_dialog_button(btn: Button, accent_color: Color) -> void:
	btn.custom_minimum_size = Vector2(150, 46)
	btn.focus_mode = Control.FOCUS_NONE

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.11, 0.16, 0.95)
	normal.border_color = accent_color
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate()
	hover.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.28)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.45)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("focus", normal)

	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 22)
	if pixel_font:
		btn.add_theme_font_override("font", pixel_font)

	_add_animated_button_markers(btn, accent_color, 22)


func _on_rebind_conflict_confirmed() -> void:
	panel.visible = true
	InputMap.action_erase_events(_pending_conflict_action)
	_apply_rebind(_pending_rebind_action, _pending_rebind_keycode)
	if _pending_rebind_button:
		_pending_rebind_button.text = _key_display_name(_pending_rebind_keycode)
	if _rebind_buttons.has(_pending_conflict_action):
		_rebind_buttons[_pending_conflict_action].text = "—"
	_save_keybinds()
	_clear_pending_rebind()


func _on_rebind_conflict_canceled() -> void:
	panel.visible = true
	if _pending_rebind_button:
		_pending_rebind_button.text = _get_action_key_display(_pending_rebind_action)
	_clear_pending_rebind()


func _clear_pending_rebind() -> void:
	_pending_rebind_action = ""
	_pending_rebind_keycode = -1
	_pending_conflict_action = ""
	_pending_rebind_button = null


func _capture_default_keybinds() -> void:
	# Lê as definições ORIGINAIS do Input Map a partir do ProjectSettings,
	# em vez do InputMap em runtime — este último pode já ter sido alterado
	# por um remapeamento anterior nesta mesma sessão de jogo (o InputMap
	# runtime não volta sozinho ao que está no project.godot). O
	# ProjectSettings guarda sempre a definição original de cada action,
	# por isso é a fonte fiável para "Restaurar Predefinições".
	for action in REBINDABLE_ACTIONS:
		var action_name: String = action
		var setting_path: String = "input/" + action_name
		if not ProjectSettings.has_setting(setting_path):
			continue
		var action_data: Dictionary = ProjectSettings.get_setting(setting_path)
		for event in action_data.get("events", []):
			if event is InputEventKey:
				var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				_default_keybinds[action] = keycode
				break


func _on_restore_defaults_pressed() -> void:
	for action in REBINDABLE_ACTIONS:
		if not _default_keybinds.has(action):
			continue
		var keycode: int = _default_keybinds[action]
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)
		if _rebind_buttons.has(action):
			_rebind_buttons[action].text = _key_display_name(keycode)
	_save_keybinds()
	_play_sound(click_sound)


func _load_keybinds() -> void:
	var config := ConfigFile.new()
	if config.load(KEYBINDS_SAVE_PATH) != OK:
		return
	for action in REBINDABLE_ACTIONS:
		if config.has_section_key("keybinds", action):
			var keycode: int = config.get_value("keybinds", action)
			InputMap.action_erase_events(action)
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)


func _save_keybinds() -> void:
	var config := ConfigFile.new()
	config.load(KEYBINDS_SAVE_PATH)  # ignora erro — o ficheiro pode ainda não existir
	for action in REBINDABLE_ACTIONS:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				config.set_value("keybinds", action, keycode)
				break
	config.save(KEYBINDS_SAVE_PATH)


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

	_add_animated_button_markers(btn, COLOR_HOVER, font_size)


func _add_animated_button_markers(btn: Button, marker_color: Color, font_size: int) -> void:
	var marker_left := Label.new()
	var marker_right := Label.new()
	marker_left.text = "<"
	marker_right.text = ">"

	for marker in [marker_left, marker_right]:
		marker.add_theme_color_override("font_color", marker_color)
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
