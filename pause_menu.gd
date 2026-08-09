extends CanvasLayer
## Menu de Pausa
## Estrutura de cena esperada (PauseMenu.tscn):
##
## PauseMenu (CanvasLayer)
## └── Control (Control) — full rect, ancora em todo o ecrã
##     ├── ColorRect (fundo semi-transparente, opcional)
##     ├── FrameTop (TextureRect) — moldura decorativa por cima do texto
##     ├── VBoxContainer (centrado) — botões do menu
##     │   ├── BtnResume (Button)
##     │   ├── BtnOptions (Button)
##     │   └── BtnQuit (Button)
##     ├── FrameBottom (TextureRect) — moldura decorativa por baixo do texto
##     └── QuitConfirmPanel (Panel) — começa oculto
##           └── VBoxContainer
##               ├── Label
##               └── HBoxContainer
##                   ├── BtnQuitYes (Button)
##                   └── BtnQuitCancel (Button)
## └── MenuSfxPlayer (AudioStreamPlayer) — som de abrir/fechar o menu
##
## Anexa este script ao nó raiz PauseMenu (CanvasLayer).
## Ajusta MAIN_MENU_SCENE_PATH e OPTIONS_MENU_SCENE aos caminhos reais das tuas cenas.

const MAIN_MENU_SCENE_PATH := "res://MainMenu.tscn"
const OPTIONS_MENU_SCENE: PackedScene = preload("res://options_menu.tscn")

@onready var control: Control = $Control
@onready var menu_box: VBoxContainer = $Control/VBoxContainer
@onready var btn_resume: Button = $Control/VBoxContainer/BtnResume
@onready var btn_options: Button = $Control/VBoxContainer/BtnOptions
@onready var btn_quit: Button = $Control/VBoxContainer/BtnQuit

@onready var quit_confirm_panel: Panel = $Control/QuitConfirmPanel
@onready var btn_quit_yes: Button = $Control/QuitConfirmPanel/VBoxContainer/HBoxContainer/BtnQuitYes
@onready var btn_quit_cancel: Button = $Control/QuitConfirmPanel/VBoxContainer/HBoxContainer/BtnQuitCancel

@onready var quit_confirm_label: Label = $Control/QuitConfirmPanel/VBoxContainer/Label

# Frames decorativos
@onready var frame_top: TextureRect = $Control/FrameTop
@onready var frame_bottom: TextureRect = $Control/FrameBottom

# Som de abrir/fechar o menu
@onready var menu_sfx_player: AudioStreamPlayer = $MenuSfxPlayer
@export var open_sound: AudioStream
@export var close_sound: AudioStream

var _frame_top_rest_pos: Vector2
var _frame_bottom_rest_pos: Vector2
var _menu_box_rest_pos: Vector2

const FRAME_SLIDE_DISTANCE := 40.0
const FRAME_ANIM_TIME := 0.35
const FRAME_FADE_TIME := 0.15
const MENU_BOX_SLIDE_DISTANCE := 30.0
const FRAME_GAP := 16.0  # espaço entre a moldura e o menu_box

var _is_open: bool = false
var _options_menu_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS

	control.visible = false
	quit_confirm_panel.visible = false

	# guarda as posições finais definidas na cena, para animar a partir delas
	_menu_box_rest_pos = menu_box.position

	# espera o layout calcular o tamanho real do menu_box antes de posicionar as molduras
	await get_tree().process_frame

	_frame_top_rest_pos = Vector2(
		frame_top.position.x,
		_menu_box_rest_pos.y - frame_top.size.y - FRAME_GAP
	)
	_frame_bottom_rest_pos = Vector2(
		frame_bottom.position.x,
		_menu_box_rest_pos.y + menu_box.size.y + FRAME_GAP
	)
	frame_top.position = _frame_top_rest_pos
	frame_bottom.position = _frame_bottom_rest_pos

	frame_top.modulate.a = 0.0
	frame_bottom.modulate.a = 0.0
	menu_box.modulate.a = 0.0

	btn_resume.pressed.connect(_on_resume_pressed)
	btn_options.pressed.connect(_on_options_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_quit_yes.pressed.connect(_on_quit_confirmed)
	btn_quit_cancel.pressed.connect(_on_quit_cancelled)
	
	_refresh_language()
	if not SettingsManager.language_changed.is_connected(_on_language_changed):
		SettingsManager.language_changed.connect(_on_language_changed)
	
	
func _on_language_changed(_language_code: String = "") -> void:
	_refresh_language()


func _refresh_language() -> void:
	btn_resume.text = SettingsManager.translate("resume")
	btn_options.text = SettingsManager.translate("options")
	btn_quit.text = SettingsManager.translate("quit")
	quit_confirm_label.text = SettingsManager.translate("quit_confirm_message")
	btn_quit_yes.text = SettingsManager.translate("yes")
	btn_quit_cancel.text = SettingsManager.translate("no")
	
func _exit_tree() -> void:
	if SettingsManager.language_changed.is_connected(_on_language_changed):
		SettingsManager.language_changed.disconnect(_on_language_changed)

func _unhandled_input(event: InputEvent) -> void:
	# Enquanto o OptionsMenu estiver aberto, o Esc não faz nada aqui — só o
	# botão "Voltar" dele é que fecha esse menu. Isto evita depender da ordem
	# de propagação do evento entre os dois scripts.
	if _options_menu_open:
		return

	# Não permite abrir (nem alternar) o menu de pausa enquanto se está no
	# menu principal.
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == MAIN_MENU_SCENE_PATH:
		return

	var is_cancel: bool = event.is_action_pressed("ui_cancel")
	var is_escape_key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE

	if is_cancel or is_escape_key:
		if quit_confirm_panel.visible:
			_on_quit_cancelled()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if _is_open:
		_resume()
	else:
		_open()


func _open() -> void:
	_is_open = true
	control.visible = true
	menu_box.visible = true
	quit_confirm_panel.visible = false
	get_tree().paused = true
	btn_resume.grab_focus()
	_animate_frames_in()
	_animate_menu_box_in()
	_play_menu_sound(open_sound)


func _resume() -> void:
	_is_open = false
	_animate_frames_out()
	_animate_menu_box_out()
	_play_menu_sound(close_sound)
	# espera a animação terminar antes de esconder tudo e retomar o jogo
	await get_tree().create_timer(FRAME_ANIM_TIME, true, false, true).timeout
	control.visible = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	_resume()


func _on_options_pressed() -> void:
	var options := OPTIONS_MENU_SCENE.instantiate()
	options.process_mode = Node.PROCESS_MODE_ALWAYS
	control.add_child(options)
	menu_box.visible = false
	frame_top.visible = false
	frame_bottom.visible = false
	_options_menu_open = true
	options.closed.connect(func():
		_options_menu_open = false
		menu_box.visible = true
		frame_top.visible = true
		frame_bottom.visible = true
		btn_options.grab_focus()
	)


func _on_quit_pressed() -> void:
	quit_confirm_panel.visible = true
	btn_quit_cancel.grab_focus()
	_animate_frames_out(true)   # esconde os frames enquanto confirma saída
	_animate_menu_box_out(true, true)  # esconde o texto dos botões também


func _on_quit_cancelled() -> void:
	quit_confirm_panel.visible = false
	menu_box.visible = true
	btn_quit.grab_focus()
	_animate_frames_in()      # volta a mostrar os frames
	_animate_menu_box_in()    # volta a mostrar o texto dos botões


func _on_quit_confirmed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _play_menu_sound(stream: AudioStream) -> void:
	if stream and menu_sfx_player:
		menu_sfx_player.stream = stream
		menu_sfx_player.play()


func _animate_frames_in() -> void:
	frame_top.position = _frame_top_rest_pos - Vector2(0, FRAME_SLIDE_DISTANCE)
	frame_bottom.position = _frame_bottom_rest_pos + Vector2(0, FRAME_SLIDE_DISTANCE)

	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(frame_top, "position", _frame_top_rest_pos, FRAME_ANIM_TIME)
	tween.tween_property(frame_bottom, "position", _frame_bottom_rest_pos, FRAME_ANIM_TIME)
	tween.tween_property(frame_top, "modulate:a", 1.0, FRAME_ANIM_TIME)
	tween.tween_property(frame_bottom, "modulate:a", 1.0, FRAME_ANIM_TIME)


func _animate_frames_out(quick: bool = false) -> void:
	var duration := FRAME_FADE_TIME if quick else FRAME_ANIM_TIME
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(frame_top, "modulate:a", 0.0, duration)
	tween.tween_property(frame_bottom, "modulate:a", 0.0, duration)
	if not quick:
		tween.tween_property(frame_top, "position", _frame_top_rest_pos - Vector2(0, FRAME_SLIDE_DISTANCE), duration)
		tween.tween_property(frame_bottom, "position", _frame_bottom_rest_pos + Vector2(0, FRAME_SLIDE_DISTANCE), duration)


func _animate_menu_box_in() -> void:
	menu_box.visible = true
	menu_box.position = _menu_box_rest_pos - Vector2(0, MENU_BOX_SLIDE_DISTANCE)

	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(menu_box, "position", _menu_box_rest_pos, FRAME_ANIM_TIME)
	tween.tween_property(menu_box, "modulate:a", 1.0, FRAME_ANIM_TIME)


func _animate_menu_box_out(quick: bool = false, keep_visible: bool = false) -> void:
	var duration := FRAME_FADE_TIME if quick else FRAME_ANIM_TIME
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(menu_box, "modulate:a", 0.0, duration)
	if not quick:
		tween.tween_property(menu_box, "position", _menu_box_rest_pos - Vector2(0, MENU_BOX_SLIDE_DISTANCE), duration)

	if not keep_visible:
		tween.finished.connect(func(): menu_box.visible = false)
		
