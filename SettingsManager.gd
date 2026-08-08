extends Node
## Autoload — gere e persiste as configurações do jogo (áudio e controlos).
## Adiciona em Projeto > Definições do Projeto > Autoload, com o nome "SettingsManager".

const SETTINGS_PATH := "user://settings.cfg"

# Nomes dos buses de áudio — confirma que existem no painel de Áudio
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

# Ações de input remapeáveis — ajusta esta lista à tua Input Map real
# (Projeto > Definições do Projeto > Mapa de Entrada)
const REMAPPABLE_ACTIONS := [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "attack", "ui_cancel"
]

var _config := ConfigFile.new()


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK:
		return  # primeira vez a correr — fica tudo nos valores por defeito da cena

	for bus_name in [BUS_MASTER, BUS_MUSIC, BUS_SFX]:
		var bus_idx := AudioServer.get_bus_index(bus_name)
		if bus_idx == -1:
			continue
		var vol_db: float = _config.get_value("audio", bus_name, 0.0)
		AudioServer.set_bus_volume_db(bus_idx, vol_db)

	for action in REMAPPABLE_ACTIONS:
		var keycode: int = _config.get_value("controls", action, -1)
		if keycode != -1:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, ev)


func save_settings() -> void:
	for bus_name in [BUS_MASTER, BUS_MUSIC, BUS_SFX]:
		var bus_idx := AudioServer.get_bus_index(bus_name)
		if bus_idx == -1:
			continue
		_config.set_value("audio", bus_name, AudioServer.get_bus_volume_db(bus_idx))

	for action in REMAPPABLE_ACTIONS:
		var events := InputMap.action_get_events(action)
		for ev in events:
			if ev is InputEventKey:
				_config.set_value("controls", action, ev.physical_keycode)
				break

	_config.save(SETTINGS_PATH)


func set_bus_volume(bus_name: String, vol_db: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, vol_db)


func get_bus_volume(bus_name: String) -> float:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return 0.0
	return AudioServer.get_bus_volume_db(bus_idx)


func rebind_action(action: String, event: InputEventKey) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
