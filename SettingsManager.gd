extends Node

## Autoload — gere e persiste as configurações do jogo.
## Adiciona em Projeto > Definições do Projeto > Autoload com o nome:
## SettingsManager

const SETTINGS_PATH := "user://settings.cfg"
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

const REMAPPABLE_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "attack", "ui_cancel"
]

enum ScreenMode { WINDOWED, BORDERLESS, FULLSCREEN }

const DEFAULT_LANGUAGE := "pt"
const DEFAULT_SCREEN_MODE := ScreenMode.WINDOWED
const DEFAULT_RESOLUTION := Vector2i(1920, 1080)
const DEFAULT_VSYNC := true
const DEFAULT_FPS_LIMIT := 60
const DEFAULT_SHOW_FPS := false
const DEFAULT_CUSTOM_CURSOR := true
const CUSTOM_CURSOR_PATH := "res://sprites/cursor_wood.png"
const CUSTOM_CURSOR_HOTSPOT := Vector2(6, 2)

var current_language: String = DEFAULT_LANGUAGE
var screen_mode: int = DEFAULT_SCREEN_MODE
var resolution: Vector2i = DEFAULT_RESOLUTION
var vsync_enabled: bool = DEFAULT_VSYNC
var fps_limit: int = DEFAULT_FPS_LIMIT
var show_fps: bool = DEFAULT_SHOW_FPS
var custom_cursor_enabled: bool = DEFAULT_CUSTOM_CURSOR

# Existe apenas UMA vez neste ficheiro.
signal language_changed(language_code: String)

var _fps_label: Label = null
var fps_font: Font = null
var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	set_process(false)
	load_settings()


func _process(_delta: float) -> void:
	if show_fps and is_instance_valid(_fps_label):
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func load_settings() -> void:
	var err: Error = _config.load(SETTINGS_PATH)

	if err != OK:
		set_language(DEFAULT_LANGUAGE)
		set_screen_mode(DEFAULT_SCREEN_MODE)
		set_resolution(DEFAULT_RESOLUTION)
		set_vsync(DEFAULT_VSYNC)
		set_fps_limit(DEFAULT_FPS_LIMIT)
		set_show_fps(DEFAULT_SHOW_FPS)
		set_custom_cursor(DEFAULT_CUSTOM_CURSOR)
		return

	for bus_name in [BUS_MASTER, BUS_MUSIC, BUS_SFX]:
		var bus_idx: int = AudioServer.get_bus_index(bus_name)
		if bus_idx == -1:
			continue
		var vol_db: float = float(_config.get_value("audio", bus_name, 0.0))
		AudioServer.set_bus_volume_db(bus_idx, vol_db)

	for action in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var keycode: int = int(_config.get_value("controls", action, -1))
		if keycode == -1:
			continue
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)

	var saved_language: String = str(_config.get_value("general", "language", DEFAULT_LANGUAGE))
	if saved_language not in ["pt", "en", "es"]:
		saved_language = DEFAULT_LANGUAGE

	current_language = saved_language
	screen_mode = int(_config.get_value("general", "screen_mode", DEFAULT_SCREEN_MODE))
	resolution = _config.get_value("general", "resolution", DEFAULT_RESOLUTION) as Vector2i
	vsync_enabled = bool(_config.get_value("general", "vsync", DEFAULT_VSYNC))
	fps_limit = int(_config.get_value("general", "fps_limit", DEFAULT_FPS_LIMIT))
	show_fps = bool(_config.get_value("general", "show_fps", DEFAULT_SHOW_FPS))
	custom_cursor_enabled = bool(_config.get_value("general", "custom_cursor", DEFAULT_CUSTOM_CURSOR))

	TranslationServer.set_locale(current_language)
	set_screen_mode(screen_mode)
	set_resolution(resolution)
	set_vsync(vsync_enabled)
	set_fps_limit(fps_limit)
	set_show_fps(show_fps)
	set_custom_cursor(custom_cursor_enabled)


func save_settings() -> void:
	for bus_name in [BUS_MASTER, BUS_MUSIC, BUS_SFX]:
		var bus_idx: int = AudioServer.get_bus_index(bus_name)
		if bus_idx == -1:
			continue
		_config.set_value("audio", bus_name, AudioServer.get_bus_volume_db(bus_idx))

	for action in REMAPPABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key_event: InputEventKey = event as InputEventKey
				var keycode: int = key_event.physical_keycode if key_event.physical_keycode != 0 else key_event.keycode
				_config.set_value("controls", action, keycode)
				break

	_config.set_value("general", "language", current_language)
	_config.set_value("general", "screen_mode", screen_mode)
	_config.set_value("general", "resolution", resolution)
	_config.set_value("general", "vsync", vsync_enabled)
	_config.set_value("general", "fps_limit", fps_limit)
	_config.set_value("general", "show_fps", show_fps)
	_config.set_value("general", "custom_cursor", custom_cursor_enabled)
	_config.save(SETTINGS_PATH)


func set_bus_volume(bus_name: String, vol_db: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, vol_db)


func get_bus_volume(bus_name: String) -> float:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return 0.0
	return AudioServer.get_bus_volume_db(bus_idx)


func rebind_action(action: String, event: InputEventKey) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)


# ============================================================
# IDIOMA — existe UMA única função translate() neste ficheiro.
# ============================================================

func set_language(lang_code: String) -> void:
	if lang_code not in ["pt", "en", "es"]:
		lang_code = DEFAULT_LANGUAGE

	var changed: bool = current_language != lang_code
	current_language = lang_code
	TranslationServer.set_locale(lang_code)

	if changed:
		language_changed.emit(current_language)


func translate(key: String) -> String:
	var translations: Dictionary = {
		"pt": {
			"new_game": "Novo Jogo", "options": "Opções", "quit": "Sair",
			"options_title": "Opções", "back": "Voltar",
			"general": "Geral", "audio": "Áudio", "graphics": "Gráficos",
			"controls": "Controlos", "extras": "Extras",
			"language": "Idioma", "screen_mode": "Modo de Ecrã",
			"windowed": "Janela", "borderless": "Janela Sem Borda",
			"fullscreen": "Ecrã Inteiro", "resolution": "Resolução",
			"vsync": "V-Sync", "fps_limit": "Limite de FPS", "unlimited": "Sem Limite",
			"show_fps": "Mostrar FPS", "enabled": "Ativado", "disabled": "Desativado",
			"custom_cursor": "Cursor Personalizado",
			"restore_defaults": "Restaurar Predefinições",
			"restore_controls": "Restaurar Predefinições",
			"master": "Volume Geral", "music": "Música", "sfx": "Efeitos",
			"master_volume": "Volume Geral", "music_volume": "Música", "sfx_volume": "Efeitos",
			"portuguese": "Português", "english": "Inglês", "spanish": "Espanhol",
			"move_left": "Mover Esquerda", "move_right": "Mover Direita",
			"move_up": "Mover Cima", "move_down": "Mover Baixo",
			"jump": "Saltar", "dash": "Dash", "attack": "Ataque Corpo a Corpo",
			"ranged_attack": "Ataque à Distância", "aim_up": "Mirar Cima", "aim_down": "Mirar Baixo",
			"pause": "Pausa",
			"key_already_used": "Tecla já está a ser utilizada",
			"key_conflict_title": "Conflito de Tecla",
			"key_conflict_message": "A tecla '%s' já está atribuída a '%s'. Continuar vai remover essa tecla de '%s' e atribuí-la a '%s'.",
			"continue": "Continuar", "cancel": "Cancelar", "yes": "Sim", "no": "Não",
			"resume": "Retomar",
			"quit_confirm_message": "Tens a certeza que queres sair?",
		},
		"en": {
			"new_game": "New Game", "options": "Options", "quit": "Quit",
			"options_title": "Options", "back": "Back",
			"general": "General", "audio": "Audio", "graphics": "Graphics",
			"controls": "Controls", "extras": "Extras",
			"language": "Language", "screen_mode": "Screen Mode",
			"windowed": "Windowed", "borderless": "Borderless", "fullscreen": "Fullscreen",
			"resolution": "Resolution", "vsync": "V-Sync", "fps_limit": "FPS Limit", "unlimited": "Unlimited",
			"show_fps": "Show FPS", "enabled": "Enabled", "disabled": "Disabled",
			"custom_cursor": "Custom Cursor",
			"restore_defaults": "Restore Defaults",
			"restore_controls": "Restore Defaults",
			"master": "Master Volume", "music": "Music", "sfx": "Sound Effects",
			"master_volume": "Master Volume", "music_volume": "Music", "sfx_volume": "Sound Effects",
			"portuguese": "Portuguese", "english": "English", "spanish": "Spanish",
			"move_left": "Move Left", "move_right": "Move Right",
			"move_up": "Move Up", "move_down": "Move Down",
			"jump": "Jump", "dash": "Dash", "attack": "Melee Attack",
			"ranged_attack": "Ranged Attack", "aim_up": "Aim Up", "aim_down": "Aim Down",
			"pause": "Pause",
			"key_already_used": "Key is already in use",
			"key_conflict_title": "Key Conflict",
			"key_conflict_message": "The key '%s' is already assigned to '%s'. Continuing will remove it from '%s' and assign it to '%s'.",
			"continue": "Continue", "cancel": "Cancel", "yes": "Yes", "no": "No",
			"resume": "Resume",
			"quit_confirm_message": "Are you sure you want to quit?"
		},
		"es": {
			"new_game": "Nueva Partida", "options": "Opciones", "quit": "Salir",
			"options_title": "Opciones", "back": "Volver",
			"general": "General", "audio": "Audio", "graphics": "Gráficos",
			"controls": "Controles", "extras": "Extras",
			"language": "Idioma", "screen_mode": "Modo de Pantalla",
			"windowed": "Ventana", "borderless": "Ventana Sin Bordes", "fullscreen": "Pantalla Completa",
			"resolution": "Resolución", "vsync": "V-Sync", "fps_limit": "Límite de FPS", "unlimited": "Sin Límite",
			"show_fps": "Mostrar FPS", "enabled": "Activado", "disabled": "Desactivado",
			"custom_cursor": "Cursor Personalizado",
			"restore_defaults": "Restaurar Valores",
			"restore_controls": "Restaurar Valores",
			"master": "Volumen General", "music": "Música", "sfx": "Efectos",
			"master_volume": "Volumen General", "music_volume": "Música", "sfx_volume": "Efectos",
			"portuguese": "Portugués", "english": "Inglés", "spanish": "Español",
			"move_left": "Mover Izquierda", "move_right": "Mover Derecha",
			"move_up": "Mover Arriba", "move_down": "Mover Abajo",
			"jump": "Saltar", "dash": "Dash", "attack": "Ataque Cuerpo a Cuerpo",
			"ranged_attack": "Ataque a Distancia", "aim_up": "Apuntar Arriba", "aim_down": "Apuntar Abajo",
			"pause": "Pausa",
			"key_already_used": "La tecla ya está en uso",
			"key_conflict_title": "Conflicto de Tecla",
			"key_conflict_message": "La tecla '%s' ya está asignada a '%s'. Continuar la quitará de '%s' y la asignará a '%s'.",
			"continue": "Continuar", "cancel": "Cancelar", "yes": "Sí", "no": "No",
			"resume": "Continuar",
			"quit_confirm_message": "¿Seguro que quieres salir?"
		}
	}

	var language_table: Dictionary = translations.get(current_language, translations["pt"])
	if language_table.has(key):
		return str(language_table[key])
	return key


# ============================================================
# ECRÃ
# ============================================================

func set_screen_mode(mode: int) -> void:
	screen_mode = mode
	var window: Window = get_window()
	if window == null:
		return

	match mode:
		ScreenMode.WINDOWED:
			window.borderless = false
			window.mode = Window.MODE_WINDOWED
		ScreenMode.BORDERLESS:
			window.mode = Window.MODE_WINDOWED
			window.borderless = true
		ScreenMode.FULLSCREEN:
			window.borderless = false
			window.mode = Window.MODE_FULLSCREEN

	if mode != ScreenMode.FULLSCREEN:
		set_resolution(resolution)


func set_resolution(size: Vector2i) -> void:
	resolution = size
	var window: Window = get_window()
	if window == null:
		return
	if window.mode == Window.MODE_WINDOWED:
		window.size = size
		_center_window()


func _center_window() -> void:
	var window: Window = get_window()
	if window == null:
		return
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	window.position = (screen_size - window.size) / 2


func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)


func set_fps_limit(fps: int) -> void:
	fps_limit = fps
	Engine.max_fps = 0 if fps <= 0 else fps


# ============================================================
# CURSOR
# ============================================================

func set_custom_cursor(enabled: bool) -> void:
	custom_cursor_enabled = enabled
	if enabled:
		var texture: Texture2D = load(CUSTOM_CURSOR_PATH) as Texture2D
		if texture:
			Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, CUSTOM_CURSOR_HOTSPOT)
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


# ============================================================
# FPS
# ============================================================

func set_show_fps(enabled: bool) -> void:
	show_fps = enabled
	if enabled:
		_ensure_fps_label()
		if is_instance_valid(_fps_label):
			_fps_label.visible = true
	elif is_instance_valid(_fps_label):
		_fps_label.visible = false
	set_process(enabled)


func _ensure_fps_label() -> void:
	if is_instance_valid(_fps_label):
		return

	const COLOR_TITLE := Color(0.92, 0.8, 0.5)
	const COLOR_OUTLINE := Color(0.05, 0.05, 0.08, 0.9)

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_fps_label = Label.new()
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_font_size_override("font_size", 18)
	_fps_label.add_theme_color_override("font_color", COLOR_TITLE)
	_fps_label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	_fps_label.add_theme_constant_override("outline_size", 3)

	if fps_font:
		_fps_label.add_theme_font_override("font", fps_font)

	_fps_label.anchor_left = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.anchor_top = 0.0
	_fps_label.anchor_bottom = 0.0
	_fps_label.offset_right = -14
	_fps_label.offset_top = 12
	_fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	layer.add_child(_fps_label)


# ============================================================
# RESTAURAR
# ============================================================

func restore_general_defaults() -> void:
	set_language(DEFAULT_LANGUAGE)
	set_screen_mode(DEFAULT_SCREEN_MODE)
	set_resolution(DEFAULT_RESOLUTION)
	set_vsync(DEFAULT_VSYNC)
	set_fps_limit(DEFAULT_FPS_LIMIT)
	set_show_fps(DEFAULT_SHOW_FPS)
	set_custom_cursor(DEFAULT_CUSTOM_CURSOR)
	save_settings()
