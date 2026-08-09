extends Control
@onready var menu_buttons: Control = $VBoxContainer
@onready var btn_new_game: Button = $VBoxContainer/BtnNewGame
@onready var btn_options: Button = $VBoxContainer/BtnOptions
@onready var btn_quit: Button = $VBoxContainer/BtnQuit
var options_layer: CanvasLayer
var options_menu: Control
func _ready() -> void:
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_options.pressed.connect(_on_options_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	_refresh_language()
	if not SettingsManager.language_changed.is_connected(_on_language_changed):
		SettingsManager.language_changed.connect(_on_language_changed)
func _exit_tree() -> void:
	if SettingsManager.language_changed.is_connected(_on_language_changed):
		SettingsManager.language_changed.disconnect(_on_language_changed)
func _on_language_changed(_language_code: String) -> void:
	_refresh_language()
func _refresh_language() -> void:
	btn_new_game.text = SettingsManager.translate("new_game")
	btn_options.text = SettingsManager.translate("options")
	btn_quit.text = SettingsManager.translate("quit")
func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Player.tscn")
func _on_options_pressed() -> void:
	if is_instance_valid(options_menu):
		return
	# ESCONDER COMPLETAMENTE O MENU PRINCIPAL
	menu_buttons.hide()
	menu_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Criar camada acima de tudo
	options_layer = CanvasLayer.new()
	options_layer.name = "OptionsLayer"
	options_layer.layer = 100
	add_child(options_layer)
	# Criar menu de opções
	var options_scene: PackedScene = preload("res://options_menu.tscn")
	options_menu = options_scene.instantiate() as Control
	if options_menu == null:
		push_error("Não foi possível carregar options_menu.tscn")
		_close_options()
		return
	options_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	options_layer.add_child(options_menu)
	if options_menu.has_signal("closed"):
		options_menu.closed.connect(_close_options)
func _close_options() -> void:
	if is_instance_valid(options_layer):
		options_layer.queue_free()
	options_layer = null
	options_menu = null
	# MOSTRAR NOVAMENTE O MENU PRINCIPAL
	menu_buttons.show()
	menu_buttons.mouse_filter = Control.MOUSE_FILTER_STOP
	_refresh_language()
func _on_quit_pressed() -> void:
	get_tree().quit()
