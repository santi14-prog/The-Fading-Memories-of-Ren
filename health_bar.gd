extends Control

@onready var progress_bar: ProgressBar = $ProgressBar

# Ajusta este caminho ao node real do Ren na tua cena, ex: "../../Ren"
@export var player_path: NodePath


func _ready() -> void:
	var player := get_node(player_path)
	if player:
		player.health_changed.connect(_on_health_changed)
		# Inicializa a barra com o valor atual assim que a cena carrega
		_on_health_changed(player.current_health, player.MAX_HEALTH)


func _on_health_changed(current_health: int, max_health: int) -> void:
	progress_bar.max_value = max_health
	progress_bar.value = current_health
