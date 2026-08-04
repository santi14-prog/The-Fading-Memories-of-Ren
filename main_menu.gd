extends Control

func _ready():
	$VBoxContainer/BtnNewGame.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/BtnOptions.pressed.connect(_on_options_pressed)
	$VBoxContainer/BtnQuit.pressed.connect(_on_quit_pressed)

func _on_new_game_pressed():
	get_tree().change_scene_to_file("res://Player.tscn")

func _on_options_pressed():
	pass # ainda sem ecrã de opções

func _on_quit_pressed():
	get_tree().quit()
