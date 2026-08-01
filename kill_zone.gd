extends Area2D

@onready var respawn_point: Marker2D = get_node("../RespawnPoint")

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.velocity = Vector2.ZERO
		body.global_position = respawn_point.global_position
