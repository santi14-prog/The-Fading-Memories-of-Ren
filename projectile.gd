extends Area2D

const SPEED = 500.0
const DAMAGE = 8
const LIFETIME = 2.0

var direction := 1.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta
	scale.x = direction

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return  # ignora quem disparou a flecha
	if body.has_method("take_damage"):
		body.take_damage(DAMAGE)
	queue_free()
