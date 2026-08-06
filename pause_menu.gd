extends CanvasLayer
## Menu de Pausa
## Estrutura de cena esperada (PauseMenu.tscn):
##
## PauseMenu (CanvasLayer)
## └── Control (Control) — full rect, ancora em todo o ecrã
##     ├── ColorRect (fundo semi-transparente, opcional)
##     ├── VBoxContainer (centrado)
##     │   ├── BtnResume (Button) — texto "Retomar"
##     │   ├── BtnOptions (Button) — texto "Opções"
##     │   └── BtnQuit (Button) — texto "Sair"
##     └── QuitConfirmPanel (Panel) — começa oculto (Visible = Off no Inspector)
##           └── VBoxContainer
##               ├── Label — texto da pergunta
##               └── HBoxContainer
##                   ├── BtnQuitYes (Button) — texto "Sim, sair"
##                   └── BtnQuitCancel (Button) — texto "Cancelar"
##
## Anexa este script ao nó raiz PauseMenu (CanvasLayer).
## Ajusta MAIN_MENU_SCENE_PATH ao caminho real da tua cena de Menu Principal.

const MAIN_MENU_SCENE_PATH := "res://MainMenu.tscn"

@onready var control: Control = $Control
@onready var menu_box: VBoxContainer = $Control/VBoxContainer
@onready var btn_resume: Button = $Control/VBoxContainer/BtnResume
@onready var btn_options: Button = $Control/VBoxContainer/BtnOptions
@onready var btn_quit: Button = $Control/VBoxContainer/BtnQuit

@onready var quit_confirm_panel: Panel = $Control/QuitConfirmPanel
@onready var btn_quit_yes: Button = $Control/QuitConfirmPanel/VBoxContainer/HBoxContainer/BtnQuitYes
@onready var btn_quit_cancel: Button = $Control/QuitConfirmPanel/VBoxContainer/HBoxContainer/BtnQuitCancel

var _is_open: bool = false


func _ready() -> void:
	# DEBUG temporário — confirma se os nós foram encontrados corretamente.
	# Podes apagar estas 2 linhas assim que confirmares que está tudo OK.
	print("PauseMenu _ready a correr")
	print("btn_quit_yes = ", btn_quit_yes, " | btn_quit_cancel = ", btn_quit_cancel, " | quit_confirm_panel = ", quit_confirm_panel)

	# Garante que este nó (e os filhos) continuam a processar mesmo com o jogo pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

	control.visible = false
	quit_confirm_panel.visible = false

	btn_resume.pressed.connect(_on_resume_pressed)
	btn_options.pressed.connect(_on_options_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	btn_quit_yes.pressed.connect(_on_quit_confirmed)
	btn_quit_cancel.pressed.connect(_on_quit_cancelled)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):  # tecla ESC por defeito
		if quit_confirm_panel.visible:
			# ESC no ecrã de confirmação funciona como "Cancelar"
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


func _resume() -> void:
	_is_open = false
	control.visible = false
	get_tree().paused = false


func _on_resume_pressed() -> void:
	_resume()


func _on_options_pressed() -> void:
	# TODO: abrir o teu ecrã/painel de Opções aqui
	pass


func _on_quit_pressed() -> void:
	# esconde o menu principal de pausa e mostra só a confirmação
	menu_box.visible = false
	quit_confirm_panel.visible = true
	btn_quit_cancel.grab_focus()


func _on_quit_cancelled() -> void:
	quit_confirm_panel.visible = false
	menu_box.visible = true
	btn_quit.grab_focus()


func _on_quit_confirmed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
